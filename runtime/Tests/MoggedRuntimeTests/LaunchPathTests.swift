import Foundation
import Testing
@testable import MoggedRuntime

@Suite(.serialized)
struct LaunchPathTests {
    @Test
    func backendConfigRoundTrip() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        let store = BackendConfigStore(paths: paths)
        let saved = BackendConfig(wine: "/tmp/fake-wine")
        try store.save(saved)
        #expect(store.load() == saved)
    }

    @Test
    func wineEnvironmentCreatesPrefixAndCache() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let env = WineEnvironment(paths: RuntimePaths(root: home))
        let trees = try env.ensure(for: "apex-legends")
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: trees.prefix.path, isDirectory: &isDir) && isDir.boolValue)
        #expect(env.needsInit(prefix: trees.prefix))
        try env.markReady(prefix: trees.prefix)
        #expect(!env.needsInit(prefix: trees.prefix))
    }

    @Test
    func launchPlanUsesProfileAndPrefix() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        let profile = try smokeProfile()
        let exe = URL(fileURLWithPath: "/tmp/r5apex.exe")
        let prefix = home.appendingPathComponent("environments/apex-legends")
        let cache = home.appendingPathComponent("caches/apex-legends")
        let plan = BackendLauncher(paths: paths).plan(
            profile: profile,
            exe: exe,
            prefix: prefix,
            cache: cache,
            config: BackendConfig(wine: "/opt/homebrew/bin/wine64"),
            thermal: .nominal
        )
        #expect(plan.executable.path == "/opt/homebrew/bin/wine64")
        #expect(plan.arguments.first == exe.path)
        #expect(plan.environment["WINEPREFIX"] == prefix.path)
        #expect(plan.environment["DXVK_STATE_CACHE_PATH"] == cache.path)
        #expect(plan.environment["DXVK_FRAME_RATE"] == "60")
        #expect(plan.environment["WINEDLLOVERRIDES"] == "d3d11,d3d10core=n,b")
        #expect(plan.workingDirectory.lastPathComponent == "tmp")
    }

    @Test
    func deskJobLaunchesFromGameFolderWithDXVK() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let install = home.appendingPathComponent("games/aperture-desk-job")
        let game = install.appendingPathComponent("game/steampal")
        try FileManager.default.createDirectory(at: game, withIntermediateDirectories: true)
        let profile = try ProfileLoader.load().first { $0.id == "aperture-desk-job" }!
        let exe = install.appendingPathComponent("game/bin/win64/deskjob.exe")
        let plan = BackendLauncher(paths: RuntimePaths(root: home)).plan(
            profile: profile,
            exe: exe,
            prefix: home.appendingPathComponent("prefix"),
            cache: home.appendingPathComponent("cache"),
            config: BackendConfig(wine: "/opt/homebrew/bin/wine64"),
            installRoot: install,
            thermal: .nominal
        )
        #expect(plan.arguments.contains("-game"))
        #expect(plan.arguments.contains("steampal"))
        #expect(plan.workingDirectory.lastPathComponent == "game")
        #expect(plan.environment["WINEDLLOVERRIDES"] == "d3d11,d3d10core=n,b")
        #expect(plan.environment["SteamAppId"] == "1902490")

        BackendLauncher.ensureSteamInf(installRoot: install, profile: profile)
        let inf = game.appendingPathComponent("steam.inf")
        let text = try String(contentsOf: inf, encoding: .utf8)
        #expect(text.contains("appID=1902490"))
        #expect(text.contains("steampal"))
    }

    @Test
    func optimizationCapsWhenHot() throws {
        let profile = try smokeProfile()
        let hot = OptimizationLayer().policy(for: profile, thermal: .serious)
        #expect(hot.fpsCap == 40)
        #expect(hot.rayTracing == "off")
        var env: [String: String] = [:]
        OptimizationLayer().apply(hot, into: &env)
        #expect(env["DXVK_FRAME_RATE"] == "40")
        #expect(env["MOGGED_THERMAL"] == "serious")
    }

    @Test
    func remapsPaidBackendToFreeStack() throws {
        let profile = try decodeProfile("""
        {
          "id": "remap-test",
          "steamAppId": 1,
          "displayName": "Remap",
          "role": "smoke",
          "engine": "test",
          "graphicsApi": "d3d12",
          "antiCheat": "none",
          "macNative": false,
          "backend": { "preferred": "d3dmetal" },
          "executables": ["game.exe"]
        }
        """)
        #expect(BackendLauncher().graphicsStack(for: profile) == "vkd3d-moltenvk")
    }

    @Test
    func spiderManUsesVkd3d() throws {
        let profile = try ProfileLoader.load().first { $0.id == "spider-man-remastered" }!
        #expect(BackendLauncher().graphicsStack(for: profile) == "vkd3d-moltenvk")
    }

    @Test
    func launchWithoutWineIsUnavailable() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let (supervisor, _) = try makeSupervisor(home: home, wine: nil)
        let profile = try smokeProfile()
        try await supervisor.rememberInstall(titleId: profile.id, folder: try makeGameFolder(home: home, profile: profile))
        await #expect(throws: MoggedError.runtimeUnavailable) {
            _ = try await supervisor.launch(profile: profile)
        }
    }

    @Test
    func launchAndStopThroughFakeWine() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let wine = try writeFakeWine(in: home, hold: true)
        let (supervisor, paths) = try makeSupervisor(home: home, wine: wine.path)
        try BackendConfigStore(paths: paths).save(BackendConfig(wine: wine.path))
        let profile = try smokeProfile()
        let game = try makeGameFolder(home: home, profile: profile)
        try await supervisor.rememberInstall(titleId: profile.id, folder: game)

        let state = try await supervisor.launch(profile: profile)
        #expect(state.pid > 0)
        #expect(await supervisor.runningTitleIds().contains(profile.id))

        try await supervisor.stop(titleId: profile.id)
        var empty = false
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            empty = await supervisor.runningTitleIds().isEmpty
            if empty { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(empty)

        let log = try String(contentsOf: paths.logs.appendingPathComponent("runtime.jsonl"), encoding: .utf8)
        #expect(log.contains("launch.requested"))
        #expect(log.contains("launch.started"))
        #expect(log.contains("launch.stopped"))
        #expect(FileManager.default.fileExists(atPath: paths.environments.appendingPathComponent(profile.id).path))
    }
}

