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

    public enum Role: String, Codable, Sendable {
        case smoke
        case primaryDemo = "primary-demo"
        case generalize
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
    }

    public struct Settings: Codable, Sendable, Equatable {
        public let upscaler: String?
        public let rayTracing: String?
        public let dlss: String?
        public let notes: String?
    }

    public struct Benchmark: Codable, Sendable, Equatable {
        public let route: String?
        public let durationSeconds: Int?
    }
}
