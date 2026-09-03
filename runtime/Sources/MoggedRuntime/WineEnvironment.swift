import Foundation

/// Isolated per-title execution tree. The player never names or configures this.
public struct WineEnvironment: Sendable {
    private let paths: RuntimePaths

    public init(paths: RuntimePaths = .standard()) {
        self.paths = paths
    }

    public func prefixURL(for titleId: String) -> URL {
        paths.environments.appendingPathComponent(titleId, isDirectory: true)
    }

    public func cacheURL(for titleId: String) -> URL {
        paths.caches.appendingPathComponent(titleId, isDirectory: true)
    }

    public func ensure(for titleId: String) throws -> (prefix: URL, cache: URL) {
        try paths.ensure()
        let prefix = prefixURL(for: titleId)
        let cache = cacheURL(for: titleId)
        try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        return (prefix, cache)
    }

    public func needsInit(prefix: URL) -> Bool {
        let marker = prefix.appendingPathComponent(".mogged-ready")
        let systemReg = prefix.appendingPathComponent("system.reg")
        return !FileManager.default.fileExists(atPath: marker.path)
            && !FileManager.default.fileExists(atPath: systemReg.path)
    }

    public func markReady(prefix: URL) throws {
        try "ready\n".write(
            to: prefix.appendingPathComponent(".mogged-ready"),
            atomically: true,
            encoding: .utf8
        )
    }
}
