import AppKit
import SwiftUI
import MoggedRuntime

struct LibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            topBar
            hairline
            HStack(spacing: 0) {
                sidebar
                hairlineVertical
                inspector
                hairlineVertical
                logs
            }
        }
        .frame(minWidth: 1100, minHeight: 640)
        .background(Theme.canvas)
        .preferredColorScheme(.dark)
    }

    private var hairline: some View { Rectangle().fill(Theme.hairline).frame(height: 1) }
    private var hairlineVertical: some View { Rectangle().fill(Theme.hairline).frame(width: 1) }

    private var topBar: some View {
        HStack(spacing: Theme.Space.x3) {
            Text("mogged")
                .font(Theme.mono(12, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text("operator")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.muted)
            Spacer()
            MonoStat(label: "wine", value: model.runtime.wine ?? "missing", ok: model.runtime.wineReady)
            MonoStat(label: "steam", value: steamValue, ok: model.runtime.steamRunning)
            MonoStat(label: "apps", value: "\(model.runtime.steamAppCount)", ok: model.runtime.steamPresent)
            if let inst = model.install, inst.running {
                MonoStat(label: "install", value: inst.percentLabel, ok: true)
            }
            if let pid = model.session?.pid {
                MonoStat(label: "pid", value: "\(pid)", ok: true)
            }
            if let err = model.lastError {
                MonoStat(label: "err", value: err, ok: false)
            }
        }
        .padding(.horizontal, Theme.Space.x3)
        .frame(height: 36)
    }

    private var steamValue: String {
        if model.runtime.steamRunning { return model.runtime.steamAccount ?? "running" }
        if model.runtime.steamPresent { return "disk" }
        return "off"
    }

    private var sidebar: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: Theme.Space.x2) {
            TextField("filter", text: $model.query)
                .textFieldStyle(.plain)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, Theme.Space.x2)
                .frame(height: 28)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.visible) { entry in
                        sidebarRow(entry)
                    }
                }
            }
        }
        .padding(Theme.Space.x2)
        .frame(width: 220)
        .background(Theme.canvas)
    }

    private func sidebarRow(_ entry: LibraryEntry) -> some View {
        let selected = model.selectedId == entry.id || model.selected?.id == entry.id
        let running = model.runningIds.contains(entry.id)
        return Button {
            model.selectedId = entry.id
        } label: {
            HStack(spacing: Theme.Space.x2) {
                let installing = model.install?.titleId == entry.id && model.install?.running == true
                Circle()
                    .fill(running || installing ? Theme.blue : (entry.canPlay ? Theme.success : Theme.accents3))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.profile.displayName)
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(rowMeta(entry, running: running))
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.x2)
            .padding(.vertical, 6)
            .background(selected ? Theme.raised : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry = model.selected {
                HStack(spacing: Theme.Space.x2) {
                    Text(entry.profile.displayName)
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    actionButtons(entry)
                }
                .padding(Theme.Space.x3)

                if let banner = model.banner {
                    HStack(alignment: .top, spacing: Theme.Space.x2) {
                        Text(banner)
                            .font(Theme.mono(11))
                            .foregroundStyle(model.bannerIsError ? Theme.error : Theme.ink)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                        Button("copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(banner, forType: .string)
                        }
                        .buttonStyle(.plain)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.muted)
                        Button("ok") { model.clearError() }
                            .buttonStyle(.plain)
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, Theme.Space.x3)
                    .padding(.bottom, Theme.Space.x2)
                }

                accountBar

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.x1) {
                        section("title")
                        KV("id", entry.profile.id)
                        KV("appid", "\(entry.profile.steamAppId)")
                        KV("engine", entry.profile.engine)
                        KV("api", entry.profile.graphicsApi.rawValue)
                        KV("anticheat", entry.profile.antiCheat.rawValue)
                        KV("stack", model.session?.stack ?? entry.profile.backend.preferred)
                        KV("ready", entry.canPlay ? "yes" : "no")
                        KV("safe", entry.profile.settings?.isSafeBoot == true ? "yes · first boot" : "heavy")
                        KV("disk", "\(entry.profile.settings?.requiredFreeGB ?? 80) GB budget")

                        installSection(entry)

                        section("paths")
                        KV("install", model.session?.install ?? "—")
                        KV("exe", model.session?.exe ?? "—")
                        KV("prefix", model.session?.prefix ?? "—")
                        KV("cache", model.session?.cache ?? "—")
                        KV("log", model.session?.logPath ?? "—")
                        KV("prefixok", (model.session?.prefixReady == true) ? "yes" : "no")

                        section("process")
                        KV("pid", model.session?.pid.map(String.init) ?? "—")
                        KV("running", model.session?.running == true ? "yes" : "no")
                        KV("exit", exitLabel)

                        section("host")
                        KV("wine", model.runtime.wine ?? "—")
                        KV("backend.json", model.runtime.backend.map { $0.wine } ?? "unwritten")
                        KV("dxvk", model.runtime.backend?.dxvkPath ?? "bundled")
                        KV("vkd3d", model.runtime.backend?.vkd3dPath ?? "bundled")
                        KV("moltenvk", model.runtime.backend?.moltenVk ?? "bundled")
                        KV("support", model.runtime.supportRoot)
                        KV("steamroot", model.runtime.steamRoot ?? "—")

                        section("opt")
                        KV("thermal", model.session?.optimization?.thermal ?? "—")
                        KV("fpscap", model.session?.optimization.map { "\($0.fpsCap)" } ?? "—")
                        KV("upscaler", model.session?.optimization?.upscaler ?? "—")
                        KV("rt", model.session?.optimization?.rayTracing ?? "—")
                        KV("why", model.session?.optimization?.reason ?? "—")

                        section("env")
                        ForEach(envRows, id: \.0) { key, value in
                            KV(key, value)
                        }
                    }
                    .padding(.horizontal, Theme.Space.x3)
                    .padding(.bottom, Theme.Space.x4)
                }
            } else {
                Text(model.loadFailed ? (model.banner ?? "load failed") : "no title")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
                    .padding(Theme.Space.x3)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.canvas)
    }

    private var envRows: [(String, String)] {
        let env = model.session?.env ?? [:]
        let keys = ["WINEPREFIX", "WINEDLLOVERRIDES", "DXVK_FRAME_RATE", "DXVK_HUD", "VK_ICD_FILENAMES", "MOGGED_THERMAL", "SteamDeck"]
        return keys.compactMap { key in
            guard let value = env[key], !value.isEmpty else { return nil }
            return (key, value)
        }
    }

    private var logs: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.x2) {
                ForEach(AppModel.LogTab.allCases) { tab in
                    Button(tab.rawValue) { model.logTab = tab }
                        .buttonStyle(.plain)
                        .font(Theme.mono(10, weight: model.logTab == tab ? .medium : .regular))
                        .foregroundStyle(model.logTab == tab ? Theme.ink : Theme.muted)
                }
                Spacer()
                Button("copy") { model.copyVisibleLog() }
                    .buttonStyle(.plain)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.Space.x2)
            .padding(.vertical, Theme.Space.x2)
            hairline
            ScrollViewReader { proxy in
                ScrollView {
                    logBody
                        .id("log-end")
                        .padding(.horizontal, Theme.Space.x2)
                        .padding(.bottom, Theme.Space.x2)
                }
                .onChange(of: visibleLog) { _, _ in
                    proxy.scrollTo("log-end", anchor: .bottom)
                }
            }
        }
        .frame(width: 400)
        .background(Theme.surface)
    }

    private var visibleLog: String {
        switch model.logTab {
        case .errors: return model.errorLog
        case .events: return model.runtimeLog
        case .title: return model.gameLog
        }
    }

    private var exitLabel: String {
        guard let code = model.session?.lastExit else { return "—" }
        return code == 0 ? "0" : "\(code) · failed"
    }

    private var logBody: some View {
        let text = visibleLog
        return Text(text.isEmpty ? emptyLog : text)
            .font(Theme.mono(10))
            .foregroundStyle(text.isEmpty ? Theme.muted : (model.logTab == .errors ? Theme.error : Theme.body))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyLog: String {
        model.logTab == .errors ? "no errors yet — Install / Play land here" : "—"
    }

    @ViewBuilder
    private var accountBar: some View {
        @Bindable var model = model
        let gettingCode = model.install?.titleId == "steam-login" && model.install?.running == true
        let blocked = model.isBusy || model.install?.running == true
            || model.steamUser.isEmpty || model.steamPassword.isEmpty
        VStack(alignment: .leading, spacing: Theme.Space.x2) {
            HStack(spacing: Theme.Space.x2) {
                accountField("account name", text: $model.steamUser)
                accountField("password", text: $model.steamPassword, secure: true)
            }
            HStack(spacing: Theme.Space.x2) {
                Button(gettingCode ? "Getting code…" : "Get code") {
                    Task { await model.requestGuard() }
                }
                .buttonStyle(VercelButtonStyle(kind: .secondary, disabled: blocked))
                .disabled(blocked)
                Spacer()
                if model.credentialsSaved {
                    Text("saved")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.success)
                }
                Button("forget") { model.forgetCredentials() }
                    .buttonStyle(.plain)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.muted)
            }
            if showCodeField {
                accountField("code", text: $model.steamGuard)
            }
            Text(accountHint)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, Theme.Space.x3)
        .padding(.bottom, Theme.Space.x2)
        .onChange(of: model.steamUser) { _, _ in model.saveCredentials() }
        .onChange(of: model.steamPassword) { _, _ in model.saveCredentials() }
        .onChange(of: model.steamGuard) { _, _ in model.saveCredentials() }
    }

    private var showCodeField: Bool {
        !model.steamGuard.isEmpty
            || model.install?.phase == "Guard"
            || (!model.bannerIsError && model.banner != nil)
    }

    private var accountHint: String {
        if !model.bannerIsError, model.banner != nil { return "Paste the code, then Install. It's saved on this Mac." }
        if !model.steamGuard.isEmpty { return "Code is saved. Change it only if Steam asks again." }
        return "Account name, not email. Get code, paste it, then Install."
    }

    private func accountField(_ placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .textFieldStyle(.plain)
        .font(Theme.mono(11))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Space.x2)
        .frame(height: 28)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    @ViewBuilder
    private func installSection(_ entry: LibraryEntry) -> some View {
        let inst = model.install
        let active = inst?.titleId == entry.id
        section("install")
        KV("state", active ? (inst?.percentLabel ?? "—") : (entry.canPlay ? "ready" : "missing"))
        KV("bytes", (active ? inst?.bytes : nil) ?? "—")
        KV("line", (active ? inst?.line : nil) ?? "—")
        KV("dest", (active ? inst?.path : nil) ?? "—")
        KV("error", (active ? inst?.error : nil) ?? (model.bannerIsError ? model.lastError : nil) ?? "—")
        if active, inst?.running == true {
            ProgressView(value: inst?.fraction ?? 0)
                .tint(Theme.blue)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func actionButtons(_ entry: LibraryEntry) -> some View {
        let installing = model.install?.titleId == entry.id && model.install?.running == true
        if model.runningIds.contains(entry.id) {
            Button("Stop") { Task { await model.stop(entry) } }
                .buttonStyle(VercelButtonStyle(kind: .secondary))
        } else if installing {
            Button("Stop") { Task { await model.cancelInstall() } }
                .buttonStyle(VercelButtonStyle(kind: .secondary))
            Text("Installing")
                .font(Theme.sans(14, weight: .medium))
                .foregroundStyle(Theme.body)
        } else {
            Button("Locate") { Task { await model.locate(entry) } }
                .buttonStyle(VercelButtonStyle(kind: .secondary))
            if entry.canPlay {
                Button(model.isBusy ? "…" : "Play") { Task { await model.play(entry) } }
                    .buttonStyle(VercelButtonStyle(kind: .primary, disabled: model.isBusy))
                    .disabled(model.isBusy)
            } else {
                let blocked = model.isBusy || model.steamUser.isEmpty || model.steamPassword.isEmpty
                Button(model.isBusy ? "…" : "Install") { Task { await model.install(entry) } }
                    .buttonStyle(VercelButtonStyle(kind: .primary, disabled: blocked))
                    .disabled(blocked)
            }
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(Theme.mono(10, weight: .medium))
            .foregroundStyle(Theme.muted)
            .padding(.top, Theme.Space.x3)
            .padding(.bottom, 2)
    }

    private func rowMeta(_ entry: LibraryEntry, running: Bool) -> String {
        var bits = [entry.profile.id]
        if running { bits.append("run") }
        else if model.install?.titleId == entry.id, model.install?.running == true {
            bits.append(model.install?.percentLabel ?? "Installing")
        }
        else if entry.canPlay { bits.append("exe") }
        else { bits.append("missing") }
        bits.append(entry.profile.antiCheat.rawValue)
        return bits.joined(separator: " · ")
    }
}

private struct KV: View {
    let key: String
    let value: String

    init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.x2) {
            Text(key)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.muted)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MonoStat: View {
    let label: String
    let value: String
    var ok = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ok ? Theme.success : Theme.accents3)
                .frame(width: 6, height: 6)
            Text("\(label) \(value)")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.body)
                .lineLimit(1)
        }
    }
}
