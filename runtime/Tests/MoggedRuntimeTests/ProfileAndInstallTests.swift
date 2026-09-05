import Foundation
import Testing
@testable import MoggedRuntime

@Test
func repoProfilesDecode() throws {
    let profiles = try ProfileLoader.load()
    let ids = Set(profiles.map(\.id))
    #expect(ids.contains("aperture-desk-job"))
    #expect(ids.contains("apex-legends"))
    #expect(ids.contains("marvel-rivals"))
    #expect(ids.contains("spider-man-remastered"))

    let smoke = try #require(profiles.first { $0.role == .smoke })
    #expect(smoke.id == "aperture-desk-job")
    #expect(smoke.steamAppId == 1_902_490)
    #expect(smoke.antiCheat == .none)
    #expect(smoke.settings?.isSafeBoot == true)

    let demo = try #require(profiles.first { $0.role == .primaryDemo })
    #expect(demo.graphicsApi == .d3d12)
    #expect(demo.launch?.env?["SteamDeck"] == "0")
}

@Test
func userMessagesOmitToolkitNames() {
    let errors: [MoggedError] = [
        .profilesNotFound,
        .invalidProfile("x.json", "boom"),
        .gameNotFound("x"),
        .executableNotFound("game.exe"),
        .runtimeUnavailable,
        .alreadyRunning("x"),
        .notRunning("x"),
        .launchFailed,
        .alreadyInstalling("x"),
        .installFailed("x"),
        .installNeedsAccount,
        .steamSignInNeeded,
        .steamAccountNeeded,
        .steamServicesMissing,
    ]
    let banned = ["wine", "gptk", "crossover", "proton", "bottle", "prefix", "winetricks"]
    for error in errors {
        let text = error.userMessage.lowercased()
        for word in banned {
            #expect(!text.contains(word), "user message leaked '\(word)': \(error.userMessage)")
        }
    }
}

@Test
func locatesExeFromBundledGamesFolder() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("mogged-games-\(UUID().uuidString)")
    let games = root.appendingPathComponent("games")
    let dest = games.appendingPathComponent("apex-legends")
    try FileManager.default.createDirectory(at: dest.appendingPathComponent("bin"), withIntermediateDirectories: true)
    try Data().write(to: dest.appendingPathComponent("bin/r5apex.exe"))
    defer { try? FileManager.default.removeItem(at: root) }

    let profile = try ProfileLoader.load().first { $0.id == "apex-legends" }!
    let located = InstallLocator(gamesRoot: games).locate(profile: profile, overridePath: nil)
    #expect(located?.path.lastPathComponent == "apex-legends")
    #expect(located?.executable?.lastPathComponent == "r5apex.exe")
}

@Test
func locatesExeFromOverrideFolder() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("mogged-test-\(UUID().uuidString)")
    let gameDir = root.appendingPathComponent("Apex")
    try FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
    let exe = gameDir.appendingPathComponent("r5apex.exe")
    try Data().write(to: exe)
    defer { try? FileManager.default.removeItem(at: root) }

    let profile = try ProfileLoader.load().first { $0.id == "apex-legends" }!
    let located = InstallLocator().locate(profile: profile, overridePath: gameDir.path)
    #expect(located?.executable?.lastPathComponent == "r5apex.exe")
}

@Test
func locatesSteamInstallFromManifest() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("mogged-steam-\(UUID().uuidString)")
    let steamapps = root.appendingPathComponent("steamapps")
    let common = steamapps.appendingPathComponent("common/Apex")
    try FileManager.default.createDirectory(at: common, withIntermediateDirectories: true)
    try Data().write(to: common.appendingPathComponent("r5apex.exe"))
    let acf = """
    "AppState"
    {
    \t"appid"\t\t"1172470"
    \t"installdir"\t\t"Apex"
    }
    """
    try acf.write(to: steamapps.appendingPathComponent("appmanifest_1172470.acf"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let profile = try ProfileLoader.load().first { $0.id == "apex-legends" }!
    let locator = InstallLocator()
    let install = locator.steamInstall(appId: profile.steamAppId, libraryRoot: steamapps)
    #expect(install?.lastPathComponent == "Apex")
}

@Test
func parsesSteamCmdProgress() {
    let line = "Update state (0x61) downloading, progress: 12.45 (1.2 GB / 74 GB)"
    let parsed = DepotProgress.parse(line)
    #expect(parsed?.phase == "Installing")
    #expect(abs((parsed?.fraction ?? 0) - 0.1245) < 0.0001)
    #expect(parsed?.bytes == "1.2 GB / 74 GB")
    let verify = DepotProgress.parse("Update state (0x81) verifying installed files, progress: 55.00 (x / y)")
    #expect(verify?.phase == "Updating")
}

@Test
func errorFeedKeepsFailuresOnly() {
    let text = """
    launch.started
    Update state downloading, progress: 12.45
    install.failed: login denied
    launch.failed code=1
    ok
    """
    let lines = ErrorFeed.lines(from: text)
    #expect(lines.contains(where: { $0.contains("install.failed") }))
    #expect(lines.contains(where: { $0.contains("launch.failed") }))
    #expect(!lines.contains(where: { $0.contains("progress") }))
}

@Test
func errorFeedIgnoresTextBeforeSessionMark() {
    let old = "launch.failed code=1\nEncountered error.\n"
    let full = old + "launch.started\nlaunch.failed code=1\n"
    let added = ErrorFeed.added(after: old, in: full)
    #expect(!added.contains("Encountered error."))
    #expect(ErrorFeed.digest(runtimeLog: added, titleLog: "").contains("launch.failed"))
    #expect(ErrorFeed.added(after: "", in: full).isEmpty)
}

@Test
func guardHintPointsAtSteamAppOrEmail() {
    let email = DepotInstaller.guardHint(from: "This account is protected by Steam Guard. Check your email.")
    #expect(email.lowercased().contains("email"))
    let app = DepotInstaller.guardHint(from: "Mobile authenticator two-factor code required")
    #expect(app.lowercased().contains("steam"))
}

@Test
func loginResultFlagsBadPasswordAndUser() {
    #expect(DepotInstaller.loginResult(from: "FAILED. Login Failure: Invalid Password") == .badPassword)
    #expect(DepotInstaller.loginResult(from: "FAILED (InvalidPassword)") == .badPassword)
    #expect(DepotInstaller.loginResult(from: "Account not found") == .badUser)
    #expect(DepotInstaller.loginResult(from: "FAILED (AccountNotFound)") == .badUser)
    #expect(DepotInstaller.loginResult(from: "FAILED login with result code Rate Limit Exceeded") == .rateLimited)
    #expect(DepotInstaller.loginResult(from: "Logged in OK") == .signedIn)
    #expect(DepotInstaller.loginResult(from: "Connecting anonymously to Steam Public") == .unknown)
    #expect(!DepotInstaller.loginResult(from: "Steam sent a code to your email").isAuthFailure)
}
