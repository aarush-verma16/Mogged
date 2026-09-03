import Foundation
import Testing
@testable import MoggedRuntime

@Test
func parsesSteamKeyValues() {
    let text = """
    "AppState"
    {
    \t"appid"\t\t"1902490"
    \t"name"\t\t"Aperture Desk Job"
    \t"installdir"\t\t"DeskJob"
    }
    """
    let table = VDF.parse(text)
    #expect(table["AppState"]?.string(at: "appid") == "1902490")
    #expect(table["AppState"]?.string(at: "name") == "Aperture Desk Job")
}

@Test
func libraryWithoutSteamShowsSmokeOnly() async throws {
    let missing = URL(fileURLWithPath: "/tmp/mogged-no-steam-\(UUID().uuidString)")
    let supervisor = RuntimeSupervisor(catalog: SteamCatalog(root: missing, running: false))
    let profiles = try ProfileLoader.load()
    let entries = await supervisor.libraryEntries(profiles: profiles)
    #expect(entries.map(\.id) == ["aperture-desk-job"])
    #expect(!entries.contains { $0.profile.role == .primaryDemo })
}

@Test
func steamCatalogReadsInstalledWindowsGameAndSkipsTools() throws {
    let root = try makeFakeSteam()
    defer { try? FileManager.default.removeItem(at: root) }

    let snap = SteamCatalog(root: root, running: true).snapshot()
    #expect(snap.present)
    #expect(snap.running)
    #expect(snap.account?.personaName == "Aarush")

    let ids = Set(snap.apps.map(\.appId))
    #expect(ids.contains(1_902_490))
    #expect(!ids.contains(228_980))
    #expect(!ids.contains(1_391_110))
    #expect(!ids.contains(400))

    let desk = try #require(snap.apps.first { $0.appId == 1_902_490 })
    #expect(desk.hasWindowsExe)
    #expect(desk.name == "Aperture Desk Job")
}

@Test
func libraryOverlaysSmokeProfileOnSteamApp() async throws {
    let root = try makeFakeSteam()
    defer { try? FileManager.default.removeItem(at: root) }

    let catalog = SteamCatalog(root: root, running: true)
    let supervisor = RuntimeSupervisor(
        locator: InstallLocator(catalog: catalog),
        catalog: catalog
    )
    let entries = await supervisor.libraryEntries(profiles: try ProfileLoader.load())
    let desk = try #require(entries.first { $0.profile.steamAppId == 1_902_490 })
    #expect(desk.id == "aperture-desk-job")
    #expect(desk.profile.role == .smoke)
    #expect(desk.canPlay)
    #expect(entries.first?.id == "aperture-desk-job")
    #expect(!entries.contains { $0.profile.role == .primaryDemo })
}

private func makeFakeSteam() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("mogged-steam-\(UUID().uuidString)")
    let steamapps = root.appendingPathComponent("steamapps")
    let desk = steamapps.appendingPathComponent("common/DeskJob")
    let tools = steamapps.appendingPathComponent("common/Steamworks Shared")
    let proton = steamapps.appendingPathComponent("common/Proton")
    let portal = steamapps.appendingPathComponent("common/Portal/Portal.app/Contents/MacOS")
    try FileManager.default.createDirectory(at: desk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: proton, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: portal, withIntermediateDirectories: true)
    try Data().write(to: desk.appendingPathComponent("Aperture Desk Job.exe"))
    try Data().write(to: portal.appendingPathComponent("Portal"))

    try FileManager.default.createDirectory(at: root.appendingPathComponent("config"), withIntermediateDirectories: true)
    try loginusers.write(to: root.appendingPathComponent("config/loginusers.vdf"), atomically: true, encoding: .utf8)

    try libraryfolders(root: root).write(
        to: steamapps.appendingPathComponent("libraryfolders.vdf"),
        atomically: true,
        encoding: .utf8
    )
    try acf(appId: 1_902_490, name: "Aperture Desk Job", installdir: "DeskJob")
        .write(to: steamapps.appendingPathComponent("appmanifest_1902490.acf"), atomically: true, encoding: .utf8)
    try acf(appId: 228_980, name: "Steamworks Common Redistributables", installdir: "Steamworks Shared")
        .write(to: steamapps.appendingPathComponent("appmanifest_228980.acf"), atomically: true, encoding: .utf8)
    try acf(appId: 1_391_110, name: "Proton Experimental", installdir: "Proton")
        .write(to: steamapps.appendingPathComponent("appmanifest_1391110.acf"), atomically: true, encoding: .utf8)
    try acf(appId: 400, name: "Portal", installdir: "Portal")
        .write(to: steamapps.appendingPathComponent("appmanifest_400.acf"), atomically: true, encoding: .utf8)
    return root
}

private var loginusers: String {
    """
    "users"
    {
    \t"76561198000000000"
    \t{
    \t\t"AccountName"\t\t"aarush"
    \t\t"PersonaName"\t\t"Aarush"
    \t\t"MostRecent"\t\t"1"
    \t}
    }
    """
}

private func libraryfolders(root: URL) -> String {
    """
    "libraryfolders"
    {
    \t"0"
    \t{
    \t\t"path"\t\t"\(root.path)"
    \t\t"apps"
    \t\t{
    \t\t\t"1902490"\t\t"1"
    \t\t}
    \t}
    }
    """
}

private func acf(appId: Int, name: String, installdir: String) -> String {
    """
    "AppState"
    {
    \t"appid"\t\t"\(appId)"
    \t"name"\t\t"\(name)"
    \t"installdir"\t\t"\(installdir)"
    }
    """
}
