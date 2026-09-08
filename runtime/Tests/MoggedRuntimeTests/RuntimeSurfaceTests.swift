import Foundation
import Testing
@testable import MoggedRuntime

@Suite("Runtime surface")
struct RuntimeSurfaceTests {
    @Test
    func inputLayerWritesSDLJoystickEnvAndHostPlist() throws {
        var env: [String: String] = ["KEEP": "1"]
        InputLayer.apply(into: &env)
        #expect(env["KEEP"] == "1")
        #expect(env["SDL_JOYSTICK_HIDAPI"] == "1")
        #expect(env["SDL_JOYSTICK_MFI"] == "1")
        #expect(env["SDL_JOYSTICK_HIDAPI_PS5"] == "1")
        #expect(env["SDL_JOYSTICK_HIDAPI_XBOX"] == "1")
        #expect(!InputLayer.environment().isEmpty)

        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let contents = home.appendingPathComponent("FakeWine.app/Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        let plist = contents.appendingPathComponent("Info.plist")
        let plistBody: [String: Any] = ["CFBundleIdentifier": "test.wine"]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plistBody, format: .xml, options: 0)
        try plistData.write(to: plist)
        let wine = contents.appendingPathComponent("MacOS/wine")
        try Data().write(to: wine)

        InputLayer.ensureHostAllowsControllers(wine: wine)
        let loaded = NSDictionary(contentsOf: plist)
        #expect(loaded?["GCSupportsControllerUserInteraction"] as? Bool == true)
        InputLayer.ensureHostAllowsControllers(wine: wine)
        #expect(InputLayer.statusLabel == "none" || !InputLayer.statusLabel.isEmpty)
        #expect(ConnectedController(name: "Pad") == ConnectedController(name: "Pad"))
    }

    @Test
    func optimizationCapsEveryThermalState() throws {
        let profile = try smokeProfile()
        let layer = OptimizationLayer()
        let expected: [(ProcessInfo.ThermalState, Int, String)] = [
            (.nominal, 60, "nominal"),
            (.fair, 60, "fair"),
            (.serious, 40, "serious"),
            (.critical, 30, "critical"),
        ]
        for (thermal, fps, name) in expected {
            let policy = layer.policy(for: profile, thermal: thermal)
            #expect(policy.fpsCap == fps)
            #expect(policy.thermal == name)
            #expect(policy.rayTracing == "off")
            var env: [String: String] = [:]
            layer.apply(policy, into: &env)
            #expect(env["DXVK_FRAME_RATE"] == "\(fps)")
            #expect(env["MOGGED_THERMAL"] == name)
            #expect(env["MVK_CONFIG_PREALLOCATE_DESCRIPTORS"] == "0")
        }
        let policy = OptimizationPolicy(fpsCap: 60, upscaler: "fsr-quality", rayTracing: "off", thermal: "nominal", dxvkHUD: "fps", reason: "test")
        #expect(policy.upscaler == "fsr-quality")
    }

