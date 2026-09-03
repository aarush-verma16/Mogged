import SwiftUI
import MoggedRuntime

struct LibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Theme.hairline).frame(width: 1)
                detail
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(Theme.canvas)
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: Theme.Space.x3) {
            Text("Mogged")
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Library")
                .font(Theme.sans(13, weight: .regular))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(.horizontal, Theme.Space.x4)
        .frame(height: Theme.Space.topbar)
        .background(Theme.canvas)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x2) {
            Text("Games")
                .font(Theme.sans(12, weight: .medium))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.Space.x2)
                .padding(.top, Theme.Space.x4)

            ScrollView {
                LazyVStack(spacing: Theme.Space.x1) {
                    ForEach(model.entries) { entry in
                        sidebarRow(entry)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.x2)
        .padding(.bottom, Theme.Space.x4)
        .frame(width: Theme.Space.sidebar)
        .background(Theme.canvas)
    }

    private func sidebarRow(_ entry: LibraryEntry) -> some View {
        let selected = model.selectedId == entry.id || (model.selectedId == nil && model.selected?.id == entry.id)
        let running = model.runningIds.contains(entry.id)
        return Button {
            model.selectedId = entry.id
        } label: {
            HStack(spacing: Theme.Space.x2) {
                Circle()
                    .fill(rowDot(entry, running: running))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.profile.displayName)
                        .font(Theme.sans(13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(rowMeta(entry, running: running))
                        .font(Theme.sans(12, weight: .regular))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.x2)
            .padding(.vertical, Theme.Space.x2)
            .background(
                selected ? Theme.raised : Color.clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            )
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry = model.selected {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text(entry.profile.displayName)
                        .font(Theme.sans(32, weight: .semibold))
                        .tracking(-0.64)
                        .foregroundStyle(Theme.ink)

                    StatusBadge(text: statusLine(entry), tone: statusTone(entry))

                    if entry.profile.controllerRequired == true {
                        Text("This game needs a controller.")
                            .font(Theme.sans(14, weight: .regular))
                            .foregroundStyle(Theme.body)
                    }
                }
                .padding(Theme.Space.x8)

                Spacer(minLength: 0)

                if let banner = model.banner {
                    Text(banner)
                        .font(Theme.sans(13, weight: .regular))
                        .foregroundStyle(Theme.warning)
                        .padding(Theme.Space.x3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        }
                        .padding(.horizontal, Theme.Space.x8)
                        .padding(.bottom, Theme.Space.x4)
                }

                HStack(spacing: Theme.Space.x2) {
                    Spacer()
                    actionButtons(entry)
                }
                .padding(.horizontal, Theme.Space.x8)
                .padding(.vertical, Theme.Space.x4)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                }
            } else {
                Text(model.loadFailed ? (model.banner ?? "Mogged couldn't load its game list.") : "No games in the library yet.")
                    .font(Theme.sans(14, weight: .regular))
                    .foregroundStyle(Theme.body)
                    .padding(Theme.Space.x8)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.canvas)
    }

    @ViewBuilder
    private func actionButtons(_ entry: LibraryEntry) -> some View {
        if model.runningIds.contains(entry.id) {
            Button("Stop") { Task { await model.stop(entry) } }
                .buttonStyle(VercelButtonStyle(kind: .secondary))
        } else if entry.isInstalled {
            Button("Locate") { Task { await model.locate(entry) } }
                .buttonStyle(VercelButtonStyle(kind: .secondary))
            Button(model.isBusy ? "Starting…" : "Play") {
                Task { await model.play(entry) }
            }
            .buttonStyle(VercelButtonStyle(kind: .primary, disabled: model.isBusy))
            .disabled(model.isBusy)
        } else {
            Button("Locate") { Task { await model.locate(entry) } }
                .buttonStyle(VercelButtonStyle(kind: .primary))
        }
    }

    private func statusLine(_ entry: LibraryEntry) -> String {
        if model.runningIds.contains(entry.id) { return "Running" }
        if entry.isInstalled { return "Ready" }
        return "Not installed"
    }

    private func statusTone(_ entry: LibraryEntry) -> StatusBadge.Tone {
        if model.runningIds.contains(entry.id) { return .running }
        if entry.isInstalled { return .ready }
        return .idle
    }

    private func rowMeta(_ entry: LibraryEntry, running: Bool) -> String {
        if running { return "Running" }
        return entry.isInstalled ? "Ready" : "Not installed"
    }

    private func rowDot(_ entry: LibraryEntry, running: Bool) -> Color {
        if running { return Theme.blue }
        return entry.isInstalled ? Theme.success : Theme.accents3
    }
}
