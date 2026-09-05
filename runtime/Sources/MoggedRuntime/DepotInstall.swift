import Foundation

/// Live Windows-depot fetch. Operator UI polls this; credentials never go to disk.
public struct InstallSnapshot: Sendable, Equatable {
    public var titleId: String
    public var phase: String
    public var fraction: Double?
    public var bytes: String?
    public var line: String
    public var log: String
    public var path: String
    public var running: Bool
    public var succeeded: Bool
    public var error: String?

    public init(
        titleId: String,
        phase: String = "Installing",
        fraction: Double? = nil,
        bytes: String? = nil,
        line: String = "",
        log: String = "",
        path: String = "",
        running: Bool = false,
        succeeded: Bool = false,
        error: String? = nil
    ) {
        self.titleId = titleId
        self.phase = phase
        self.fraction = fraction
        self.bytes = bytes
        self.line = line
        self.log = log
        self.path = path
        self.running = running
        self.succeeded = succeeded
        self.error = error
    }

    public var percentLabel: String {
        guard let fraction else { return phase }
        return "\(phase) \(Int((fraction * 100).rounded()))%"
    }
}

public enum DepotProgress {
    public static func parse(_ raw: String) -> (fraction: Double, bytes: String?, phase: String)? {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        let phase: String
        let lower = line.lowercased()
        if lower.contains("verif") { phase = "Updating" }
        else if lower.contains("download") { phase = "Installing" }
        else if lower.contains("preallocat") { phase = "Installing" }
        else { phase = "Installing" }

        guard let progressRange = line.range(of: "progress:", options: .caseInsensitive) else {
            return nil
        }
        let after = line[progressRange.upperBound...]
        let number = after.trimmingCharacters(in: .whitespaces)
        let percentToken = number.split(whereSeparator: { $0 == " " || $0 == "(" }).first
        guard let percentToken, let percent = Double(percentToken) else { return nil }

        var bytes: String?
        if let close = line.lastIndex(of: ")"),
           let open = line[..<close].lastIndex(of: "(")
        {
            bytes = String(line[line.index(after: open)..<close])
        }
        return (min(max(percent / 100, 0), 1), bytes, phase)
    }
}

/// SteamCMD Windows-platform fetch. Not a storefront — same job as `npm run fetch`.
public final class DepotInstaller: @unchecked Sendable {
    public static let steamcmdURL = URL(
        string: "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz"
    )!

    private let paths: RuntimePaths
    private let locator: InstallLocator
    private let lock = NSLock()
    private var process: Process?
    private var snapshot = InstallSnapshot(titleId: "")
    private var logLines: [String] = []

    public init(paths: RuntimePaths = .standard(), locator: InstallLocator = InstallLocator()) {
        self.paths = paths
        self.locator = locator
    }

