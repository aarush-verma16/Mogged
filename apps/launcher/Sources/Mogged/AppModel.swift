import AppKit
import Foundation
import MoggedRuntime
import Observation

@MainActor
@Observable
final class AppModel {
    var entries: [LibraryEntry] = []
    var selectedId: String?
    var runningIds: Set<String> = []
    var banner: String?
    var bannerIsError = true
    var isBusy = false
    var loadFailed = false
    var query = ""
    var steam: SteamSnapshot = .empty
    var runtime = RuntimeInspect.empty
    var session: SessionInspect?
    var runtimeLog = ""
    var gameLog = ""
    var install: InstallSnapshot?
    var lastError: String?
    var errorLog = ""
    var logTab: LogTab = .errors
    var steamUser = ""
    var steamPassword = ""
    var steamGuard = ""
    var credentialsSaved = false
    var steamServicesReady = false
    var steamSignedIn = false
    var steamNeedsGuardCode = false

    enum LogTab: String, CaseIterable, Identifiable {
        case errors
        case events
        case title
        var id: String { rawValue }
    }

    private let supervisor = RuntimeSupervisor()
    private var pollTask: Task<Void, Never>?
    private var seenExit: [String: Int32] = [:]
    private var seenInstallError: String?
    private var seenInstallNotice: String?
    private var errorMarkRuntime = ""
    private var errorMarkGame = ""
    private var sessionReady = false

    var selected: LibraryEntry? {
        visible.first { $0.id == selectedId } ?? entries.first { $0.id == selectedId } ?? visible.first
    }

