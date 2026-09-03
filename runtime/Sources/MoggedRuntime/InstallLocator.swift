import Foundation

public struct LocatedInstall: Sendable, Equatable {
    public let path: URL
    public let executable: URL?
}

public struct InstallLocator: Sendable {
    public init() {}

    public func locate(profile: TitleProfile, overridePath: String?) -> LocatedInstall? {
        let fm = FileManager.default
        if let overridePath {
            let url = URL(fileURLWithPath: overridePath)
            if fm.fileExists(atPath: url.path) {
                return LocatedInstall(path: url, executable: findExecutable(in: url, names: profile.executables))
            }
        }

        for libraryRoot in steamLibraryRoots() {
            if let install = steamInstall(appId: profile.steamAppId, libraryRoot: libraryRoot) {
                return LocatedInstall(
                    path: install,
                    executable: findExecutable(in: install, names: profile.executables)
                )
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
        let fm = FileManager.default
        var roots: [URL] = []
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let macSteam = home.appendingPathComponent("Library/Application Support/Steam/steamapps")
        if fm.fileExists(atPath: macSteam.path) {
            roots.append(macSteam)
            roots.append(contentsOf: extraLibraries(from: macSteam.appendingPathComponent("libraryfolders.vdf")))
        }

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

    func steamInstall(appId: Int, libraryRoot: URL) -> URL? {
        let manifest = libraryRoot.appendingPathComponent("appmanifest_\(appId).acf")
        guard let contents = try? String(contentsOf: manifest, encoding: .utf8) else { return nil }
        let installdir = acfString(contents, key: "installdir")
            ?? "\(appId)"
        let common = libraryRoot.appendingPathComponent("common/\(installdir)", isDirectory: true)
        return FileManager.default.fileExists(atPath: common.path) ? common : nil
    }

    private func extraLibraries(from vdf: URL) -> [URL] {
        guard let text = try? String(contentsOf: vdf, encoding: .utf8) else { return [] }
        var urls: [URL] = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\"path\"") else { continue }
            let parts = trimmed.split(separator: "\"").map(String.init)
            guard parts.count >= 4 else { continue }
            let raw = parts[3].replacingOccurrences(of: "\\\\", with: "/")
            let steamapps = URL(fileURLWithPath: raw).appendingPathComponent("steamapps")
            if FileManager.default.fileExists(atPath: steamapps.path) {
                urls.append(steamapps)
            }
        }
        return urls
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
