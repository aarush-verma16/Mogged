import Foundation
#if canImport(AppKit)
import AppKit
#endif

public struct SteamAccount: Sendable, Equatable {
    public let steamId: String
    public let personaName: String?
}

public struct SteamLibraryApp: Sendable, Equatable {
    public let appId: Int
    public let name: String
    public let installDir: String?
    public let installPath: URL?
    public let lastPlayed: Int?
    public let coverURL: URL?
    public let executableNames: [String]
    public let hasWindowsExe: Bool
    public let macNativeOnly: Bool
    public let isInstalled: Bool
    public let isTool: Bool
}

public struct SteamSnapshot: Sendable, Equatable {
    public let present: Bool
    public let running: Bool
    public let root: URL?
    public let account: SteamAccount?
    public let apps: [SteamLibraryApp]

    public static let empty = SteamSnapshot(present: false, running: false, root: nil, account: nil, apps: [])
}

/// Reads the local Steam client on this Mac. Never a store; never Steam's UI.
public struct SteamCatalog: Sendable {
    private let rootOverride: URL?
    private let runningOverride: Bool?

    public init(root: URL? = nil, running: Bool? = nil) {
        self.rootOverride = root
        self.runningOverride = running
    }

    public func snapshot() -> SteamSnapshot {
        guard let root = steamRoot() else {
            return SteamSnapshot(present: false, running: isRunning(), root: nil, account: nil, apps: [])
        }

        let steamappsDirs = steamappsDirectories(root: root)
        var lastPlayed: [Int: Int] = [:]
        readPlaytimes(root: root, lastPlayed: &lastPlayed)

        var appsById: [Int: SteamLibraryApp] = [:]
        for steamapps in steamappsDirs {
            for app in installedApps(in: steamapps, root: root, lastPlayed: lastPlayed) {
                appsById[app.appId] = app
            }
        }

        return SteamSnapshot(
            present: true,
            running: isRunning(),
            root: root,
            account: account(in: root),
            apps: appsById.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )
    }

    public func steamappsDirectories() -> [URL] {
        guard let root = steamRoot() else { return [] }
        return steamappsDirectories(root: root)
    }

