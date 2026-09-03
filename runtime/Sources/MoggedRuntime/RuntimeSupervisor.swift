import Foundation

public struct LibraryEntry: Sendable, Equatable, Identifiable {
    public var id: String { profile.id }
    public let profile: TitleProfile
    public let install: LocatedInstall?
    public var isInstalled: Bool { install != nil }
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
    private var running: [String: ProcessHandle] = [:]

    public init(
        locator: InstallLocator = InstallLocator(),
        library: LibraryStore = LibraryStore(),
        probe: BackendProbe = BackendProbe(),
        telemetry: TelemetryLog = TelemetryLog(),
        configStore: BackendConfigStore = BackendConfigStore(),
        environment: WineEnvironment = WineEnvironment(),
        launcher: BackendLauncher = BackendLauncher()
    ) {
        self.locator = locator
        self.library = library
        self.probe = probe
        self.telemetry = telemetry
        self.configStore = configStore
        self.environment = environment
        self.launcher = launcher
    }

    public func libraryEntries(profiles: [TitleProfile]) -> [LibraryEntry] {
        profiles.map { profile in
            let override = library.overridePath(for: profile.id)
            let install = locator.locate(profile: profile, overridePath: override)
            return LibraryEntry(profile: profile, install: install)
        }
        .sorted { lhs, rhs in
            roleRank(lhs.profile.role) < roleRank(rhs.profile.role)
        }
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

    private func fail(_ titleId: String, _ error: MoggedError) {
        telemetry.record(TelemetryEvent(event: "launch.failed", titleId: titleId, detail: error.logDescription))
    }

    private func fail(_ titleId: String, _ detail: String) {
        telemetry.record(TelemetryEvent(event: "launch.failed", titleId: titleId, detail: detail))
    }

    private func roleRank(_ role: TitleProfile.Role) -> Int {
        switch role {
        case .smoke: return 0
        case .primaryDemo: return 1
        case .generalize: return 2
        }
    }
}
