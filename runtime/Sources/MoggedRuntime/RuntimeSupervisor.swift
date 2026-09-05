import Foundation

public struct LibraryEntry: Sendable, Equatable, Identifiable {
    public var id: String { profile.id }
    public let profile: TitleProfile
    public let install: LocatedInstall?
    public let coverURL: URL?
    public let lastPlayed: Int?
    public var isInstalled: Bool { install != nil }
    public var canPlay: Bool { install?.executable != nil && !profile.macNative }
}

public struct LaunchState: Sendable, Equatable {
    public let titleId: String
    public let pid: Int32
}

/// Hidden supervisor. The app calls this; the player never sees it.
public actor RuntimeSupervisor {
    private let locator: InstallLocator
    private let library: LibraryStore
    private let probe: BackendProbe
    private let telemetry: TelemetryLog
    private let configStore: BackendConfigStore
    private let environment: WineEnvironment
    private let launcher: BackendLauncher
    private let catalog: SteamCatalog
    private let installer: DepotInstaller
    private let services: SteamServices
    private var running: [String: ProcessHandle] = [:]
    private var lastPlan: [String: LaunchPlan] = [:]
    private var lastExit: [String: Int32] = [:]
    private var steamClient: ProcessHandle?

    public init(
        locator: InstallLocator? = nil,
        library: LibraryStore = LibraryStore(),
        probe: BackendProbe = BackendProbe(),
        telemetry: TelemetryLog = TelemetryLog(),
        configStore: BackendConfigStore = BackendConfigStore(),
        environment: WineEnvironment = WineEnvironment(),
        launcher: BackendLauncher = BackendLauncher(),
        catalog: SteamCatalog = SteamCatalog(),
        installer: DepotInstaller = DepotInstaller(),
        services: SteamServices = SteamServices()
    ) {
        self.catalog = catalog
        self.locator = locator ?? InstallLocator(catalog: catalog)
        self.library = library
        self.probe = probe
        self.telemetry = telemetry
        self.configStore = configStore
        self.environment = environment
        self.launcher = launcher
        self.installer = installer
        self.services = services
    }

    public func steamSnapshot() -> SteamSnapshot {
        catalog.snapshot()
    }

    public func libraryEntries(profiles: [TitleProfile]) -> [LibraryEntry] {
        let snapshot = catalog.snapshot()
        let profilesByAppId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.steamAppId, $0) })
        var entries: [LibraryEntry] = []
        var seen = Set<Int>()

        for app in snapshot.apps {
            if app.isTool || app.macNativeOnly { continue }
            seen.insert(app.appId)
            let profile = profilesByAppId[app.appId] ?? TitleProfile.fromSteam(app)
            entries.append(makeEntry(profile: profile, steam: app))
        }

        if let smoke = profiles.first(where: { $0.role == .smoke }), !seen.contains(smoke.steamAppId) {
            entries.append(makeEntry(profile: smoke, steam: nil))
        }

        for profile in profiles where profile.isPinned && !seen.contains(profile.steamAppId) && profile.role != .smoke {
            seen.insert(profile.steamAppId)
            entries.append(makeEntry(profile: profile, steam: nil))
        }

        return entries.sorted(by: Self.sortLibrary)
    }

    public func rememberInstall(titleId: String, folder: URL) throws {
        try library.setOverride(titleId: titleId, path: folder.path)
        telemetry.record(TelemetryEvent(event: "library.located", titleId: titleId, detail: folder.path))
    }

    public func startInstall(
        profile: TitleProfile,
        username: String,
        password: String,
        guardCode: String?
    ) async throws {
        if running[profile.id] != nil {
            throw MoggedError.alreadyRunning(profile.id)
        }
        telemetry.record(TelemetryEvent(event: "install.requested", titleId: profile.id))
        try await installer.ensureSteamCMD()
        try installer.start(
            profile: profile,
            username: username,
            password: password,
            guardCode: guardCode
        ) { [weak self] snap in
            guard let self else { return }
            Task { await self.noteInstallExit(snap) }
        }
        telemetry.record(TelemetryEvent(event: "install.started", titleId: profile.id))
    }

    public func requestGuard(username: String, password: String) async throws {
        telemetry.record(TelemetryEvent(event: "login.guard.requested", titleId: "steam-login"))
        try await installer.ensureSteamCMD()
        try installer.startLogin(username: username, password: password) { [weak self] snap in
            guard let self else { return }
            Task { await self.noteInstallExit(snap) }
        }
    }

    public func cancelInstall() {
        installer.cancel()
        telemetry.record(TelemetryEvent(event: "install.stopped", titleId: installer.current().titleId))
    }

    public func inspectInstall() -> InstallSnapshot? {
        let snap = installer.current()
        return snap.titleId.isEmpty ? nil : snap
    }

    public func launch(profile: TitleProfile) throws -> LaunchState {
        if running[profile.id] != nil {
            throw MoggedError.alreadyRunning(profile.id)
        }

        if ProcessInfo.processInfo.thermalState == .critical {
            fail(profile.id, "thermal critical")
            throw MoggedError.launchFailed
        }

        telemetry.record(TelemetryEvent(event: "launch.requested", titleId: profile.id))

        let override = library.overridePath(for: profile.id)
        guard let install = locator.locate(profile: profile, overridePath: override) else {
            fail(profile.id, MoggedError.gameNotFound(profile.id))
            throw MoggedError.gameNotFound(profile.id)
        }

        guard let exe = install.executable else {
            fail(profile.id, "exe missing")
            throw MoggedError.executableNotFound(profile.executables.first ?? profile.id)
        }

        let config: BackendConfig
        do {
            config = try configStore.resolve(discover: { probe.wineBinary() })
        } catch {
            fail(profile.id, MoggedError.runtimeUnavailable.logDescription)
            throw MoggedError.runtimeUnavailable
        }

        let trees: (prefix: URL, cache: URL)
        do {
            trees = try environment.ensure(for: profile.id)
        } catch {
            fail(profile.id, "environment create failed")
            throw MoggedError.launchFailed
        }

        preparePrefix(prefix: trees.prefix, profile: profile, config: config)
        startSteamServicesIfNeeded(profile: profile, prefix: trees.prefix, config: config)

        BackendLauncher.ensureSteamInf(installRoot: install.path, profile: profile)
        let plan = launcher.plan(
            profile: profile,
            exe: exe,
            prefix: trees.prefix,
            cache: trees.cache,
            config: config,
            installRoot: install.path
        )

        let titleId = profile.id
        let handle: ProcessHandle
        do {
            handle = try ProcessHandle.spawn(plan) { [weak self] code in
                guard let self else { return }
                Task { await self.noteExit(titleId: titleId, code: code) }
            }
        } catch {
            fail(profile.id, MoggedError.launchFailed.logDescription)
            throw MoggedError.launchFailed
        }

        running[profile.id] = handle
        lastPlan[profile.id] = plan
        telemetry.record(
            TelemetryEvent(
                event: "launch.started",
                titleId: profile.id,
                detail: "pid=\(handle.pid) stack=\(launcher.graphicsStack(for: profile))"
            )
        )
        return LaunchState(titleId: profile.id, pid: handle.pid)
    }

    public func stop(titleId: String) throws {
        guard let handle = running.removeValue(forKey: titleId) else {
            throw MoggedError.notRunning(titleId)
        }
        handle.terminate()
        telemetry.record(TelemetryEvent(event: "launch.stopped", titleId: titleId))
    }

    public func runningTitleIds() -> [String] {
        running = running.filter { $0.value.isRunning }
        return Array(running.keys)
    }

    public func backendReady() -> Bool {
        if let existing = configStore.load(), existing.wineIsExecutable {
            return true
        }
        return probe.isAvailable
    }

    /// Steam Input and SteamAPI_Init only work with Steam running in the same prefix.
    private func startSteamServicesIfNeeded(profile: TitleProfile, prefix: URL, config: BackendConfig) {
        guard profile.settings?.needsSteamClient == true else { return }
        if steamClient?.isRunning == true { return }

        guard let exe = SteamServices.clientExe(prefix: prefix) else {
            telemetry.record(
                TelemetryEvent(
                    event: "steam.services.missing",
                    titleId: profile.id,
                    detail: "Steam Input needs Steam installed for this game. Click Add Steam."
                )
            )
            return
        }

        do {
            steamClient = try services.start(prefix: prefix, config: config, exe: exe)
            telemetry.record(TelemetryEvent(event: "steam.services.started", titleId: profile.id))
            Thread.sleep(forTimeInterval: 3)
        } catch {
            telemetry.record(
                TelemetryEvent(
                    event: "steam.services.failed",
                    titleId: profile.id,
                    detail: "Steam Input unavailable."
                )
            )
        }
    }

    /// One-time: put Steam in this title's environment so Steam Input works.
    public func addSteamServices(profile: TitleProfile) async throws {
        let config = try configStore.resolve(discover: { probe.wineBinary() })
        let trees = try environment.ensure(for: profile.id)
        preparePrefix(prefix: trees.prefix, profile: profile, config: config)

        if SteamServices.clientExe(prefix: trees.prefix) != nil {
            telemetry.record(TelemetryEvent(event: "steam.services.present", titleId: profile.id))
            return
        }

        telemetry.record(TelemetryEvent(event: "steam.services.install", titleId: profile.id))
        let installer = try await services.downloadInstaller()
        try services.install(prefix: trees.prefix, config: config, installer: installer)

        guard SteamServices.clientExe(prefix: trees.prefix) != nil else {
            throw MoggedError.installFailed("Couldn't add Steam for this game.")
        }
        telemetry.record(TelemetryEvent(event: "steam.services.added", titleId: profile.id))
    }

    public func steamServicesReady(profile: TitleProfile) -> Bool {
        SteamServices.clientExe(prefix: environment.prefixURL(for: profile.id)) != nil
    }

    private func preparePrefix(prefix: URL, profile: TitleProfile, config: BackendConfig) {
        if environment.needsInit(prefix: prefix) {
            let boot = launcher.winebootPlan(prefix: prefix, config: config)
            if let handle = try? ProcessHandle.spawn(boot) {
                _ = handle.waitUntilExit(timeout: 120)
            }
            try? environment.markReady(prefix: prefix)
        }
        launcher.overlayTranslationDLLs(prefix: prefix, profile: profile, config: config)
    }

    private func noteExit(titleId: String, code: Int32) {
        running.removeValue(forKey: titleId)
        lastExit[titleId] = code
        let event = code == 0 ? "launch.exited" : "launch.failed"
        telemetry.record(TelemetryEvent(event: event, titleId: titleId, detail: "code=\(code)"))
    }

    public func inspectRuntime() -> RuntimeInspect {
        let snap = catalog.snapshot()
        let config = configStore.load()
        let wine = config?.wine ?? probe.wineBinary()
        let paths = RuntimePaths.standard()
        return RuntimeInspect(
            wine: wine,
            wineReady: backendReady(),
            backend: config,
            supportRoot: paths.root.path,
            logsDir: paths.logs.path,
            steamPresent: snap.present,
            steamRunning: snap.running,
            steamRoot: snap.root?.path,
            steamAccount: snap.account?.personaName ?? snap.account?.steamId,
            steamAppCount: snap.apps.count
        )
    }

    public func inspectSession(profile: TitleProfile, install: LocatedInstall?) -> SessionInspect {
        let trees = (
            prefix: environment.prefixURL(for: profile.id),
            cache: environment.cacheURL(for: profile.id)
        )
        let plan = lastPlan[profile.id] ?? (install?.executable).map {
            launcher.plan(
                profile: profile,
                exe: $0,
                prefix: trees.prefix,
                cache: trees.cache,
                config: configStore.load() ?? BackendConfig(wine: probe.wineBinary() ?? ""),
                installRoot: install?.path
            )
        }
        let handle = running[profile.id]
        let log = plan?.logURL ?? RuntimePaths.standard().logs.appendingPathComponent("\(profile.id).log")
        let policy = OptimizationLayer().policy(for: profile)
        return SessionInspect(
            titleId: profile.id,
            pid: handle?.isRunning == true ? handle?.pid : nil,
            running: handle?.isRunning == true,
            lastExit: lastExit[profile.id],
            prefix: trees.prefix.path,
            cache: trees.cache.path,
            logPath: log.path,
            exe: install?.executable?.path ?? plan?.arguments.first,
            install: install?.path.path,
            stack: launcher.graphicsStack(for: profile),
            env: plan?.environment ?? [:],
            prefixReady: !environment.needsInit(prefix: trees.prefix),
            optimization: policy
        )
    }

    public func telemetryTail() -> String {
        telemetry.tailJSONL()
    }

    public func gameLogTail(titleId: String) -> String {
        let url = lastPlan[titleId]?.logURL
            ?? RuntimePaths.standard().logs.appendingPathComponent("\(titleId).log")
        return TelemetryLog.tail(url: url)
    }

    private func makeEntry(profile: TitleProfile, steam: SteamLibraryApp?) -> LibraryEntry {
        let override = library.overridePath(for: profile.id)
            ?? library.overridePath(for: "steam-\(profile.steamAppId)")
        let fromLocator = locator.locate(profile: profile, overridePath: override)
        let install: LocatedInstall?
        if let fromLocator {
            install = fromLocator
        } else if let path = steam?.installPath {
            let exe = locator.findExecutable(in: path, names: profile.executables)
                ?? locator.windowsExecutables(in: path).first
            install = LocatedInstall(path: path, executable: exe)
        } else {
            install = nil
        }
        return LibraryEntry(
            profile: profile,
            install: install,
            coverURL: steam?.coverURL,
            lastPlayed: steam?.lastPlayed
        )
    }

    private static func sortLibrary(_ lhs: LibraryEntry, _ rhs: LibraryEntry) -> Bool {
        let l = pinRank(lhs.profile)
        let r = pinRank(rhs.profile)
        if l != r { return l < r }
        if lhs.isInstalled != rhs.isInstalled { return lhs.isInstalled && !rhs.isInstalled }
        let lp = lhs.lastPlayed ?? 0
        let rp = rhs.lastPlayed ?? 0
        if lp != rp { return lp > rp }
        return lhs.profile.displayName.localizedCaseInsensitiveCompare(rhs.profile.displayName) == .orderedAscending
    }

    private static func pinRank(_ profile: TitleProfile) -> Int {
        if profile.role == .smoke { return 0 }
        if profile.isPinned { return 1 }
        return 2
    }

    private func noteInstallExit(_ snap: InstallSnapshot) {
        if snap.titleId == "steam-login" {
            telemetry.record(TelemetryEvent(event: "login.guard", titleId: snap.titleId, detail: snap.line))
            return
        }
        if snap.succeeded {
            try? library.setOverride(titleId: snap.titleId, path: snap.path)
            telemetry.record(TelemetryEvent(event: "install.finished", titleId: snap.titleId, detail: snap.path))
        } else {
            telemetry.record(
                TelemetryEvent(event: "install.failed", titleId: snap.titleId, detail: snap.error ?? snap.line)
            )
        }
    }

    private func fail(_ titleId: String, _ error: MoggedError) {
        telemetry.record(TelemetryEvent(event: "launch.failed", titleId: titleId, detail: error.logDescription))
    }

    private func fail(_ titleId: String, _ detail: String) {
        telemetry.record(TelemetryEvent(event: "launch.failed", titleId: titleId, detail: detail))
    }
}
