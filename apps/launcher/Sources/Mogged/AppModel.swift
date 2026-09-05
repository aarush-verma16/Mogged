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
    var steamUser = UserDefaults.standard.string(forKey: "mogged.steamUser") ?? ""
    var steamPassword = ""
    var steamGuard = ""

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
        await refresh()
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
            }
            runtimeLog = await supervisor.telemetryTail()
            install = await supervisor.inspectInstall()
            if let install, install.titleId == selectedId, install.running || !(selected?.canPlay ?? false) {
                if !install.log.isEmpty { gameLog = install.log }
            }
            if let install, let err = install.error, !install.running, seenInstallError != err {
                seenInstallError = err
                rememberError(err)
            }
            if let session, let code = session.lastExit, code != 0, session.running == false,
               seenExit[session.titleId] != code
            {
                seenExit[session.titleId] = code
                rememberError("\(session.titleId) exited \(code)")
            }
            errorLog = ErrorFeed.digest(
                runtimeLog: runtimeLog,
                titleLog: gameLog,
                extra: [lastError, install?.error].compactMap { $0 }
            )
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
            _ = try await supervisor.launch(profile: entry.profile)
            await refresh()
        } catch let error as MoggedError {
            rememberError(error.userMessage)
            await refresh()
        } catch {
            rememberError(String(describing: error))
        }
    }

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
        UserDefaults.standard.set(steamUser, forKey: "mogged.steamUser")
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

    func cancelInstall() async {
        await supervisor.cancelInstall()
        await refresh()
    }

    func locate(_ entry: LibraryEntry) async {
        banner = nil
        guard let folder = Self.pickFolder(title: entry.profile.displayName) else { return }
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
        if lastError == trimmed { return }
        lastError = trimmed
        logTab = .errors
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

    private static func pickFolder(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        panel.message = "Folder for \(title)"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
