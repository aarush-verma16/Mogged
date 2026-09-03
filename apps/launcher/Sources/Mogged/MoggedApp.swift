import SwiftUI

@main
struct MoggedApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Mogged", id: "library") {
            LibraryView()
                .environment(model)
                .task { await model.bootstrap() }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 780, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
