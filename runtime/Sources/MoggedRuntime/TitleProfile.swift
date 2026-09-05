import Foundation

public struct TitleProfile: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let steamAppId: Int
    public let displayName: String
    public let role: Role
    public let engine: String
    public let graphicsApi: GraphicsAPI
    public let antiCheat: AntiCheat
    public let macNative: Bool
    public let backend: Backend
    public let executables: [String]
    public let launch: Launch?
    public let settings: Settings?
    public let benchmark: Benchmark?
    public let controllerRequired: Bool?
    public let knownIssues: [String]?
    public let research: [String: String]?
    public let pinned: Bool?

    public enum Role: String, Codable, Sendable {
        case smoke
        case primaryDemo = "primary-demo"
        case generalize
        case catalog
    }

    public enum GraphicsAPI: String, Codable, Sendable {
        case d3d9, d3d11, d3d12, vulkan, opengl, mixed
    }

    public enum AntiCheat: String, Codable, Sendable {
        case none, vac, eac, battleye, other
    }

    public struct Backend: Codable, Sendable, Equatable {
        public let preferred: String
        public let fallback: String?
    }

    public struct Launch: Codable, Sendable, Equatable {
        public let args: [String]?
        public let env: [String: String]?
        /// Folder relative to the install root. Source 2 needs `game`, not `bin/win64`.
        public let workingDirectory: String?
    }

    public struct Settings: Codable, Sendable, Equatable {
        public let upscaler: String?
        public let rayTracing: String?
        public let dlss: String?
        public let notes: String?
        public let safeBoot: Bool?
        public let diskBudgetGB: Int?

        public var isSafeBoot: Bool { safeBoot == true }
        public var requiredFreeGB: Int { diskBudgetGB ?? 80 }
    }

    public struct Benchmark: Codable, Sendable, Equatable {
        public let route: String?
        public let durationSeconds: Int?
    }

    public var isPinned: Bool { pinned == true || role == .smoke }

    /// Profile overlay for a game discovered from the local Steam library.
    public static func fromSteam(_ app: SteamLibraryApp) -> TitleProfile {
        TitleProfile(
            id: "steam-\(app.appId)",
            steamAppId: app.appId,
            displayName: app.name,
            role: .catalog,
            engine: "unknown",
            graphicsApi: app.hasWindowsExe ? .d3d11 : .mixed,
            antiCheat: .none,
            macNative: app.macNativeOnly,
            backend: Backend(preferred: "dxvk-moltenvk", fallback: "moltenvk"),
            executables: app.executableNames.isEmpty ? ["game.exe"] : app.executableNames,
            launch: nil,
            settings: nil,
            benchmark: nil,
            controllerRequired: nil,
            knownIssues: nil,
            research: nil,
            pinned: nil
        )
    }
}
