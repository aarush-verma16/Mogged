import Foundation

/// Steam Input / SteamAPI need a signed-in Steam client inside the same environment.
/// SteamCMD only fetches files, so titles that call SteamAPI_Init need this too.
public struct SteamServices: Sendable {
    public static let installerURL = URL(
        string: "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
    )!

    private let paths: RuntimePaths

    public init(paths: RuntimePaths = .standard()) {
        self.paths = paths
    }

    public static func clientExe(prefix: URL) -> URL? {
        let candidates = [
            "drive_c/Program Files (x86)/Steam/steam.exe",
            "drive_c/Program Files/Steam/steam.exe",
        ]
        let fm = FileManager.default
        for rel in candidates {
            let url = prefix.appendingPathComponent(rel)
            if fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    /// True when a Steam client is already talking to this prefix.
    public static func isRunning(prefix: URL) -> Bool {
        let pidFile = prefix.appendingPathComponent("drive_c/users/steamuser/steam-running")
        guard let text = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return false }
        return kill(pid, 0) == 0
    }

    public func downloadInstaller() async throws -> URL {
        try paths.ensure()
        let dest = paths.caches.appendingPathComponent("SteamSetup.exe")
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        let (data, response) = try await URLSession.shared.data(from: Self.installerURL)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw MoggedError.installFailed("Steam services download HTTP \(http.statusCode)")
        }
        try data.write(to: dest, options: .atomic)
        return dest
    }

    /// Silent Steam install into the prefix. The user still signs in once, in Steam's own window.
    public func install(prefix: URL, config: BackendConfig, installer: URL) throws {
        let plan = LaunchPlan(
            executable: config.wineURL,
            arguments: [installer.path, "/S"],
            environment: ["WINEPREFIX": prefix.path, "WINEDEBUG": "-all"],
            workingDirectory: paths.caches,
            logURL: paths.logs.appendingPathComponent("steam-services.log")
        )
        let handle = try ProcessHandle.spawn(plan)
        _ = handle.waitUntilExit(timeout: 300)
    }

    /// Start Steam so SteamAPI_Init and Steam Input can attach.
    public func start(prefix: URL, config: BackendConfig, exe: URL) throws -> ProcessHandle {
        let plan = LaunchPlan(
            executable: config.wineURL,
            arguments: [exe.path, "-silent", "-no-browser"],
            environment: [
                "WINEPREFIX": prefix.path,
                "WINEDEBUG": "-all",
            ],
            workingDirectory: exe.deletingLastPathComponent(),
            logURL: paths.logs.appendingPathComponent("steam-services.log")
        )
        return try ProcessHandle.spawn(plan)
    }
}
