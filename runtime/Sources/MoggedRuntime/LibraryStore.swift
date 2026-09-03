import Foundation

/// Where a title is installed on disk. The UI never shows how we found it.
public struct InstallRecord: Codable, Sendable, Equatable {
    public let titleId: String
    public let path: String
}

public struct LibraryFile: Codable, Sendable, Equatable {
    public var overrides: [InstallRecord]

    public static let empty = LibraryFile(overrides: [])
}

public enum AppSupport {
    public static var defaultRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Mogged", isDirectory: true)
    }

    public static var defaultLogs: URL {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return logs.appendingPathComponent("Logs/Mogged", isDirectory: true)
    }

    public static var root: URL { RuntimePaths.standard().root }
    public static var libraryURL: URL { RuntimePaths.standard().libraryURL }
    public static var logsDirectory: URL { RuntimePaths.standard().logs }

    public static func ensureDirectories() throws {
        try RuntimePaths.standard().ensure()
    }
}

public struct LibraryStore: Sendable {
    private let paths: RuntimePaths

    public init(paths: RuntimePaths = .standard()) {
        self.paths = paths
    }

    public func load() -> LibraryFile {
        guard let data = try? Data(contentsOf: paths.libraryURL) else { return .empty }
        return (try? JSONDecoder().decode(LibraryFile.self, from: data)) ?? .empty
    }

    public func save(_ file: LibraryFile) throws {
        try paths.ensure()
        let data = try JSONEncoder().encode(file)
        try data.write(to: paths.libraryURL, options: .atomic)
    }

    public func setOverride(titleId: String, path: String) throws {
        var file = load()
        file.overrides.removeAll { $0.titleId == titleId }
        file.overrides.append(InstallRecord(titleId: titleId, path: path))
        try save(file)
    }

    public func overridePath(for titleId: String) -> String? {
        load().overrides.first { $0.titleId == titleId }?.path
    }
}
