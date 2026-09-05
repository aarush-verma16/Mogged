import Foundation

/// Steam Input / SteamAPI need a signed-in Steam client inside the same environment.
/// SteamCMD only fetches files, so titles that call SteamAPI_Init need this too.
/// Where a title's Steam session stands, in the order Play cares about.
public enum SteamServicesState: Sendable, Equatable {
    case ready
    case signingIn
    case needsAccount
    case notInstalled
}

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

    /// Steam's own window cannot be used here. Chromium composites in a second
    /// process and hands frames over a shared swapchain that Wine has no path for, so
    /// the window paints black. Steam's `-cef-*` flags do not reach Chromium (verified:
    /// steamwebhelper still starts `--type=gpu-process`), so there is nothing to pass.
    /// Mogged already has the account, so it signs in on the command line and keeps
    /// Steam hidden — the player never sees it.
    public static func startArguments(exe: URL, credentials: SteamCredentials) -> [String] {
        var args = [
            exe.path,
            "-silent",
            "-no-browser",
            "-no-cef-sandbox",
            "-login", credentials.user, credentials.password,
        ]
        if !credentials.guardCode.isEmpty {
            args.append(credentials.guardCode)
        }
        return args
    }

    /// `SteamAPI_Init` reads this key. Non-zero means a real signed-in session, which
    /// is the only state where Steam Input works.
    public static func activeUser(prefix: URL) -> Int {
        guard let reg = try? String(
            contentsOf: prefix.appendingPathComponent("user.reg"),
            encoding: .utf8
        ) else { return 0 }
        guard let section = reg.range(of: #"[Software\\Valve\\Steam\\ActiveProcess]"#) else { return 0 }
        let rest = reg[section.upperBound...]
        let end = rest.range(of: "\n[")?.lowerBound ?? rest.endIndex
        for line in rest[..<end].split(separator: "\n") {
            guard line.hasPrefix(#""ActiveUser""#),
                  let hex = line.components(separatedBy: "dword:").last
            else { continue }
            return Int(hex.trimmingCharacters(in: .whitespaces), radix: 16) ?? 0
        }
        return 0
    }

    public static func isSignedIn(prefix: URL) -> Bool {
        activeUser(prefix: prefix) != 0
    }

    /// Start Steam so SteamAPI_Init and Steam Input can attach.
    public func start(
        prefix: URL,
        config: BackendConfig,
        exe: URL,
        credentials: SteamCredentials
    ) throws -> ProcessHandle {
        let plan = LaunchPlan(
            executable: config.wineURL,
            arguments: Self.startArguments(exe: exe, credentials: credentials),
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
