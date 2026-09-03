import Foundation

/// On-disk layout for the hidden runtime. Override `root` in tests.
public struct RuntimePaths: Sendable, Equatable {
    public let root: URL
    public let logs: URL

    public init(root: URL, logs: URL? = nil) {
        self.root = root
        self.logs = logs ?? root.appendingPathComponent("logs", isDirectory: true)
    }

    public static func standard() -> RuntimePaths {
        if let override = ProcessInfo.processInfo.environment["MOGGED_HOME"], !override.isEmpty {
            let root = URL(fileURLWithPath: override, isDirectory: true)
            return RuntimePaths(root: root)
        }
        return RuntimePaths(root: AppSupport.defaultRoot, logs: AppSupport.defaultLogs)
    }

    public var libraryURL: URL { root.appendingPathComponent("library.json") }
    public var backendURL: URL { root.appendingPathComponent("backend.json") }
    public var environments: URL { root.appendingPathComponent("environments", isDirectory: true) }
    public var caches: URL { root.appendingPathComponent("caches", isDirectory: true) }

    public func ensure() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: logs, withIntermediateDirectories: true)
        try fm.createDirectory(at: environments, withIntermediateDirectories: true)
        try fm.createDirectory(at: caches, withIntermediateDirectories: true)
    }
}
