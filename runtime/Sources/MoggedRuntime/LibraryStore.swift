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
    public static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Mogged", isDirectory: true)
    }

    public static var libraryURL: URL {
        root.appendingPathComponent("library.json")
    }

    public static var logsDirectory: URL {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return logs.appendingPathComponent("Logs/Mogged", isDirectory: true)
    }

    public static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }
}

public struct LibraryStore: Sendable {
    public init() {}

    public func load() -> LibraryFile {
        let url = AppSupport.libraryURL
        guard let data = try? Data(contentsOf: url) else { return .empty }
        return (try? JSONDecoder().decode(LibraryFile.self, from: data)) ?? .empty
    }

    public func save(_ file: LibraryFile) throws {
        try AppSupport.ensureDirectories()
        let data = try JSONEncoder().encode(file)
        try data.write(to: AppSupport.libraryURL, options: .atomic)
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
