import Foundation

public enum ProfileLoader {
    public static func load(from directory: URL? = nil) throws -> [TitleProfile] {
        let dir = try directory ?? profilesDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix("_") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let decoder = JSONDecoder()
        return try files.map { url in
            let data = try Data(contentsOf: url)
            do {
                return try decoder.decode(TitleProfile.self, from: data)
            } catch {
                throw MoggedError.invalidProfile(url.lastPathComponent, error.localizedDescription)
            }
        }
    }

    public static func profilesDirectory() throws -> URL {
        let isApp = Bundle.main.bundleURL.pathExtension == "app"

        if isApp {
            if let bundled = Bundle.main.resourceURL?.appendingPathComponent("profiles", isDirectory: true),
               directoryHasProfiles(bundled)
            {
                return bundled
            }
            let staged = RuntimePaths.standard().profiles
            if directoryHasProfiles(staged) { return staged }
        }

        if let env = ProcessInfo.processInfo.environment["MOGGED_PROFILES"] {
            let url = URL(fileURLWithPath: env, isDirectory: true)
            if directoryHasProfiles(url) { return url }
        }

        // Tests / CLI only. The .app must not read the repo (it lives on Desktop and re-prompts).
        if !isApp {
            var walker = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            for _ in 0..<10 {
                let candidate = walker.appendingPathComponent("profiles", isDirectory: true)
                if directoryHasProfiles(candidate) { return candidate }
                let parent = walker.deletingLastPathComponent()
                if parent.path == walker.path { break }
                walker = parent
            }

            let fromSource = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("profiles", isDirectory: true)
            if directoryHasProfiles(fromSource) { return fromSource }
        }

        throw MoggedError.profilesNotFound
    }

    private static func directoryHasProfiles(_ url: URL) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return false
        }
        return files.contains { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix("_") }
    }
}
