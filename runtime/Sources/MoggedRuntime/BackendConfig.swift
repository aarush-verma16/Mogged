import Foundation

/// Hidden execution-engine paths. Written by Mogged on first run. Never shown in the UI.
public struct BackendConfig: Codable, Sendable, Equatable {
    public var wine: String
    public var dxvkPath: String
    public var vkd3dPath: String
    public var moltenVk: String

    public init(
        wine: String,
        dxvkPath: String = "bundled",
        vkd3dPath: String = "bundled",
        moltenVk: String = "bundled"
    ) {
        self.wine = wine
        self.dxvkPath = dxvkPath
        self.vkd3dPath = vkd3dPath
        self.moltenVk = moltenVk
    }

    enum CodingKeys: String, CodingKey {
        case wine
        case dxvkPath = "dxvk_path"
        case vkd3dPath = "vkd3d_path"
        case moltenVk = "molten_vk"
    }

    public var wineURL: URL { URL(fileURLWithPath: wine) }

    public var wineIsExecutable: Bool {
        FileManager.default.isExecutableFile(atPath: wine)
    }
}

public struct BackendConfigStore: Sendable {
    private let paths: RuntimePaths

    public init(paths: RuntimePaths = .standard()) {
        self.paths = paths
    }

    public func load() -> BackendConfig? {
        guard let data = try? Data(contentsOf: paths.backendURL) else { return nil }
        return try? JSONDecoder().decode(BackendConfig.self, from: data)
    }

    public func save(_ config: BackendConfig) throws {
        try paths.ensure()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: paths.backendURL, options: .atomic)
    }

    /// Load a still-valid config, or discover Wine and persist it.
    public func resolve(discover: () -> String?) throws -> BackendConfig {
        if let existing = load(), existing.wineIsExecutable {
            return existing
        }
        if let env = ProcessInfo.processInfo.environment["MOGGED_WINE"],
           FileManager.default.isExecutableFile(atPath: env)
        {
            let config = BackendConfig(wine: env)
            try save(config)
            return config
        }
        guard let wine = discover() else {
            throw MoggedError.runtimeUnavailable
        }
        let config = BackendConfig(wine: wine)
        try save(config)
        return config
    }
}
