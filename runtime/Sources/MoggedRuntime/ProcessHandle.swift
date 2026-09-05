import Darwin
import Foundation

/// Spawned game process. Lives only inside the supervisor.
public final class ProcessHandle: @unchecked Sendable {
    private let process: Process
    public let pid: Int32

    public var isRunning: Bool { process.isRunning }

    private init(process: Process, pid: Int32) {
        self.process = process
        self.pid = pid
    }

    public static func spawn(
        _ plan: LaunchPlan,
        onExit: (@Sendable (Int32) -> Void)? = nil
    ) throws -> ProcessHandle {
        try FileManager.default.createDirectory(
            at: plan.logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: plan.logURL.path) {
            FileManager.default.createFile(atPath: plan.logURL.path, contents: Data())
        }
        trimLog(at: plan.logURL)
        let log = try FileHandle(forWritingTo: plan.logURL)
        try log.seekToEnd()

        let process = Process()
        process.executableURL = plan.executable
        process.arguments = plan.arguments
        process.currentDirectoryURL = plan.workingDirectory
        process.qualityOfService = .userInteractive

        var env = ProcessInfo.processInfo.environment
        for (key, value) in plan.environment {
            env[key] = value
        }
        process.environment = env
        process.standardOutput = log
        process.standardError = log
        process.standardInput = FileHandle.nullDevice
        process.terminationHandler = { proc in
            try? log.close()
            onExit?(proc.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            try? log.close()
            throw MoggedError.launchFailed
        }

        return ProcessHandle(process: process, pid: process.processIdentifier)
    }

    /// A chatty driver can write hundreds of MB per boot. Keep the tail, drop the rest.
    static let logByteLimit = 8 * 1024 * 1024

    static func trimLog(at url: URL) {
        let fm = FileManager.default
        guard let size = (try? fm.attributesOfItem(atPath: url.path)[.size]) as? Int,
              size > logByteLimit
        else { return }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let keep = logByteLimit / 2
        try? handle.seek(toOffset: UInt64(size - keep))
        let tail = (try? handle.readToEnd()) ?? Data()
        try? tail.write(to: url, options: .atomic)
    }

    public func terminate() {
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [process] in
            if process.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }

    public func waitUntilExit(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        return !process.isRunning
    }
}