    @Test
    func libraryStoreRoundTripsOverrides() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        let store = LibraryStore(paths: paths)
        #expect(store.load() == LibraryFile.empty)
        try store.setOverride(titleId: "apex-legends", path: "/tmp/apex")
        #expect(store.overridePath(for: "apex-legends") == "/tmp/apex")
        let record = InstallRecord(titleId: "apex-legends", path: "/tmp/apex")
        #expect(store.load().overrides == [record])
        #expect(AppSupport.defaultRoot.lastPathComponent == "Mogged")
    }

    @Test
    func runtimePathsEnsureCreatesTheTree() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        try paths.ensure()
        for url in [paths.logs, paths.environments, paths.caches, paths.steamcmd, paths.games] {
            var isDir: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue)
        }
        #expect(paths.gameFolder(for: "desk").lastPathComponent == "desk")
        #expect(paths.libraryURL.lastPathComponent == "library.json")
        #expect(paths.dxvk.path.contains("dxvk"))
    }

    @Test
    func telemetryAppendsAndTailsJSONL() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        let log = TelemetryLog(paths: paths)
        log.record(TelemetryEvent(event: "test.one", titleId: "apex-legends", detail: "a"))
        log.record(TelemetryEvent(event: "test.two", titleId: "apex-legends", detail: "b"))
        let text = log.tailJSONL()
        #expect(text.contains("test.one"))
        #expect(text.contains("test.two"))
        #expect(TelemetryLog.tail(url: home.appendingPathComponent("missing.jsonl")).isEmpty)

        let big = home.appendingPathComponent("big.log")
        try Data(repeating: 0x41, count: 200).write(to: big)
        #expect(TelemetryLog.tail(url: big, maxBytes: 50).count <= 50)
    }

    @Test
    func processHandleSpawnsWaitsAndTrims() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let log = home.appendingPathComponent("proc.log")
        let plan = LaunchPlan(
            executable: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["mogged-ok"],
            environment: [:],
            workingDirectory: home,
            logURL: log
        )
        let handle = try ProcessHandle.spawn(plan)
        #expect(handle.pid > 0)
        #expect(handle.waitUntilExit(timeout: 5))
        let body = try String(contentsOf: log, encoding: .utf8)
        #expect(body.contains("mogged-ok"))

        let huge = home.appendingPathComponent("huge.log")
        try Data(repeating: 0x42, count: ProcessHandle.logByteLimit + 1024).write(to: huge)
        ProcessHandle.trimLog(at: huge)
        let size = (try FileManager.default.attributesOfItem(atPath: huge.path)[.size]) as? Int
        #expect((size ?? .max) <= ProcessHandle.logByteLimit)
    }

    @Test
    func backendConfigResolvesWhenSavedWineIsGone() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        let store = BackendConfigStore(paths: paths)
        try store.save(BackendConfig(wine: "/nope/wine"))
        let resolved = try store.resolve(discover: { "/bin/echo" })
        #expect(resolved.wine == "/bin/echo")
        #expect(store.load()?.wine == "/bin/echo")
        #expect(resolved.wineURL.path == "/bin/echo")

        #expect(!BackendProbe(fixedWine: nil).isAvailable)
        #expect(BackendProbe(fixedWine: "/bin/echo").isAvailable)
        #expect(BackendProbe(fixedWine: "/bin/echo").detect().first?.kind == .wine)
        #expect(BackendProbe(fixedWine: "/bin/echo").wineBinary() == "/bin/echo")
    }

    @Test
    func windowPixelsClampAndWorkingDirectoryFallsBack() throws {
        let tiny = try decodeProfile("""
        {
          "id": "tiny",
          "steamAppId": 1,
          "displayName": "Tiny",
          "role": "catalog",
          "engine": "test",
          "graphicsApi": "d3d11",
          "antiCheat": "none",
          "macNative": false,
          "backend": { "preferred": "moltenvk" },
          "executables": ["game.exe"],
          "launch": { "workingDirectory": "missing", "window": { "mode": "windowed", "width": 10, "height": 10 } }
        }
        """)
        #expect(tiny.launch?.window?.pixelWidth == 640)
        #expect(tiny.launch?.window?.pixelHeight == 480)
        #expect(tiny.launch?.window?.size == "640x480")
        #expect(tiny.launch?.window?.isWindowed == true)
        #expect(BackendLauncher().graphicsStack(for: tiny) == "moltenvk")

        let exe = URL(fileURLWithPath: "/tmp/game.exe")
        let cwd = BackendLauncher.workingDirectory(profile: tiny, exe: exe, installRoot: URL(fileURLWithPath: "/tmp"))
        #expect(cwd == exe.deletingLastPathComponent())
        BackendLauncher.ensureSteamInf(installRoot: URL(fileURLWithPath: "/tmp"), profile: tiny)
    }

    @Test
    func winebootAndDLLOverlayUseThePrefix() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        try paths.ensure()
        let launcher = BackendLauncher(paths: paths)
        let prefix = home.appendingPathComponent("prefix")
        let sys32 = prefix.appendingPathComponent("drive_c/windows/system32")
        try FileManager.default.createDirectory(at: sys32, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.dxvk, withIntermediateDirectories: true)
        try Data("dxvk".utf8).write(to: paths.dxvk.appendingPathComponent("d3d11.dll"))

        let wine = home.appendingPathComponent("bin/wine")
        try FileManager.default.createDirectory(at: wine.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: wine)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
        let wineserver = wine.deletingLastPathComponent().appendingPathComponent("wineserver")
        try Data().write(to: wineserver)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wineserver.path)
        let wineboot = wine.deletingLastPathComponent().appendingPathComponent("wineboot")
        try Data().write(to: wineboot)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wineboot.path)

        let config = BackendConfig(wine: wine.path)
        let boot = launcher.winebootPlan(prefix: prefix, config: config)
        #expect(boot.executable == wineboot)
        #expect(boot.arguments == ["--init"])
        #expect(launcher.wineserverKillPlan(prefix: prefix, config: config)?.arguments == ["-k"])

        let profile = try smokeProfile()
        launcher.overlayTranslationDLLs(prefix: prefix, profile: profile, config: config)
        #expect(FileManager.default.fileExists(atPath: sys32.appendingPathComponent("d3d11.dll").path))
    }

    @Test
    func depotProgressAndLoginResultsCoverTheEdges() {
        #expect(DepotProgress.parse("") == nil)
        #expect(DepotProgress.parse("no numbers here") == nil)
        let pre = DepotProgress.parse("Update state (0x11) preallocating, progress: 200.00 (1 / 1)")
        #expect(pre?.phase == "Installing")
        #expect(pre?.fraction == 1)
        #expect(InstallSnapshot(titleId: "x", phase: "Installing", fraction: 0.4).percentLabel.contains("40%"))
        #expect(InstallSnapshot(titleId: "x").percentLabel == "Installing")

        let samples: [(String, DepotInstaller.LoginResult)] = [
            ("FAILED. Login Failure: Invalid Password", .badPassword),
            ("Account not found", .badUser),
            ("InvalidLoginAuthCode", .badGuard),
            ("twofactor code mismatch", .badGuard),
            ("Rate Limit Exceeded", .rateLimited),
            ("Logged in OK", .signedIn),
            ("Waiting for user info...OK", .signedIn),
            ("ERROR (Account Logon Denied)", .needsGuard("Steam emailed a one-time code. You only need one. Paste the newest, then press Play.")),
            ("Mobile authenticator two-factor code required", .needsGuard("Open the Steam phone app, copy the Guard code, paste it here, then Install.")),
            ("Steam sent a code to your email", .needsGuard("Steam sent a code to your email. Paste it in guard, then Install.")),
            ("FAILED. Login something else", .failed("Steam login failed. Check account name and password.")),
            ("hello", .unknown),
        ]
        let banned = ["wine", "gptk", "crossover", "proton", "bottle", "prefix"]
        for (line, expected) in samples {
            let result = DepotInstaller.loginResult(from: line)
            #expect(result == expected, "for \(line)")
            for word in banned {
                #expect(!result.message.lowercased().contains(word), "login message leaked '\(word)': \(result.message)")
            }
        }
        #expect(DepotInstaller.LoginResult.badPassword.isAuthFailure)
        #expect(!DepotInstaller.LoginResult.signedIn.isAuthFailure)
        #expect(DepotInstaller.LoginResult.needsGuard("x").phase == "Guard")
        #expect(DepotInstaller.LoginResult.signedIn.phase == "Ready")
        #expect(DepotInstaller.LoginResult.badUser.phase == "Failed")
    }

    @Test
    func errorFeedDedupesAndVDFSkipsComments() throws {
        let digest = ErrorFeed.digest(
            runtimeLog: "launch.failed\nlaunch.failed\n",
            titleLog: "ok\nFATAL boom\n",
            extra: ["custom.failed"]
        )
        #expect(digest.contains("custom.failed"))
        #expect(digest.contains("launch.failed"))
        #expect(digest.contains("FATAL boom"))
        #expect(ErrorFeed.isError("panic in shader"))

        let parsed = VDF.parse("""
        // ignore me
        "AppState"
        {
        \t"appid"\t\t"1"
        \t"nested"
        \t{
        \t\t"name"\t\t"Desk"
        \t}
        }
        """)
        #expect(parsed["AppState"]?.string(at: "appid") == "1")
        #expect(parsed["AppState"]?.string(at: "nested", "name") == "Desk")

        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let url = home.appendingPathComponent("file.vdf")
        try #""k" { "v" "1" }"#.write(to: url, atomically: true, encoding: .utf8)
        #expect(VDF.load(from: url)?["k"]?.string(at: "v") == "1")
    }

    @Test
    func credentialDecodeRejectsJunkAndLocatorFindsLooseExes() throws {
        #expect(SteamCredentialStore.decode("only-one-line") == nil)
        #expect(SteamCredentialStore.decode("\npassword") == nil)
        #expect(SteamCredentials(user: "a", password: "b", guardCode: " ab ").normalizedGuardCode == "AB")

        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let folder = home.appendingPathComponent("game")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let nested = folder.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data().write(to: nested.appendingPathComponent("other.exe"))
        let locator = InstallLocator(gamesRoot: home)
        #expect(locator.windowsExecutables(in: folder).map(\.lastPathComponent) == ["other.exe"])
        #expect(!locator.isMacNativeOnly(in: folder))
        let mac = home.appendingPathComponent("mac")
        try FileManager.default.createDirectory(at: mac.appendingPathComponent("Portal.app"), withIntermediateDirectories: true)
        #expect(locator.isMacNativeOnly(in: mac))
        #expect(locator.windowsExecutables(in: nested.appendingPathComponent("other.exe")).count == 1)
    }

    @Test
    func inspectInstallIsNilUntilASnapshotExists() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let (supervisor, _) = try makeSupervisor(home: home, wine: nil)
        #expect(await supervisor.inspectInstall() == nil)
        #expect(await supervisor.backendReady() == false)
        #expect(await supervisor.telemetryTail().isEmpty)
        #expect(await supervisor.gameLogTail(titleId: "apex-legends").isEmpty)
        #expect(SteamAccount(steamId: "1", personaName: "A").personaName == "A")
    }
}