    public func current() -> InstallSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return snapshot.running
    }

    public func cancel() {
        lock.lock()
        let proc = process
        lock.unlock()
        proc?.terminate()
        apply { snap in
            snap.running = false
            snap.phase = "Stopped"
            snap.line = "install cancelled"
        }
    }

    public func ensureSteamCMD() async throws {
        try paths.ensure()
        if FileManager.default.isExecutableFile(atPath: steamcmdBinary.path)
            || FileManager.default.isExecutableFile(atPath: steamcmdScript.path)
        {
            return
        }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mogged-steamcmd-\(UUID().uuidString).tar.gz")
        let (bytes, response) = try await URLSession.shared.data(from: Self.steamcmdURL)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw MoggedError.installFailed("steamcmd download HTTP \(http.statusCode)")
        }
        try bytes.write(to: tmp)
        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-xzf", tmp.path, "-C", paths.steamcmd.path]
        try tar.run()
        tar.waitUntilExit()
        try? FileManager.default.removeItem(at: tmp)
        if tar.terminationStatus != 0 {
            throw MoggedError.installFailed("steamcmd extract failed")
        }
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", paths.steamcmd.path]
        try? xattr.run()
        xattr.waitUntilExit()
    }

    public func start(
        profile: TitleProfile,
        username: String,
        password: String,
        guardCode: String?,
        onExit: @escaping @Sendable (InstallSnapshot) -> Void
    ) throws {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !pass.isEmpty else {
            throw MoggedError.installNeedsAccount
        }
        if isRunning {
            throw MoggedError.alreadyInstalling(profile.id)
        }
        if ProcessInfo.processInfo.thermalState == .critical {
            throw MoggedError.installFailed("This Mac is too hot. Let it cool, then Install.")
        }

        try paths.ensure()
        let dest = paths.games.appendingPathComponent(profile.id, isDirectory: true)
        let gamesRoot = paths.games.standardizedFileURL.path
        guard dest.standardizedFileURL.path.hasPrefix(gamesRoot) else {
            throw MoggedError.installFailed("Install path rejected.")
        }
        let need = profile.settings?.requiredFreeGB ?? 80
        if let free = Self.freeGigabytes(at: dest), free < need {
            throw MoggedError.installFailed("Need \(need) GB free. This volume has \(free) GB.")
        }
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        let script = steamcmdScript
        let binary = steamcmdBinary
        let executable: URL
        var arguments: [String]
        if FileManager.default.isExecutableFile(atPath: script.path) {
            executable = URL(fileURLWithPath: "/bin/bash")
            arguments = [script.path]
        } else if FileManager.default.isExecutableFile(atPath: binary.path) {
            executable = binary
            arguments = []
        } else {
            throw MoggedError.installFailed("Installer missing. Click Install again.")
        }

        arguments += [
            "+@sSteamCmdForcePlatformType", "windows",
            "+force_install_dir", dest.path,
            "+login", user, pass,
        ]
        if let guardCode {
            let code = guardCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if !code.isEmpty { arguments.append(code) }
        }
        arguments += ["+app_update", "\(profile.steamAppId)", "validate", "+quit"]

        let logURL = paths.logs.appendingPathComponent("install-\(profile.id).log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: Data())
        }

        let proc = Process()
        proc.executableURL = executable
        proc.arguments = arguments
        proc.currentDirectoryURL = paths.steamcmd
        var env = ProcessInfo.processInfo.environment
        env["DYLD_LIBRARY_PATH"] = paths.steamcmd.path
        env["DYLD_FRAMEWORK_PATH"] = paths.steamcmd.path
        proc.environment = env
        proc.qualityOfService = .utility

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        proc.standardInput = FileHandle.nullDevice

        apply { snap in
            snap = InstallSnapshot(
                titleId: profile.id,
                phase: "Installing",
                line: "starting",
                path: dest.path,
                running: true
            )
        }
        logLines = ["install \(profile.id) app \(profile.steamAppId) → \(dest.path)"]

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            self?.ingest(chunk, password: pass, logURL: logURL)
        }

        proc.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            guard let self else { return }
            let ok = finished.terminationStatus == 0
            let exe = self.locator.findExecutable(in: dest, names: profile.executables)
            let found = exe != nil
            self.apply { snap in
                snap.running = false
                if ok && found {
                    snap.succeeded = true
                    snap.phase = "Ready"
                    snap.fraction = 1
                    snap.line = exe?.path ?? dest.path
                    snap.error = nil
                } else {
                    snap.succeeded = false
                    snap.phase = "Failed"
                    snap.error = found ? "exit \(finished.terminationStatus)" : "files missing after install"
                }
            }
            onExit(self.current())
        }

        do {
            try proc.run()
        } catch {
            throw MoggedError.installFailed("could not start installer")
        }

        lock.lock()
        process = proc
        lock.unlock()
    }

    private var steamcmdScript: URL {
        paths.steamcmd.appendingPathComponent("steamcmd.sh")
    }

    private var steamcmdBinary: URL {
        paths.steamcmd.appendingPathComponent("steamcmd")
    }

    private func ingest(_ chunk: String, password: String, logURL: URL) {
        let lines = chunk.split { $0 == "\n" || $0 == "\r" }.map(String.init)
        for raw in lines {
            var line = raw
            if !password.isEmpty {
                line = line.replacingOccurrences(of: password, with: "••••")
            }
            if line.lowercased().contains("login") && line.contains(password) {
                continue
            }
            if let parsed = DepotProgress.parse(line) {
                apply { snap in
                    snap.fraction = parsed.fraction
                    snap.bytes = parsed.bytes
                    snap.phase = parsed.phase
                    snap.line = line
                    snap.running = true
                }
            } else {
                apply { snap in
                    snap.line = line
                }
            }
            lock.lock()
            logLines.append(line)
            if logLines.count > 400 { logLines.removeFirst(logLines.count - 400) }
            let joined = logLines.joined(separator: "\n")
            lock.unlock()
            apply { snap in
                snap.log = joined
            }
            if let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                if let data = (line + "\n").data(using: .utf8) {
                    handle.write(data)
                }
            }
        }
    }

    private func apply(_ body: (inout InstallSnapshot) -> Void) {
        lock.lock()
        body(&snapshot)
        lock.unlock()
    }

    static func freeGigabytes(at url: URL) -> Int? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? url.resourceValues(forKeys: keys),
              let bytes = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return Int(bytes / 1_000_000_000)
    }
}
