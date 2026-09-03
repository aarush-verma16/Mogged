import Foundation
import Testing
@testable import MoggedRuntime

@Test
func repoProfilesDecode() throws {
    let profiles = try ProfileLoader.load()
    let ids = Set(profiles.map(\.id))
    #expect(ids.contains("aperture-desk-job"))
    #expect(ids.contains("spider-man-remastered"))

    let smoke = try #require(profiles.first { $0.role == .smoke })
    #expect(smoke.steamAppId == 1_902_490)
    #expect(smoke.antiCheat == .none)

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
    let gameDir = root.appendingPathComponent("Aperture Desk Job")
    try FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
    let exe = gameDir.appendingPathComponent("Aperture Desk Job.exe")
    try Data().write(to: exe)
    defer { try? FileManager.default.removeItem(at: root) }

    let profile = try ProfileLoader.load().first { $0.id == "aperture-desk-job" }!
    let located = InstallLocator().locate(profile: profile, overridePath: gameDir.path)
    #expect(located?.executable?.lastPathComponent == "Aperture Desk Job.exe")
}

@Test
func locatesSteamInstallFromManifest() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("mogged-steam-\(UUID().uuidString)")
    let steamapps = root.appendingPathComponent("steamapps")
    let common = steamapps.appendingPathComponent("common/DeskJob")
    try FileManager.default.createDirectory(at: common, withIntermediateDirectories: true)
    try Data().write(to: common.appendingPathComponent("deskjob.exe"))
    let acf = """
    "AppState"
    {
    \t"appid"\t\t"1902490"
    \t"installdir"\t\t"DeskJob"
    }
    """
    try acf.write(to: steamapps.appendingPathComponent("appmanifest_1902490.acf"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let profile = try ProfileLoader.load().first { $0.id == "aperture-desk-job" }!
    let locator = InstallLocator()
    let install = locator.steamInstall(appId: profile.steamAppId, libraryRoot: steamapps)
    #expect(install?.lastPathComponent == "DeskJob")
}