private func scratchHome() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("mogged-launch-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeSupervisor(home: URL, wine: String?) throws -> (RuntimeSupervisor, RuntimePaths) {
    let paths = RuntimePaths(root: home)
    let supervisor = RuntimeSupervisor(
        library: LibraryStore(paths: paths),
        probe: BackendProbe(fixedWine: wine),
        telemetry: TelemetryLog(paths: paths),
        configStore: BackendConfigStore(paths: paths),
        environment: WineEnvironment(paths: paths),
        launcher: BackendLauncher(paths: paths)
    )
    return (supervisor, paths)
}

private func writeFakeWine(in dir: URL, hold: Bool) throws -> URL {
    let url = dir.appendingPathComponent("fake-wine")
    let holdLine = hold ? "sleep 60" : "true"
    let script = """
    #!/bin/sh
    echo "$*" >> "$(dirname "$0")/invocations.txt"
    if [ "$1" = "wineboot" ]; then
      mkdir -p "$WINEPREFIX"
      touch "$WINEPREFIX/system.reg"
      exit 0
    fi
    \(holdLine)
    exit 0
    """
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}

private func makeGameFolder(home: URL, profile: TitleProfile) throws -> URL {
    let game = home.appendingPathComponent("game")
    try FileManager.default.createDirectory(at: game, withIntermediateDirectories: true)
    try Data().write(to: game.appendingPathComponent(profile.executables[0]))
    return game
}

private func smokeProfile() throws -> TitleProfile {
    try ProfileLoader.load().first { $0.id == "apex-legends" }!
}

private func decodeProfile(_ json: String) throws -> TitleProfile {
    try JSONDecoder().decode(TitleProfile.self, from: Data(json.utf8))
}