    public func steamRoot() -> URL? {
        let fm = FileManager.default
        if let rootOverride {
            return fm.fileExists(atPath: rootOverride.path) ? rootOverride : nil
        }
        if let env = ProcessInfo.processInfo.environment["MOGGED_STEAM_ROOT"], !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true)
            return fm.fileExists(atPath: url.path) ? url : nil
        }

        let home = URL(fileURLWithPath: NSHomeDirectory())
        let support = home.appendingPathComponent("Library/Application Support/Steam", isDirectory: true)
        if fm.fileExists(atPath: support.path) { return support }

        let app = URL(fileURLWithPath: "/Applications/Steam.app")
        if fm.fileExists(atPath: app.path) { return support }

        return nil
    }

    func isRunning() -> Bool {
        if let runningOverride { return runningOverride }
        #if canImport(AppKit)
        let ids = ["com.valvesoftware.steam"]
        for id in ids {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty {
                return true
            }
        }
        #endif
        return false
    }

    private func steamappsDirectories(root: URL) -> [URL] {
        let fm = FileManager.default
        var dirs: [URL] = []
        let primary = root.appendingPathComponent("steamapps", isDirectory: true)
        if fm.fileExists(atPath: primary.path) {
            dirs.append(primary)
        }

        let vdf = primary.appendingPathComponent("libraryfolders.vdf")
        if let table = VDF.load(from: vdf) {
            let folders = table["libraryfolders"]?.table ?? table
            for (_, value) in folders {
                guard let path = value.table?["path"]?.string ?? value.string else { continue }
                let cleaned = path.replacingOccurrences(of: "\\\\", with: "/")
                var steamapps = URL(fileURLWithPath: cleaned)
                if steamapps.lastPathComponent.lowercased() != "steamapps" {
                    steamapps.appendPathComponent("steamapps", isDirectory: true)
                }
                if fm.fileExists(atPath: steamapps.path), !dirs.contains(steamapps) {
                    dirs.append(steamapps)
                }
            }
        }
        return dirs
    }

    private func installedApps(in steamapps: URL, root: URL, lastPlayed: [Int: Int]) -> [SteamLibraryApp] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: steamapps, includingPropertiesForKeys: nil) else { return [] }
        return files.compactMap { url -> SteamLibraryApp? in
            guard url.pathExtension == "acf" else { return nil }
            return parseManifest(url, steamapps: steamapps, root: root, lastPlayed: lastPlayed)
        }
    }

    private func parseManifest(_ url: URL, steamapps: URL, root: URL, lastPlayed: [Int: Int]) -> SteamLibraryApp? {
        guard let table = VDF.load(from: url) else { return nil }
        let state = table["AppState"]?.table ?? table
        guard let appId = intValue(state["appid"]?.string) else { return nil }
        if Self.toolAppIds.contains(appId) { return nil }

        let name = state["name"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "App \(appId)"
        if Self.isToolName(name) { return nil }

        let installDir = state["installdir"]?.string
        var installPath: URL?
        if let installDir {
            let common = steamapps.appendingPathComponent("common/\(installDir)", isDirectory: true)
            if FileManager.default.fileExists(atPath: common.path) {
                installPath = common
            }
        }

        let played = intValue(state["LastPlayed"]?.string)
            ?? intValue(state["UserConfig"]?.table?["LastPlayed"]?.string)
            ?? lastPlayed[appId]

        let exes = installPath.map { InstallLocator().windowsExecutables(in: $0) } ?? []
        let exeNames = exes.map(\.lastPathComponent)
        let macOnly = installPath.map { InstallLocator().isMacNativeOnly(in: $0) } ?? false
        if macOnly { return nil }

        return SteamLibraryApp(
            appId: appId,
            name: name,
            installDir: installDir,
            installPath: installPath,
            lastPlayed: played,
            coverURL: coverURL(appId: appId, root: root),
            executableNames: exeNames,
            hasWindowsExe: !exes.isEmpty,
            macNativeOnly: macOnly,
            isInstalled: installPath != nil,
            isTool: false
        )
    }

    private func account(in root: URL) -> SteamAccount? {
        let url = root.appendingPathComponent("config/loginusers.vdf")
        guard let table = VDF.load(from: url) else { return nil }
        let users = table["users"]?.table ?? [:]
        var latest: (id: String, name: String?, recent: Bool)?
        for (id, value) in users {
            guard let user = value.table else { continue }
            let recent = user["MostRecent"]?.string == "1"
            let name = user["PersonaName"]?.string ?? user["AccountName"]?.string
            if recent { return SteamAccount(steamId: id, personaName: name) }
            if latest == nil { latest = (id, name, recent) }
        }
        if let latest {
            return SteamAccount(steamId: latest.id, personaName: latest.name)
        }
        return nil
    }

    private func readPlaytimes(root: URL, lastPlayed: inout [Int: Int]) {
        let userdata = root.appendingPathComponent("userdata", isDirectory: true)
        guard let users = try? FileManager.default.contentsOfDirectory(at: userdata, includingPropertiesForKeys: nil) else { return }
        for user in users {
            let local = user.appendingPathComponent("config/localconfig.vdf")
            guard let table = VDF.load(from: local) else { continue }
            let apps = table["UserLocalConfigStore"]?.table(at: "Software", "Valve", "Steam")?["apps"]?.table
                ?? table["UserLocalConfigStore"]?.table?["apps"]?.table
            guard let apps else { continue }
            for (key, value) in apps {
                guard let appId = Int(key), let played = intValue(value.table?["LastPlayed"]?.string) else { continue }
                lastPlayed[appId] = max(lastPlayed[appId] ?? 0, played)
            }
        }
    }

    private func coverURL(appId: Int, root: URL) -> URL? {
        let fm = FileManager.default
        let names = [
            "\(appId)_library_hero.jpg",
            "\(appId)_library_600x900.jpg",
            "\(appId)_header.jpg",
            "\(appId)_library_hero.png",
        ]
        let dirs = [
            root.appendingPathComponent("appcache/librarycache", isDirectory: true),
            root.appendingPathComponent("appcache/librarycache/\(appId)", isDirectory: true),
        ]
        for dir in dirs {
            for name in names {
                let url = dir.appendingPathComponent(name)
                if fm.fileExists(atPath: url.path) { return url }
            }
        }
        return nil
    }

    private func intValue(_ raw: String?) -> Int? {
        guard let raw, let value = Int(raw) else { return nil }
        return value
    }

    private static func isToolName(_ name: String) -> Bool {
        let lower = name.lowercased()
        let banned = ["proton", "steamworks common", "steam linux runtime", "steamworks sdk", "soundtrack"]
        return banned.contains { lower.contains($0) }
    }

    /// Steam tools / runtimes, not games.
    static let toolAppIds: Set<Int> = [
        228_980, 1_070_560, 1_391_110, 1_493_710, 1_620_710, 1_626_350, 1_826_330,
        1_887_720, 2_180_100, 2_234_130, 2_348_590, 2_805_730, 2_659_630, 1_113_280,
        1_580_130,
    ]
}
