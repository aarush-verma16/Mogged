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
    private var running: [String: Process] = [:]

    public init(
        locator: InstallLocator = InstallLocator(),
        library: LibraryStore = LibraryStore(),
        probe: BackendProbe = BackendProbe(),
        telemetry: TelemetryLog = TelemetryLog()
    ) {
        self.locator = locator
        self.library = library
        self.probe = probe
        self.telemetry = telemetry
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
            telemetry.record(TelemetryEvent(event: "launch.failed", titleId: profile.id, detail: MoggedError.gameNotFound(profile.id).logDescription))
            throw MoggedError.gameNotFound(profile.id)
        }

        guard let exe = install.executable else {
            telemetry.record(TelemetryEvent(event: "launch.failed", titleId: profile.id, detail: "exe missing"))
            throw MoggedError.executableNotFound(profile.executables.first ?? profile.id)
        }

        guard probe.isAvailable else {
            telemetry.record(TelemetryEvent(event: "launch.failed", titleId: profile.id, detail: MoggedError.runtimeUnavailable.logDescription))
            throw MoggedError.runtimeUnavailable
        }

        // Real backend spawn lands in M1 once an eval engine is installed on this Mac.
        // We refuse rather than exec a .exe with open(1) and calling that a launch.
        _ = exe
        telemetry.record(TelemetryEvent(event: "launch.blocked", titleId: profile.id, detail: "backend present but spawn not wired"))
        throw MoggedError.runtimeUnavailable
    }

    public func stop(titleId: String) throws {
        guard let process = running.removeValue(forKey: titleId) else {
            throw MoggedError.notRunning(titleId)
        }
        process.terminate()
        telemetry.record(TelemetryEvent(event: "launch.stopped", titleId: titleId))
    }

    public func runningTitleIds() -> [String] {
        Array(running.keys)
    }

    public func backendReady() -> Bool {
        probe.isAvailable
    }

    private func roleRank(_ role: TitleProfile.Role) -> Int {
        switch role {
        case .smoke: return 0
        case .primaryDemo: return 1
        case .generalize: return 2
        }
    }
}
