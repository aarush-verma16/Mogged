import SwiftUI

/// Quit must stop what Mogged started. Foundation's `Process` keeps a game or a
/// Steam client alive as an orphan once Mogged exits, unless told to stop first.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        Task {
            await model.stopEverything()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct MoggedApp: App {
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        GeistFonts.register()
    }

    var body: some Scene {
        Window("Mogged", id: "library") {
            LibraryView()
                .environment(model)
                .task {
                    appDelegate.model = model
                    await model.bootstrap()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
