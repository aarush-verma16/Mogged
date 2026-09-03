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
