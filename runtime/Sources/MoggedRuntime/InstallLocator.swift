import Foundation

public struct LocatedInstall: Sendable, Equatable {
    public let path: URL
    public let executable: URL?
}

public struct InstallLocator: Sendable {
    private let catalog: SteamCatalog
    private let gamesRoot: URL

    public init(catalog: SteamCatalog = SteamCatalog(), gamesRoot: URL? = nil) {
        self.catalog = catalog
        self.gamesRoot = gamesRoot ?? RuntimePaths.standard().games
    }

    public func locate(profile: TitleProfile, overridePath: String?) -> LocatedInstall? {
        let fm = FileManager.default
        if let overridePath {
            let url = URL(fileURLWithPath: overridePath)
            if fm.fileExists(atPath: url.path) {
                let exe = findExecutable(in: url, names: profile.executables)
                    ?? windowsExecutables(in: url).first
                return LocatedInstall(path: url, executable: exe)
            }
        }

        let bundled = gamesRoot.appendingPathComponent(profile.id, isDirectory: true)
        if fm.fileExists(atPath: bundled.path) {
            let exe = findExecutable(in: bundled, names: profile.executables)
                ?? windowsExecutables(in: bundled).first
            return LocatedInstall(path: bundled, executable: exe)
        }

        for libraryRoot in steamLibraryRoots() {
            if let install = steamInstall(appId: profile.steamAppId, libraryRoot: libraryRoot) {
                let exe = findExecutable(in: install, names: profile.executables)
                    ?? windowsExecutables(in: install).first
                return LocatedInstall(path: install, executable: exe)
            }
        }

        return nil
    }

    public func findExecutable(in root: URL, names: [String]) -> URL? {
        let fm = FileManager.default
        let lowered = Set(names.map { $0.lowercased() })
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else { return nil }

        if !isDir.boolValue {
            return lowered.contains(root.lastPathComponent.lowercased()) ? root : nil
        }

        let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var depthGuard = 0
        while let item = enumerator?.nextObject() as? URL {
            depthGuard += 1
            if depthGuard > 8_000 { break }
            if lowered.contains(item.lastPathComponent.lowercased()) {
                return item
            }
        }
        return nil
    }

    /// Native Steam on this Mac plus any Windows Steam trees we already created under Application Support.
    public func steamLibraryRoots() -> [URL] {
        var roots = catalog.steamappsDirectories()
        let fm = FileManager.default
        let moggedPrefixes = AppSupport.root.appendingPathComponent("environments", isDirectory: true)
        if let envs = try? fm.contentsOfDirectory(at: moggedPrefixes, includingPropertiesForKeys: nil) {
            for env in envs {
                let windowsSteam = env
                    .appendingPathComponent("drive_c/Program Files (x86)/Steam/steamapps")
                if FileManager.default.fileExists(atPath: windowsSteam.path) {
                    roots.append(windowsSteam)
                }
            }
        }

        return roots
    }

    public func windowsExecutables(in root: URL, limit: Int = 8) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else { return [] }
        if !isDir.boolValue {
            return root.pathExtension.lowercased() == "exe" ? [root] : []
        }

        var rootLevel: [URL] = []
        var nested: [URL] = []
        let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var depthGuard = 0
        while let item = enumerator?.nextObject() as? URL {
            depthGuard += 1
            if depthGuard > 8_000 { break }
            guard item.pathExtension.lowercased() == "exe" else { continue }
            if item.deletingLastPathComponent() == root {
                rootLevel.append(item)
            } else {
                nested.append(item)
            }
            if rootLevel.count + nested.count >= 40 { break }
        }
        return Array((rootLevel + nested).prefix(limit))
    }

    public func isMacNativeOnly(in root: URL) -> Bool {
        windowsExecutables(in: root, limit: 1).isEmpty && hasMacApp(in: root)
    }

    private func hasMacApp(in root: URL) -> Bool {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return false }
        return items.contains { $0.pathExtension.lowercased() == "app" }
    }

    func steamInstall(appId: Int, libraryRoot: URL) -> URL? {
        let manifest = libraryRoot.appendingPathComponent("appmanifest_\(appId).acf")
        guard let contents = try? String(contentsOf: manifest, encoding: .utf8) else { return nil }
        let installdir = acfString(contents, key: "installdir")
            ?? "\(appId)"
        let common = libraryRoot.appendingPathComponent("common/\(installdir)", isDirectory: true)
        return FileManager.default.fileExists(atPath: common.path) ? common : nil
    }

    private func acfString(_ contents: String, key: String) -> String? {
        let needle = "\"\(key)\""
        guard let keyRange = contents.range(of: needle) else { return nil }
        let rest = contents[keyRange.upperBound...]
        guard let open = rest.firstIndex(of: "\"") else { return nil }
        let start = rest.index(after: open)
        guard let close = rest[start...].firstIndex(of: "\"") else { return nil }
        return String(rest[start..<close])
    }
}
