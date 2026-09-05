import Foundation

public struct LaunchPlan: Sendable, Equatable {
    public let executable: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let workingDirectory: URL
    public let logURL: URL
}

/// Builds the Wine command from a title profile and backend config.
public struct BackendLauncher: Sendable {
    private let paths: RuntimePaths

    public init(paths: RuntimePaths = .standard()) {
        self.paths = paths
    }

    public func graphicsStack(for profile: TitleProfile) -> String {
        switch profile.backend.preferred {
        case "dxvk-moltenvk", "moltenvk", "vkd3d-moltenvk":
            return profile.backend.preferred
        default:
            switch profile.graphicsApi {
            case .d3d12:
                return "vkd3d-moltenvk"
            case .vulkan:
                return "moltenvk"
            case .d3d9, .d3d11, .opengl, .mixed:
                return "dxvk-moltenvk"
            }
        }
    }

    public func plan(
        profile: TitleProfile,
        exe: URL,
        prefix: URL,
        cache: URL,
        config: BackendConfig,
        installRoot: URL? = nil,
        thermal: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    ) -> LaunchPlan {
        let stack = graphicsStack(for: profile)
        var env: [String: String] = [
            "WINEPREFIX": prefix.path,
            "WINEDEBUG": "-all",
            "DXVK_STATE_CACHE": "1",
            "DXVK_STATE_CACHE_PATH": cache.path,
            "DXVK_LOG_PATH": paths.logs.path,
            "DXVK_LOG_LEVEL": "warn",
            "SteamAppId": "\(profile.steamAppId)",
            "SteamGameId": "\(profile.steamAppId)",
        ]

        let policy = OptimizationLayer().policy(for: profile, thermal: thermal)
        OptimizationLayer().apply(policy, into: &env)

        if let overrides = dllOverrides(for: stack) {
            env["WINEDLLOVERRIDES"] = overrides
        }

        writeDxvkConf()
        env["DXVK_CONFIG_FILE"] = paths.caches.appendingPathComponent("dxvk.conf").path
        env["ENABLE_VKBASALT"] = "0"
        env["DISABLE_VK_LAYER_VALVE_steam_overlay_1"] = "1"

        if let molten = Self.moltenVkPaths(wine: config.wineURL, configured: config.moltenVk) {
            env["VK_ICD_FILENAMES"] = molten.icd
            env["VK_DRIVER_FILES"] = molten.icd
            env["DYLD_LIBRARY_PATH"] = joinedPath(molten.libDir, ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"])
        }

        if let extra = profile.launch?.env {
            for (key, value) in extra {
                env[key] = value
            }
        }

        return LaunchPlan(
            executable: config.wineURL,
            arguments: Self.arguments(profile: profile, exe: exe),
            environment: env,
            workingDirectory: Self.workingDirectory(
                profile: profile,
                exe: exe,
                installRoot: installRoot
            ),
            logURL: paths.logs.appendingPathComponent("\(profile.id).log")
        )
    }

    /// A windowed title already gets a framed Mac window with traffic lights, so it
    /// runs directly. Only `desktop` mode needs the extra hosting window.
    public static func arguments(profile: TitleProfile, exe: URL) -> [String] {
        let game = [exe.path] + (profile.launch?.args ?? [])
        guard let window = profile.launch?.window, window.isHosted else { return game }
        return ["explorer", "/desktop=mogged-\(profile.id),\(window.size)"] + game
    }

    public static func workingDirectory(
        profile: TitleProfile,
        exe: URL,
        installRoot: URL?
    ) -> URL {
        let rel = profile.launch?.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rel.isEmpty, let installRoot else {
            return exe.deletingLastPathComponent()
        }
        let dest = installRoot.appendingPathComponent(rel, isDirectory: true)
        return FileManager.default.fileExists(atPath: dest.path) ? dest : exe.deletingLastPathComponent()
    }

    /// Source 2 looks for steam.inf next to gameinfo. Steam writes it; SteamCMD often does not.
    public static func ensureSteamInf(installRoot: URL, profile: TitleProfile) {
        guard let args = profile.launch?.args,
              let index = args.firstIndex(of: "-game"),
              args.index(after: index) < args.endIndex
        else { return }
        let mod = args[args.index(after: index)]
        let base = workingDirectory(profile: profile, exe: installRoot, installRoot: installRoot)
        let folder = base.appendingPathComponent(mod, isDirectory: true)
        let inf = folder.appendingPathComponent("steam.inf")
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path), !fm.fileExists(atPath: inf.path) else { return }
        let body = """
        ClientVersion=0
        ServerVersion=0
        ProductName=\(mod)
        appID=\(profile.steamAppId)

        """
        try? body.write(to: inf, atomically: true, encoding: .utf8)
    }

    /// Mac driver keys that give the game window a native frame with traffic lights.
    public func windowDecorationPlan(prefix: URL, config: BackendConfig, value: String) -> LaunchPlan {
        LaunchPlan(
            executable: config.wineURL,
            arguments: [
                "reg", "add", #"HKEY_CURRENT_USER\Software\Wine\Mac Driver"#,
                "/v", "Decorated", "/t", "REG_SZ", "/d", value, "/f",
            ],
            environment: [
                "WINEPREFIX": prefix.path,
                "WINEDEBUG": "-all",
            ],
            workingDirectory: prefix,
            logURL: paths.logs.appendingPathComponent("wineboot.log")
        )
    }

