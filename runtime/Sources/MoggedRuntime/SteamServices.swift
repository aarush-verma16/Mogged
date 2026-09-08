import Foundation

/// Steam Input / SteamAPI need a signed-in Steam client inside the same environment.
/// SteamCMD only fetches files, so titles that call SteamAPI_Init need this too.
/// Where a title's Steam session stands, in the order Play cares about.
public enum SteamServicesState: Sendable, Equatable, CaseIterable {
    case ready
    case signingIn
    /// The client is applying its own update. Killing it here just loops the window.
    case updating
    /// Steam denied the command-line login and wants a fresh code for this device.
    case needsGuardCode
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
        isClientAlive(prefix: prefix)
    }

    /// `ProcessHandle` dies when Steam re-execs itself to apply an update, but
    /// `steam.exe` is still there. Match this prefix's own binary so another title
    /// or the real Steam client is never counted.
    public static func isClientAlive(prefix: URL) -> Bool {
        guard let exe = clientExe(prefix: prefix) else { return false }
        return !matchingPids(path: exe.path).isEmpty
    }

    /// Steam's updater window is its own process. Play used to treat a stale
    /// "Account Logon Denied" from the last session as a reason to kill and
    /// relaunch every couple of seconds, which closed that window as soon as it
    /// appeared. An in-progress bootstrap download is not a failed login.
    public static func isUpdating(prefix: URL) -> Bool {
        guard let session = lastLogSession(prefix: prefix, file: "bootstrap_log.txt", marker: "Startup -")
        else { return false }
        guard updateInProgress(session) else { return false }
        if isClientAlive(prefix: prefix) { return true }
        // Steam exits and relaunches itself mid-update. A short dead gap is still
        // an update, not a cue to spawn another `-login`.
        return isRecent(session, within: 8)
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
    ///
    /// `steam.exe -login` does **not** accept a Guard code (that is SteamCMD only).
    /// Passing one is ignored, Steam emails a *new* code, and the one the player
    /// just pasted is already stale. Device trust is created by `steamcmd.exe`
    /// in this same folder (`loginWithCommandLine`), then `steam.exe` starts
    /// without a code.
    public static func startArguments(exe: URL, credentials: SteamCredentials) -> [String] {
        [
            exe.path,
            "-silent",
            "-no-browser",
            "-no-cef-sandbox",
            "-login", credentials.user, credentials.password,
        ]
    }

    public static func cmdLoginArguments(cmd: URL, credentials: SteamCredentials) -> [String] {
        var args = [cmd.path, "+login", credentials.user, credentials.password]
        if !credentials.normalizedGuardCode.isEmpty {
            args.append(credentials.normalizedGuardCode)
        }
        args.append("+quit")
        return args
    }

    public static func commandLineLoginExe(prefix: URL) -> URL? {
        guard let dir = clientExe(prefix: prefix)?.deletingLastPathComponent() else { return nil }
        let url = dir.appendingPathComponent("steamcmd.exe")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public static func hasSentry(prefix: URL) -> Bool {
        guard let dir = clientExe(prefix: prefix)?.deletingLastPathComponent() else { return false }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.contains { $0.lowercased().hasPrefix("ssfn") }
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

    /// Kills a stuck client even across app restarts, when `RuntimeSupervisor` has no
    /// in-memory handle for it. `pkill -f` matches as a POSIX ERE — "Program Files
    /// (x86)" must be escaped or it matches nothing. CEF's window process often
    /// does not include the Unix `steam.exe` path, so killing only that binary
    /// leaves a blank window up.
    public static func killOrphanedClient(prefix: URL) {
        guard let exe = clientExe(prefix: prefix) else { return }
        pkill(matching: exe.path)
        pkill(matching: exe.deletingLastPathComponent().path)
        // Wine shows these as Windows paths; they are not the native Mac Steam app.
        pkill(matching: "steamwebhelper.exe")
        pkill(matching: "steamservice.exe")
    }

    static func pkill(matching path: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        proc.arguments = ["-f", regexEscaped(path)]
        try? proc.run()
        proc.waitUntilExit()
    }

    /// Play with a code must not see the previous attempt's "Account Logon Denied".
    /// That leftover line is what made a just-entered code look like it had already
    /// failed before Steam ever received it.
    public static func beginLoginAttempt(prefix: URL) {
        guard let dir = clientExe(prefix: prefix)?.deletingLastPathComponent() else { return }
        let logs = dir.appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let console = logs.appendingPathComponent("console_log.txt")
        let previous = logs.appendingPathComponent("console_log.prev.txt")
        if FileManager.default.fileExists(atPath: console.path) {
            try? FileManager.default.removeItem(at: previous)
            try? FileManager.default.moveItem(at: console, to: previous)
        }
    }

    private static func regexEscaped(_ path: String) -> String {
        let special = Set<Character>(".^$*+?()[]{}|\\")
        var out = ""
        for ch in path {
            if special.contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    /// SteamCMD and the graphical Steam client hold separate device authorizations
    /// even inside the same prefix: a SteamCMD login already trusted on this Mac does
    /// not carry over, so the client's first `-login` on a fresh prefix comes back
    /// "Account Logon Denied" and wants its own one-time code. Steam's window paints
    /// black here, so that has to surface in Mogged instead — this reads the client's
    /// own `console_log.txt` to notice.
    ///
    /// A previous session's denial must not apply while Steam is still updating or
    /// has started a newer boot than that log: those are the cases where Play used
    /// to kill the updater window in a loop.
    public static func needsGuardCode(prefix: URL) -> Bool {
        if isUpdating(prefix: prefix) { return false }
        if isStarting(prefix: prefix) { return false }
        guard let dir = clientExe(prefix: prefix)?.deletingLastPathComponent(),
              let log = try? String(contentsOf: dir.appendingPathComponent("logs/console_log.txt"), encoding: .utf8)
        else { return false }
        // Logs persist across restarts; only this run's section counts.
        let session = log.components(separatedBy: "Client version:").last ?? log
        return session.contains("LogonFailure Account Logon Denied")
            || session.contains("LogonFailure Invalid Login Auth Code")
            || session.contains("LogonFailure Account Login Denied Need Two Factor")
    }

    /// Last updater boot is newer than the last console session, so login has
    /// not been attempted yet this run.
    public static func isStarting(prefix: URL) -> Bool {
        let boot = lastLogSession(prefix: prefix, file: "bootstrap_log.txt", marker: "Startup -")
        let console = lastLogSession(prefix: prefix, file: "console_log.txt", marker: "Client version:")
        guard let bootTime = firstTimestamp(in: boot ?? ""), !bootTime.isEmpty else { return false }
        guard let consoleTime = firstTimestamp(in: console ?? "") else { return true }
        return bootTime > consoleTime
    }

    /// Start Steam so SteamAPI_Init and Steam Input can attach.
    public func start(
        prefix: URL,
        config: BackendConfig,
        exe: URL,
        credentials: SteamCredentials
    ) throws -> ProcessHandle {
        var environment = [
            "WINEPREFIX": prefix.path,
            "WINEDEBUG": "-all",
        ]
        InputLayer.apply(into: &environment)
        let plan = LaunchPlan(
            executable: config.wineURL,
            arguments: Self.startArguments(exe: exe, credentials: credentials),
            environment: environment,
            workingDirectory: exe.deletingLastPathComponent(),
            logURL: paths.logs.appendingPathComponent("steam-services.log")
        )
        return try ProcessHandle.spawn(plan)
    }

    /// Drop Windows SteamCMD next to `steam.exe` so a Guard code can authorize
    /// this environment. `steam.exe` cannot take that code itself.
    public func ensureCommandLineLogin(steamDir: URL) async {
        let dest = steamDir.appendingPathComponent("steamcmd.exe")
        let driveC = steamDir.deletingLastPathComponent().deletingLastPathComponent()
        let toolsDir = driveC.appendingPathComponent("tools/steamcmd")
        let fm = FileManager.default
        if !fm.fileExists(atPath: dest.path) {
            let tools = toolsDir.appendingPathComponent("steamcmd.exe")
            let cached = paths.caches.appendingPathComponent("steamcmd.exe")
            if fm.fileExists(atPath: tools.path) {
                try? fm.copyItem(at: tools, to: dest)
            } else if fm.fileExists(atPath: cached.path) {
                try? fm.copyItem(at: cached, to: dest)
            }
        }
        for name in ["steamconsole.dll", "steamconsole64.dll"] {
            let target = steamDir.appendingPathComponent(name)
            let source = toolsDir.appendingPathComponent(name)
            if !fm.fileExists(atPath: target.path), fm.fileExists(atPath: source.path) {
                try? fm.copyItem(at: source, to: target)
            }
        }
    }

    /// SteamCMD accepts `+login user password code`. One successful run writes
    /// `ssfn*` in this folder; `steam.exe` then trusts the device with no more codes.
    /// A first run often exits after self-update, before login — retry so that is
    /// not mistaken for "need another code".
    public func loginWithCommandLine(
        prefix: URL,
        config: BackendConfig,
        cmd: URL,
        credentials: SteamCredentials
    ) -> DepotInstaller.LoginResult {
        let logURL = paths.logs.appendingPathComponent("steam-cmd-login.log")
        var last: DepotInstaller.LoginResult = .unknown
        for _ in 0..<3 {
            try? Data().write(to: logURL)
            let plan = LaunchPlan(
                executable: config.wineURL,
                arguments: Self.cmdLoginArguments(cmd: cmd, credentials: credentials),
                environment: [
                    "WINEPREFIX": prefix.path,
                    "WINEDEBUG": "-all",
                ],
                workingDirectory: cmd.deletingLastPathComponent(),
                logURL: logURL
            )
            guard let handle = try? ProcessHandle.spawn(plan) else { return .unknown }
            _ = handle.waitUntilExit(timeout: 240)
            if Self.hasSentry(prefix: prefix) { return .signedIn }
            let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            last = DepotInstaller.loginResult(from: log)
            switch last {
            case .signedIn, .needsGuard, .badGuard, .badUser, .badPassword, .rateLimited:
                return last
            case .failed, .unknown:
                if Self.commandLineStillBootstrapping(log) { continue }
                return last
            }
        }
        return last
    }

    static func commandLineStillBootstrapping(_ log: String) -> Bool {
        let line = log.lowercased()
        let updating = line.contains("downloading update")
            || line.contains("installing update")
            || line.contains("extracting package")
            || line.contains("checking for available updates")
            || line.contains("uncompressing")
        let attemptedLogin = line.contains("logging in")
            || line.contains("logon")
            || line.contains("logged in")
            || line.contains("account logon")
            || line.contains("waiting for user info")
        return updating && !attemptedLogin
    }

    static func matchingPids(path: String) -> [Int32] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-f", regexEscaped(path)]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return []
        }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return text.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    static func lastLogSession(prefix: URL, file: String, marker: String) -> String? {
        guard let dir = clientExe(prefix: prefix)?.deletingLastPathComponent(),
              let log = try? String(contentsOf: dir.appendingPathComponent("logs/\(file)"), encoding: .utf8),
              !log.isEmpty
        else { return nil }
        guard let range = log.range(of: marker, options: .backwards) else { return log }
        let before = log[..<range.lowerBound]
        let lineStart = before.lastIndex(of: "\n").map { log.index(after: $0) } ?? log.startIndex
        return String(log[lineStart...])
    }

    static func updateInProgress(_ session: String) -> Bool {
        let downloading = session.contains("Downloading update")
            || session.contains("Extracting package")
            || session.contains("Installing update")
            || (session.contains("Package file") && session.contains("missing"))
        guard downloading else { return false }
        return !session.contains("Verification complete")
            && !session.contains("Update complete")
            && !session.contains("Nothing to do")
    }

    static func isRecent(_ session: String, within seconds: TimeInterval) -> Bool {
        guard let stamp = lastTimestamp(in: session),
              let date = logDate.date(from: stamp)
        else { return false }
        return Date().timeIntervalSince(date) < seconds
    }

    static func firstTimestamp(in text: String) -> String? {
        timestamps(in: text).first
    }

    static func lastTimestamp(in text: String) -> String? {
        timestamps(in: text).last
    }

    static func logDateString(_ date: Date) -> String {
        logDate.string(from: date)
    }

    private static func timestamps(in text: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]"#)
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let regex else { return [] }
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return ns.substring(with: match.range(at: 1))
        }
    }

    private static let logDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter
    }()
}
