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

    private let supervisor = RuntimeSupervisor()
    private var watchTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    var selected: LibraryEntry? {
        visible.first { $0.id == selectedId } ?? entries.first { $0.id == selectedId } ?? visible.first
    }

    var visible: [LibraryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.profile.displayName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var steamStatus: String {
        if steam.running { return steam.account?.personaName.map { "Steam · \($0)" } ?? "Steam connected" }
        if steam.present { return "Steam on this Mac" }
        return "No Steam on this Mac"
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
        } catch let error as MoggedError {
            loadFailed = true
            banner = error.userMessage
        } catch {
            loadFailed = true
            banner = "Mogged couldn't load its game list."
        }
    }

    func play(_ entry: LibraryEntry) async {
        banner = nil
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await supervisor.launch(profile: entry.profile)
            await refresh()
            watchRunning()
        } catch let error as MoggedError {
            banner = error.userMessage
        } catch {
            banner = "Couldn't start the game."
        }
    }

    func stop(_ entry: LibraryEntry) async {
        banner = nil
        do {
            try await supervisor.stop(titleId: entry.id)
            await refresh()
        } catch let error as MoggedError {
            banner = error.userMessage
        } catch {
            banner = "Couldn't stop the game."
        }
    }

    func locate(_ entry: LibraryEntry) async {
        banner = nil
        guard let folder = Self.pickFolder(title: entry.profile.displayName) else { return }
        do {
            try await supervisor.rememberInstall(titleId: entry.id, folder: folder)
            await refresh()
            selectedId = entry.id
        } catch {
            banner = "Couldn't save that folder."
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                await refresh()
            }
        }
    }

    private func watchRunning() {
        watchTask?.cancel()
        watchTask = Task { [supervisor] in
            while !Task.isCancelled {
                let ids = await supervisor.runningTitleIds()
                runningIds = Set(ids)
                if ids.isEmpty { break }
                try? await Task.sleep(for: .seconds(1))
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
        panel.message = "Select the folder for \(title)"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
