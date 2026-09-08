import Foundation
import Testing
@testable import MoggedRuntime

@Suite("Steam", .serialized)
struct SteamServicesTests {
    @Test
    func findsSteamUnderProgramFilesAsWellAsX86() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let prefix = home.appendingPathComponent("prefix")
        #expect(SteamServices.clientExe(prefix: prefix) == nil)

        let steamDir = try plantSteamClient(prefix: prefix, programFilesX86: false)
        #expect(SteamServices.clientExe(prefix: prefix) == steamDir.appendingPathComponent("steam.exe"))
        #expect(!SteamServices.hasSentry(prefix: prefix))
        #expect(SteamServices.commandLineLoginExe(prefix: prefix) == nil)

        try Data().write(to: steamDir.appendingPathComponent("steamcmd.exe"))
        try Data().write(to: steamDir.appendingPathComponent("ssfn123"))
        #expect(SteamServices.hasSentry(prefix: prefix))
        #expect(SteamServices.commandLineLoginExe(prefix: prefix)?.lastPathComponent == "steamcmd.exe")
    }

    @Test
    func commandLineLoginOmitsAnEmptyGuardCode() {
        let cmd = URL(fileURLWithPath: "/tmp/steamcmd.exe")
        let without = SteamServices.cmdLoginArguments(
            cmd: cmd,
            credentials: SteamCredentials(user: "player", password: "secret")
        )
        #expect(without == [cmd.path, "+login", "player", "secret", "+quit"])

        let withCode = SteamServices.cmdLoginArguments(
            cmd: cmd,
            credentials: SteamCredentials(user: "player", password: "secret", guardCode: "ab12c")
        )
        #expect(withCode.contains("AB12C"))
        #expect(withCode.last == "+quit")
    }

    @Test
    func startArgumentsNeverCarryAGuardCode() {
        let exe = URL(fileURLWithPath: "/tmp/steam.exe")
        let args = SteamServices.startArguments(
            exe: exe,
            credentials: SteamCredentials(user: "player", password: "secret", guardCode: "XYZ12")
        )
        #expect(args.contains("-login"))
        #expect(args.contains("-silent"))
        #expect(args.contains("-no-browser"))
        #expect(args.contains("-no-cef-sandbox"))
        #expect(!args.contains("XYZ12"))
        #expect(args.suffix(2) == ["player", "secret"])
    }

    @Test
    func needsGuardCodeReadsInvalidAuthAndTwoFactor() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let prefix = home.appendingPathComponent("prefix")
        let steamDir = try plantSteamClient(prefix: prefix)
        let console = steamDir.appendingPathComponent("logs/console_log.txt")

        try """
        [2026-09-08 10:00:00] Client version: 1
        [2026-09-08 10:00:01] LogonFailure Invalid Login Auth Code
        """.write(to: console, atomically: true, encoding: .utf8)
        #expect(SteamServices.needsGuardCode(prefix: prefix))

        try """
        [2026-09-08 10:00:00] Client version: 1
        [2026-09-08 10:00:01] LogonFailure Account Login Denied Need Two Factor
        """.write(to: console, atomically: true, encoding: .utf8)
        #expect(SteamServices.needsGuardCode(prefix: prefix))
    }

    @Test
    func aNewerBootstrapThanConsoleIsStillStarting() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let prefix = home.appendingPathComponent("prefix")
        let steamDir = try plantSteamClient(prefix: prefix)
        try """
        [2026-09-08 10:00:00] Client version: 1
        [2026-09-08 10:00:01] LogonFailure Account Logon Denied
        """.write(to: steamDir.appendingPathComponent("logs/console_log.txt"), atomically: true, encoding: .utf8)
        try """
        [2026-09-08 10:05:00] Startup - updater built Sep 8 2026
        """.write(to: steamDir.appendingPathComponent("logs/bootstrap_log.txt"), atomically: true, encoding: .utf8)

        #expect(SteamServices.isStarting(prefix: prefix))
        #expect(!SteamServices.needsGuardCode(prefix: prefix))
    }

    @Test
    func bootstrapStillDownloadingIsAnUpdate() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let prefix = home.appendingPathComponent("prefix")
        let steamDir = try plantSteamClient(prefix: prefix)
        let now = SteamServices.logDateString(Date())
        try """
        [\(now)] Startup - updater built Sep 8 2026
        [\(now)] Extracting package...
        """.write(to: steamDir.appendingPathComponent("logs/bootstrap_log.txt"), atomically: true, encoding: .utf8)
        #expect(SteamServices.isUpdating(prefix: prefix))

        try """
        [\(now)] Startup - updater built Sep 8 2026
        [\(now)] Downloading update (1 of 2 KB)...
        [\(now)] Verification complete
        """.write(to: steamDir.appendingPathComponent("logs/bootstrap_log.txt"), atomically: true, encoding: .utf8)
        #expect(!SteamServices.isUpdating(prefix: prefix))

        try """
        [\(now)] Startup - updater built Sep 8 2026
        [\(now)] Package file steam.pkg missing
        [\(now)] Nothing to do
        """.write(to: steamDir.appendingPathComponent("logs/bootstrap_log.txt"), atomically: true, encoding: .utf8)
        #expect(!SteamServices.isUpdating(prefix: prefix))
    }

    @Test
    func commandLineBootstrapContinuesUntilLoginIsAttempted() {
        #expect(SteamServices.commandLineStillBootstrapping("Checking for available updates...\nUncompressing..."))
        #expect(SteamServices.commandLineStillBootstrapping("Downloading update...\nExtracting package..."))
        #expect(!SteamServices.commandLineStillBootstrapping("Downloading update...\nLogging in user 'player'"))
        #expect(!SteamServices.commandLineStillBootstrapping("Installing update...\nWaiting for user info...OK"))
        #expect(!SteamServices.commandLineStillBootstrapping("no updater noise"))
    }

    @Test
    func copiesSteamCMDFromCacheNextToTheClient() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        try paths.ensure()
        let steamDir = try plantSteamClient(prefix: home.appendingPathComponent("prefix"))
        try Data("cmd".utf8).write(to: paths.caches.appendingPathComponent("steamcmd.exe"))

        await SteamServices(paths: paths).ensureCommandLineLogin(steamDir: steamDir)
        #expect(FileManager.default.fileExists(atPath: steamDir.appendingPathComponent("steamcmd.exe").path))
    }

    @Test
    func copiesSteamCMDFromTheToolsFolderWhenPresent() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let steamDir = try plantSteamClient(prefix: home.appendingPathComponent("prefix"))
        let tools = steamDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("tools/steamcmd")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        try Data("cmd".utf8).write(to: tools.appendingPathComponent("steamcmd.exe"))
        try Data("dll".utf8).write(to: tools.appendingPathComponent("steamconsole.dll"))

        await SteamServices(paths: RuntimePaths(root: home)).ensureCommandLineLogin(steamDir: steamDir)
        #expect(FileManager.default.fileExists(atPath: steamDir.appendingPathComponent("steamcmd.exe").path))
        #expect(FileManager.default.fileExists(atPath: steamDir.appendingPathComponent("steamconsole.dll").path))
    }

    @Test
    func cachedInstallerIsReusedWithoutANetworkFetch() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = RuntimePaths(root: home)
        try paths.ensure()
        let cached = paths.caches.appendingPathComponent("SteamSetup.exe")
        try Data("setup".utf8).write(to: cached)
        let url = try await SteamServices(paths: paths).downloadInstaller()
        #expect(url == cached)
        #expect(try String(contentsOf: url, encoding: .utf8) == "setup")
    }

    @Test
    func addSteamServicesInstallsTheClientThroughFakeWine() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let wine = try writeFakeSteamClientWine(in: home)
        let (supervisor, paths) = try makeSupervisor(home: home, wine: wine.path)
        try BackendConfigStore(paths: paths).save(BackendConfig(wine: wine.path))
        try paths.ensure()
        try Data("setup".utf8).write(to: paths.caches.appendingPathComponent("SteamSetup.exe"))

        let profile = try deskJobProfile()
        #expect(!(await supervisor.steamServicesReady(profile: profile)))
        try await supervisor.addSteamServices(profile: profile)
        #expect(await supervisor.steamServicesReady(profile: profile))
        #expect(SteamServices.clientExe(prefix: WineEnvironment(paths: paths).prefixURL(for: profile.id)) != nil)
    }

    @Test
    func loginWithCommandLineWritesDeviceTrust() throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let wine = try writeFakeSteamClientWine(in: home)
        let paths = RuntimePaths(root: home)
        let prefix = home.appendingPathComponent("prefix")
        let steamDir = try plantSteamClient(prefix: prefix)
        let cmd = steamDir.appendingPathComponent("steamcmd.exe")
        try Data().write(to: cmd)

        let result = SteamServices(paths: paths).loginWithCommandLine(
            prefix: prefix,
            config: BackendConfig(wine: wine.path),
            cmd: cmd,
            credentials: SteamCredentials(user: "player", password: "secret", guardCode: "ABCDE")
        )
        #expect(result == .signedIn)
        #expect(SteamServices.hasSentry(prefix: prefix))
    }

    @Test
    func titlesThatDoNotNeedSteamSkipSignIn() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let (supervisor, _) = try makeSupervisor(home: home, wine: "/bin/echo")
        let profile = try smokeProfile()
        #expect(profile.settings?.needsSteamClient != true)
        #expect(try await supervisor.prepareSteamServices(profile: profile) == .ready)
        #expect(try await supervisor.pollSteamLogin(profile: profile) == .ready)
        #expect(await supervisor.steamSignedIn(profile: profile))
    }

    @Test
    func playWithoutSteamInstalledAsksToAddSteam() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let wine = try writeFakeWine(in: home, hold: true)
        let (supervisor, paths) = try makeSupervisor(home: home, wine: wine.path)
        try BackendConfigStore(paths: paths).save(BackendConfig(wine: wine.path))
        let profile = try deskJobProfile()
        try await supervisor.rememberInstall(titleId: profile.id, folder: try makeGameFolder(home: home, profile: profile))
        SteamCredentialStore.save(user: "player", password: "secret", guardCode: "", paths: paths)

        await #expect(throws: MoggedError.steamServicesMissing) {
            _ = try await supervisor.launch(profile: profile)
        }
    }

    @Test
    func playWithoutStoredAccountAsksForTheAccount() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let wine = try writeFakeWine(in: home, hold: true)
        let (supervisor, paths) = try makeSupervisor(home: home, wine: wine.path)
        try BackendConfigStore(paths: paths).save(BackendConfig(wine: wine.path))
        let profile = try deskJobProfile()
        try await supervisor.rememberInstall(titleId: profile.id, folder: try makeGameFolder(home: home, profile: profile))
        let prefix = WineEnvironment(paths: paths).prefixURL(for: profile.id)
        _ = try plantSteamClient(prefix: prefix)

        await #expect(throws: MoggedError.steamAccountNeeded) {
            _ = try await supervisor.launch(profile: profile)
        }
    }

    @Test
    func catalogGamesFromSteamDoNotNeedAPinnedProfile() {
        let app: SteamLibraryApp = sampleSteamApp(appId: 4242, name: "Loose Title", executableNames: ["loose.exe"])
        let profile = TitleProfile.fromSteam(app)
        #expect(profile.id == "steam-4242")
        #expect(profile.role == .catalog)
        #expect(profile.steamAppId == 4242)
        #expect(profile.executables == ["loose.exe"])
        #expect(profile.graphicsApi == .d3d11)
        #expect(profile.backend.preferred == "dxvk-moltenvk")
        #expect(!profile.isPinned)
        #expect(!profile.macNative)

        let mac = TitleProfile.fromSteam(sampleSteamApp(hasWindowsExe: false, macNativeOnly: true))
        #expect(mac.graphicsApi == .mixed)
        #expect(mac.macNative)
        let entry = LibraryEntry(profile: mac, install: LocatedInstall(path: URL(fileURLWithPath: "/tmp"), executable: URL(fileURLWithPath: "/tmp/game.exe")), coverURL: nil, lastPlayed: nil)
        #expect(!entry.canPlay)
    }

    @Test
    func inspectReportsSteamAndASession() async throws {
        let home = try scratchHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let wine = try writeFakeWine(in: home, hold: true)
        let (supervisor, paths) = try makeSupervisor(home: home, wine: wine.path)
        try BackendConfigStore(paths: paths).save(BackendConfig(wine: wine.path))
        let profile = try smokeProfile()
        let game = try makeGameFolder(home: home, profile: profile)
        try await supervisor.rememberInstall(titleId: profile.id, folder: game)

        let runtime = await supervisor.inspectRuntime()
        #expect(runtime.wineReady)
        #expect(runtime.wine == wine.path)
        #expect(RuntimeInspect.empty.steamAppCount == 0)
        #expect(SteamSnapshot.empty.apps.isEmpty)

        let state: LaunchState = try await supervisor.launch(profile: profile)
        #expect(state.titleId == profile.id)
        let session: SessionInspect = await supervisor.inspectSession(
            profile: profile,
            install: LocatedInstall(path: game, executable: game.appendingPathComponent(profile.executables[0]))
        )
        #expect(session.titleId == profile.id)
        #expect(session.running)
        #expect(session.pid != nil)
        #expect(session.stack == "dxvk-moltenvk")
        #expect(session.optimization != nil)
        try await supervisor.stop(titleId: profile.id)
    }
}