    var visible: [LibraryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.profile.displayName.localizedCaseInsensitiveContains(trimmed)
            || $0.profile.id.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func bootstrap() async {
        loadSavedCredentials()
        await refresh()
        // A Steam client denied last session keeps retrying and flashing its own
        // window with nothing tying that to a Play click. Sweep it before anything
        // else runs, not just reactively the next time Play happens to be pressed.
        await supervisor.cleanupOrphanedSteamClients(profiles: entries.map(\.profile))
        errorMarkRuntime = runtimeLog
        errorMarkGame = gameLog
        sessionReady = true
        clearError()
        errorLog = ""
        seenInstallError = nil
        seenInstallNotice = nil
        seenExit = [:]
        if selectedId == nil {
            selectedId = entries.first(where: { $0.profile.role == .smoke })?.id ?? entries.first?.id
        }
        startPolling()
    }

    func refresh() async {
        do {
            let profiles = try ProfileLoader.load()
            steam = await supervisor.steamSnapshot()
            entries = await supervisor.libraryEntries(profiles: profiles)
            loadFailed = false
            runningIds = Set(await supervisor.runningTitleIds())
            runtime = await supervisor.inspectRuntime()
            if let entry = selected {
                session = await supervisor.inspectSession(profile: entry.profile, install: entry.install)
                gameLog = await supervisor.gameLogTail(titleId: entry.id)
                steamServicesReady = await supervisor.steamServicesReady(profile: entry.profile)
                steamSignedIn = await supervisor.steamSignedIn(profile: entry.profile)
            }
            runtimeLog = await supervisor.telemetryTail()
            install = await supervisor.inspectInstall()
            if let install, install.titleId == selectedId, install.running || !(selected?.canPlay ?? false) {
                if !install.log.isEmpty { gameLog = install.log }
            }
            if let install, let err = install.error, seenInstallError != err {
                seenInstallError = err
                rememberError(err)
            } else if let install, install.titleId == "steam-login", !install.running,
                      install.error == nil, !install.line.isEmpty, seenInstallNotice != install.line
            {
                seenInstallNotice = install.line
                rememberNotice(install.line)
            }
            if let session, let code = session.lastExit, code != 0, session.running == false,
               seenExit[session.titleId] != code
            {
                seenExit[session.titleId] = code
                rememberError("\(session.titleId) exited \(code)")
            }
            if sessionReady {
                errorLog = ErrorFeed.digest(
                    runtimeLog: ErrorFeed.added(after: errorMarkRuntime, in: runtimeLog),
                    titleLog: ErrorFeed.added(after: errorMarkGame, in: gameLog),
                    extra: [lastError, install?.error].compactMap { $0 }
                )
            } else {
                errorLog = ""
            }
        } catch let error as MoggedError {
            loadFailed = true
            rememberError(error.logDescription)
        } catch {
            loadFailed = true
            rememberError(String(describing: error))
        }
    }

    func play(_ entry: LibraryEntry) async {
        banner = nil
        isBusy = true
        defer { isBusy = false }
        do {
            guard await waitForSteam(entry) else { return }
            _ = try await supervisor.launch(profile: entry.profile)
            await refresh()
        } catch let error as MoggedError {
            rememberError(error.userMessage)
            await refresh()
        } catch {
            rememberError(String(describing: error))
        }
    }

    /// Steam signs in before the game starts, otherwise the title stalls on
    /// "Unable to initialize Steam Input". Signing in takes a few seconds.
    private func waitForSteam(_ entry: LibraryEntry) async -> Bool {
        guard entry.profile.settings?.needsSteamClient == true else { return true }

        func handle(_ state: SteamServicesState) -> Bool? {
            switch state {
            case .ready:
                steamNeedsGuardCode = false
                return true
            case .signingIn:
                return nil
            case .needsGuardCode:
                steamNeedsGuardCode = true
                rememberError(MoggedError.steamGuardCodeNeeded.userMessage)
                return false
            case .needsAccount:
                rememberError(MoggedError.steamAccountNeeded.userMessage)
                return false
            case .notInstalled:
                rememberError(MoggedError.steamServicesMissing.userMessage)
                return false
            }
        }

        do {
            if let done = handle(try await supervisor.prepareSteamServices(profile: entry.profile)) {
                return done
            }
        } catch let error as MoggedError {
            rememberError(error.userMessage)
            return false
        } catch {
            rememberError(String(describing: error))
            return false
        }

        rememberNotice("Signing in to Steam for \(entry.profile.displayName)…")
        for _ in 0..<Self.steamSignInPolls {
            try? await Task.sleep(for: .seconds(2))
            do {
                if let done = handle(try await supervisor.pollSteamLogin(profile: entry.profile)) {
                    if done { rememberNotice("Steam ready. Starting \(entry.profile.displayName)…") }
                    return done
                }
            } catch let error as MoggedError {
                rememberError(error.userMessage)
                return false
            } catch {
                rememberError(String(describing: error))
                return false
            }
        }
        rememberError(MoggedError.steamSignInNeeded.userMessage)
        return false
    }

    private static let steamSignInPolls = 45

    func stop(_ entry: LibraryEntry) async {
        banner = nil
        do {
            try await supervisor.stop(titleId: entry.id)
            await refresh()
        } catch let error as MoggedError {
            rememberError(error.userMessage)
        } catch {
            rememberError(String(describing: error))
        }
    }

    func install(_ entry: LibraryEntry) async {
        banner = nil
        lastError = nil
        bannerIsError = true
        saveCredentials()
        isBusy = true
        defer { isBusy = false }
        do {
            try await supervisor.startInstall(
                profile: entry.profile,
                username: steamUser,
                password: steamPassword,
                guardCode: steamGuard.isEmpty ? nil : steamGuard
            )
            await refresh()
        } catch let error as MoggedError {
            rememberError(error.userMessage)
            await refresh()
        } catch {
            rememberError(String(describing: error))
        }
    }

    func requestGuard() async {
        banner = nil
        lastError = nil
        bannerIsError = true
        saveCredentials()
        isBusy = true
        defer { isBusy = false }
        do {
            try await supervisor.requestGuard(username: steamUser, password: steamPassword)
            await refresh()
        } catch let error as MoggedError {
            rememberError(error.userMessage)
            await refresh()
        } catch {
            rememberError(String(describing: error))
        }
    }

    func addSteamServices(_ entry: LibraryEntry) async {
        banner = nil
        lastError = nil
        bannerIsError = true
        isBusy = true
        defer { isBusy = false }
        rememberNotice("Adding Steam for \(entry.profile.displayName). This takes a minute.")
        do {
            try await supervisor.addSteamServices(profile: entry.profile)
            steamServicesReady = await supervisor.steamServicesReady(profile: entry.profile)
            rememberNotice("Steam added. Click Play — Mogged signs in for you.")
            await refresh()
        } catch let error as MoggedError {
            rememberError(error.userMessage)
        } catch {
            rememberError(String(describing: error))
        }
    }

    /// Quitting Mogged must not leave a game or a Steam client it started running
    /// behind — see `RuntimeSupervisor.stopAll()`.
    func stopEverything() async {
        await supervisor.stopAll()
    }

    func cancelInstall() async {
        await supervisor.cancelInstall()
        await refresh()
    }

    func locate(_ entry: LibraryEntry) async {
        banner = nil
        let dest = RuntimePaths.standard().gameFolder(for: entry.id)
        let known = entry.install?.path
            ?? (FileManager.default.fileExists(atPath: dest.path) ? dest : nil)

        if let known {
            let highlight = entry.install?.executable ?? known
            NSWorkspace.shared.activateFileViewerSelecting([highlight])
            do {
                try await supervisor.rememberInstall(titleId: entry.id, folder: known)
                rememberNotice(known.path)
                await refresh()
                selectedId = entry.id
            } catch {
                rememberError(String(describing: error))
            }
            return
        }

        let games = RuntimePaths.standard().games
        try? FileManager.default.createDirectory(at: games, withIntermediateDirectories: true)
        guard let folder = Self.pickFolder(title: entry.profile.displayName, start: games) else { return }
        do {
            try await supervisor.rememberInstall(titleId: entry.id, folder: folder)
            await refresh()
            selectedId = entry.id
        } catch {
            rememberError(String(describing: error))
        }
    }

    func clearError() {
        banner = nil
        lastError = nil
        bannerIsError = true
    }

    func copyVisibleLog() {
        let text: String
        switch logTab {
        case .errors: text = errorLog
        case .events: text = runtimeLog
        case .title: text = gameLog
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text.isEmpty ? "—" : text, forType: .string)
    }

    func rememberError(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        banner = trimmed
        bannerIsError = true
        if lastError == trimmed { return }
        lastError = trimmed
        logTab = .errors
    }

    func rememberNotice(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        banner = trimmed
        bannerIsError = false
    }

    func saveCredentials() {
        SteamCredentialStore.save(user: steamUser, password: steamPassword, guardCode: steamGuard)
        UserDefaults.standard.removeObject(forKey: "mogged.steamUser")
        credentialsSaved = SteamCredentialStore.load() != nil
    }

    func forgetCredentials() {
        SteamCredentialStore.delete()
        steamPassword = ""
        steamGuard = ""
        credentialsSaved = false
        steamNeedsGuardCode = false
    }

    private func loadSavedCredentials() {
        if let saved = SteamCredentialStore.load() {
            steamUser = saved.user
            steamPassword = saved.password
            steamGuard = saved.guardCode
            credentialsSaved = true
            return
        }
        steamUser = UserDefaults.standard.string(forKey: "mogged.steamUser") ?? ""
        credentialsSaved = false
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                let hot = !runningIds.isEmpty || install?.running == true
                try? await Task.sleep(for: .milliseconds(hot ? 400 : 1000))
                await refresh()
            }
        }
    }

    func defaultInstallFolder(for titleId: String) -> URL {
        RuntimePaths.standard().gameFolder(for: titleId)
    }

    private static func pickFolder(title: String, start: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = start
        panel.prompt = "Choose"
        panel.message = "Installs go in \(start.path). Choose that folder or another for \(title)."
        return panel.runModal() == .OK ? panel.url : nil
    }
}
