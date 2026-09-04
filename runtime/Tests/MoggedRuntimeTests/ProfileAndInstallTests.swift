import Foundation
import Testing
@testable import MoggedRuntime

@Test
func repoProfilesDecode() throws {
    let profiles = try ProfileLoader.load()
    let ids = Set(profiles.map(\.id))
    #expect(ids.contains("apex-legends"))
    #expect(ids.contains("marvel-rivals"))
    #expect(ids.contains("spider-man-remastered"))

    let smoke = try #require(profiles.first { $0.role == .smoke })
    #expect(smoke.id == "apex-legends")
    #expect(smoke.steamAppId == 1_172_470)
    #expect(smoke.antiCheat == .eac)

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
