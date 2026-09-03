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
    private var running: [String: ProcessHandle] = [:]

    public init(
        locator: InstallLocator? = nil,
        library: LibraryStore = LibraryStore(),
        probe: BackendProbe = BackendProbe(),
        telemetry: TelemetryLog = TelemetryLog(),
        configStore: BackendConfigStore = BackendConfigStore(),
        environment: WineEnvironment = WineEnvironment(),
        launcher: BackendLauncher = BackendLauncher(),
        catalog: SteamCatalog = SteamCatalog()
    ) {
        self.catalog = catalog
        self.locator = locator ?? InstallLocator(catalog: catalog)
        self.library = library
        self.probe = probe
        self.telemetry = telemetry
        self.configStore = configStore
        self.environment = environment
        self.launcher = launcher
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

        return entries.sorted(by: Self.sortLibrary)
    }

    public func rememberInstall(titleId: String, folder: URL) throws {
        try library.setOverride(titleId: titleId, path: folder.path)
        telemetry.record(TelemetryEvent(event: "library.located", titleId: titleId, detail: folder.path))
    }

    public func launch(profile: TitleProfile) throws -> LaunchState {
        if running[profile.id] != nil {
            throw MoggedError.alreadyRunning(profile.id)
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

        let plan = launcher.plan(
            profile: profile,
            exe: exe,
            prefix: trees.prefix,
            cache: trees.cache,
            config: config
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
        telemetry.record(TelemetryEvent(event: "launch.exited", titleId: titleId, detail: "code=\(code)"))
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
        if lhs.profile.role == .smoke && rhs.profile.role != .smoke { return true }
        if rhs.profile.role == .smoke && lhs.profile.role != .smoke { return false }
        if lhs.isInstalled != rhs.isInstalled { return lhs.isInstalled && !rhs.isInstalled }
        let lp = lhs.lastPlayed ?? 0
        let rp = rhs.lastPlayed ?? 0
        if lp != rp { return lp > rp }
        return lhs.profile.displayName.localizedCaseInsensitiveCompare(rhs.profile.displayName) == .orderedAscending
    }

    private func fail(_ titleId: String, _ error: MoggedError) {
        telemetry.record(TelemetryEvent(event: "launch.failed", titleId: titleId, detail: error.logDescription))
    }

    private func fail(_ titleId: String, _ detail: String) {
        telemetry.record(TelemetryEvent(event: "launch.failed", titleId: titleId, detail: detail))
    }
}