    public func winebootPlan(prefix: URL, config: BackendConfig) -> LaunchPlan {
        var arguments = ["wineboot", "--init"]
        let sibling = config.wineURL.deletingLastPathComponent().appendingPathComponent("wineboot")
        let executable: URL
        if FileManager.default.isExecutableFile(atPath: sibling.path) {
            executable = sibling
            arguments = ["--init"]
        } else {
            executable = config.wineURL
        }

        return LaunchPlan(
            executable: executable,
            arguments: arguments,
            environment: [
                "WINEPREFIX": prefix.path,
                "WINEDEBUG": "-all",
            ],
            workingDirectory: prefix,
            logURL: paths.logs.appendingPathComponent("wineboot.log")
        )
    }

    public func overlayTranslationDLLs(
        prefix: URL,
        profile: TitleProfile,
        config: BackendConfig
    ) {
        let sys32 = prefix.appendingPathComponent("drive_c/windows/system32")
        guard FileManager.default.fileExists(atPath: sys32.path) else { return }

        let stack = graphicsStack(for: profile)
        if stack == "dxvk-moltenvk" || stack == "vkd3d-moltenvk" {
            if let dxvk = resolvedDir(config.dxvkPath, bundled: ["dxvk/x64", "dxvk"]) {
                copyDLLs(["d3d11.dll", "d3d10core.dll", "d3d9.dll", "dxgi.dll"], from: dxvk, to: sys32)
            }
        }
        if stack == "vkd3d-moltenvk" {
            if let vkd3d = resolvedDir(config.vkd3dPath, bundled: ["vkd3d-proton/x64", "vkd3d-proton"]) {
                copyDLLs(["d3d12.dll", "d3d12core.dll"], from: vkd3d, to: sys32)
            }
        }
    }

    private func dllOverrides(for stack: String) -> String? {
        switch stack {
        case "dxvk-moltenvk":
            // DXVK-macOS ships d3d11/d3d10core only. Do not native-override dxgi/d3d9.
            return "d3d11,d3d10core=n,b"
        case "vkd3d-moltenvk":
            return "d3d12,d3d12core,dxgi=n,b"
        default:
            return nil
        }
    }

    /// ICD must be a JSON file. A raw dylib as VK_ICD_FILENAMES drops VK_KHR_surface and games exit 5.
    public static func moltenVkPaths(wine: URL, configured: String) -> (icd: String, libDir: String)? {
        let fm = FileManager.default
        var icds: [URL] = []
        if configured != "bundled" {
            icds.append(URL(fileURLWithPath: configured))
        }

        let wineRoot = wine.deletingLastPathComponent().deletingLastPathComponent()
        icds.append(contentsOf: [
            wineRoot.appendingPathComponent("lib/wine/x86_64-unix/vulkan/icd.d/MoltenVK_icd.json"),
            wineRoot.appendingPathComponent("share/vulkan/icd.d/MoltenVK_icd.json"),
            URL(fileURLWithPath: "/opt/homebrew/etc/vulkan/icd.d/MoltenVK_icd.json"),
            URL(fileURLWithPath: "/opt/homebrew/share/vulkan/icd.d/MoltenVK_icd.json"),
            URL(fileURLWithPath: "/usr/local/etc/vulkan/icd.d/MoltenVK_icd.json"),
            URL(fileURLWithPath: "/usr/local/share/vulkan/icd.d/MoltenVK_icd.json"),
        ])

        for icd in icds {
            guard icd.pathExtension.lowercased() == "json", fm.fileExists(atPath: icd.path) else { continue }
            let libDir = libDirForICD(icd, wineRoot: wineRoot)
            return (icd.path, libDir.path)
        }
        return nil
    }

    private static func libDirForICD(_ icd: URL, wineRoot: URL) -> URL {
        let wineLib = wineRoot.appendingPathComponent("lib/libMoltenVK.dylib")
        if FileManager.default.fileExists(atPath: wineLib.path) {
            return wineLib.deletingLastPathComponent()
        }
        let brew = URL(fileURLWithPath: "/opt/homebrew/lib/libMoltenVK.dylib")
        if FileManager.default.fileExists(atPath: brew.path) {
            return brew.deletingLastPathComponent()
        }
        return icd.deletingLastPathComponent()
    }

    private func writeDxvkConf() {
        let url = paths.caches.appendingPathComponent("dxvk.conf")
        try? FileManager.default.createDirectory(at: paths.caches, withIntermediateDirectories: true)
        let body = """
        dxvk.enableOpenVR = False
        dxvk.enableOpenXR = False
        """
        try? body.write(to: url, atomically: true, encoding: .utf8)
    }

    private func resolvedDir(_ value: String, bundled: [String]) -> URL? {
        if value != "bundled" {
            let url = URL(fileURLWithPath: value)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let staged = paths.dxvk
        if FileManager.default.fileExists(atPath: staged.appendingPathComponent("d3d11.dll").path) {
            return staged
        }
        guard let third = ThirdParty.root() else { return nil }
        for rel in bundled {
            let url = third.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private func copyDLLs(_ names: [String], from source: URL, to dest: URL) {
        let fm = FileManager.default
        for name in names {
            let from = source.appendingPathComponent(name)
            guard fm.fileExists(atPath: from.path) else { continue }
            let to = dest.appendingPathComponent(name)
            try? fm.removeItem(at: to)
            try? fm.copyItem(at: from, to: to)
        }
    }

    private func joinedPath(_ first: String, _ rest: String?) -> String {
        if let rest, !rest.isEmpty { return "\(first):\(rest)" }
        return first
    }
}

enum ThirdParty {
    static func root() -> URL? {
        if let env = ProcessInfo.processInfo.environment["MOGGED_THIRD_PARTY"], !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }

        var walker = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<10 {
            let candidate = walker.appendingPathComponent("third_party", isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            let parent = walker.deletingLastPathComponent()
            if parent.path == walker.path { break }
            walker = parent
        }
        return nil
    }
}
