import SwiftUI
import MoggedRuntime

struct LibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(Palette.bg)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MOGGED")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Palette.dim)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            List(model.entries, selection: Bindable(model).selectedId) { entry in
                GameRow(entry: entry, isRunning: model.runningIds.contains(entry.id))
                    .tag(entry.id)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 280)
        .background(Palette.sidebar)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let entry = model.selected {
                Text(entry.profile.displayName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(statusLine(entry))
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.dim)

                if entry.profile.controllerRequired == true {
                    Text("This game needs a controller.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.dim)
                }

                Spacer()

                if let banner = model.banner {
                    Text(banner)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.warn)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.warn.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 12) {
                    if model.runningIds.contains(entry.id) {
                        Button("Stop") { Task { await model.stop(entry) } }
                            .buttonStyle(SecondaryButtonStyle())
                    } else if entry.isInstalled {
                        Button(model.isBusy ? "Starting…" : "Play") {
                            Task { await model.play(entry) }
                        }
                        .buttonStyle(PlayButtonStyle())
                        .disabled(model.isBusy)
                    } else {
                        Button("Locate") { Task { await model.locate(entry) } }
                            .buttonStyle(PlayButtonStyle())
                    }

                    if entry.isInstalled {
                        Button("Locate") { Task { await model.locate(entry) } }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
            } else if model.loadFailed {
                Text(model.banner ?? "Mogged couldn't load its game list.")
                    .foregroundStyle(Palette.warn)
                Spacer()
            } else {
                Text("No games in the library yet.")
                    .foregroundStyle(Palette.dim)
                Spacer()
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statusLine(_ entry: LibraryEntry) -> String {
        if model.runningIds.contains(entry.id) { return "Running" }
        if entry.isInstalled { return "Ready to play" }
        return "Not installed"
    }
}

private struct GameRow: View {
    let entry: LibraryEntry
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.profile.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(isRunning ? "Running" : entry.isInstalled ? "Ready" : "Not installed")
                .font(.system(size: 12))
                .foregroundStyle(entry.isInstalled ? Palette.ok : Palette.dim)
        }
        .padding(.vertical, 6)
    }
}

private enum Palette {
    static let bg = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let sidebar = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let dim = Color(red: 0.62, green: 0.62, blue: 0.65)
    static let accent = Color(red: 0.91, green: 0.27, blue: 0.27)
    static let ok = Color(red: 0.45, green: 0.78, blue: 0.52)
    static let warn = Color(red: 0.95, green: 0.72, blue: 0.38)
}

private struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.12), in: Capsule())
    }
}
