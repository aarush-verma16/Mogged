import SwiftUI

@main
struct MoggedApp: App {
    @State private var model = AppModel()

    init() {
        GeistFonts.register()
    }

    var body: some Scene {
        Window("Mogged", id: "library") {
            LibraryView()
                .environment(model)
                .task { await model.bootstrap() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
