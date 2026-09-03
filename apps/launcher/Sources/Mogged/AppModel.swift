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

    private let supervisor = RuntimeSupervisor()

    var selected: LibraryEntry? {
        entries.first { $0.id == selectedId } ?? entries.first
    }

    func bootstrap() async {
        await refresh()
        if selectedId == nil {
            selectedId = entries.first?.id
        }
    }

    func refresh() async {
        do {
            let profiles = try ProfileLoader.load()
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
