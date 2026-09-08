import Foundation
import Testing
@testable import MoggedRuntime

/// Contract checks that grow with the repo: a new profile, runtime file, error, or
/// Steam state is automatically part of the next `swift test` run.
@Suite("Inventory")
struct InventoryTests {
    @Test
    func everyProfileOnDiskLoadsAndStaysOnTheFreeStack() throws {
        let files = try profileJSONFiles()
        let profiles = try ProfileLoader.load()
        let ids = Set(profiles.map(\.id))
        let fileIds = Set(files.map { $0.deletingPathExtension().lastPathComponent })

        #expect(!profiles.isEmpty)
        #expect(ids == fileIds, "Profile filename must match id. Files \(fileIds) vs ids \(ids)")

        let stacks: Set<String> = ["dxvk-moltenvk", "vkd3d-moltenvk", "moltenvk"]
        for profile in profiles {
            #expect(!profile.id.isEmpty)
            #expect(profile.id == profile.id.lowercased())
            #expect(profile.steamAppId > 0)
            #expect(!profile.displayName.isEmpty)
            #expect(!profile.executables.isEmpty)
            #expect(!profile.executables.contains { $0.isEmpty })
            let stack = BackendLauncher().graphicsStack(for: profile)
            #expect(stacks.contains(stack), "\(profile.id) remapped to paid/unknown stack \(stack)")
            #expect(TitleProfile.Role.allCases.contains(profile.role))
            #expect(TitleProfile.GraphicsAPI.allCases.contains(profile.graphicsApi))
            #expect(TitleProfile.AntiCheat.allCases.contains(profile.antiCheat))
        }

        #expect(profiles.contains { $0.role == .smoke })
        #expect(profiles.contains { $0.role == .primaryDemo })
    }

    @Test(arguments: TitleProfile.Role.allCases)
    func everyRoleHasAStableRawValue(_ role: TitleProfile.Role) {
        switch role {
        case .smoke: #expect(role.rawValue == "smoke")
        case .primaryDemo: #expect(role.rawValue == "primary-demo")
        case .generalize: #expect(role.rawValue == "generalize")
        case .catalog: #expect(role.rawValue == "catalog")
        }
    }

    @Test(arguments: TitleProfile.GraphicsAPI.allCases)
    func everyGraphicsAPIRemapsOffPaidBackends(_ api: TitleProfile.GraphicsAPI) throws {
        let profile = try decodeProfile("""
        {
          "id": "api-\(api.rawValue)",
          "steamAppId": 1,
          "displayName": "API",
          "role": "catalog",
          "engine": "test",
          "graphicsApi": "\(api.rawValue)",
          "antiCheat": "none",
          "macNative": false,
          "backend": { "preferred": "d3dmetal" },
          "executables": ["game.exe"]
        }
        """)
        let stack = BackendLauncher().graphicsStack(for: profile)
        switch api {
        case .d3d12:
            #expect(stack == "vkd3d-moltenvk")
        case .vulkan:
            #expect(stack == "moltenvk")
        case .d3d9, .d3d11, .opengl, .mixed:
            #expect(stack == "dxvk-moltenvk")
        }
    }

    @Test(arguments: TitleProfile.AntiCheat.allCases)
    func everyAntiCheatValueDecodes(_ kind: TitleProfile.AntiCheat) {
        #expect(!kind.rawValue.isEmpty)
    }

    @Test(arguments: SteamServicesState.allCases)
    func everySteamStateMapsToAPlayOutcome(_ state: SteamServicesState) {
        switch state {
        case .ready:
            #expect(state == .ready)
        case .signingIn, .updating:
            #expect(MoggedError.steamSignInNeeded.userMessage.lowercased().contains("play"))
        case .needsGuardCode:
            #expect(MoggedError.steamGuardCodeNeeded.userMessage.lowercased().contains("code"))
        case .needsAccount:
            #expect(MoggedError.steamAccountNeeded.userMessage.lowercased().contains("account"))
        case .notInstalled:
            #expect(MoggedError.steamServicesMissing.userMessage.lowercased().contains("steam"))
        }
    }

    @Test
    func everyMoggedErrorHasAToolkitFreeUserMessage() {
        let banned = ["wine", "gptk", "crossover", "proton", "bottle", "prefix", "winetricks"]
        let samples = moggedErrorSamples()
        #expect(Set(samples.map(errorTag)) == Set(0..<samples.count))
        for error in samples {
            let text = error.userMessage.lowercased()
            #expect(!error.userMessage.isEmpty)
            #expect(!error.logDescription.isEmpty)
            for word in banned {
                #expect(!text.contains(word), "user message leaked '\(word)': \(error.userMessage)")
            }
        }
    }

    @Test
    func everyRuntimeSourceIsNamedInTests() throws {
        let fm = FileManager.default
        let sources = try fm.contentsOfDirectory(
            at: TestRepo.sourcesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let tests = try concatenatedTestSources()
        var missing: [String] = []
        for source in sources {
            let text = try String(contentsOf: source, encoding: .utf8)
            let types = publicTypeNames(in: text)
            let stem = source.deletingPathExtension().lastPathComponent
            let mentioned: Bool
            if types.isEmpty {
                mentioned = tests.contains(stem)
            } else {
                mentioned = types.contains { tests.contains($0) }
            }
            if !mentioned {
                missing.append(stem + (types.isEmpty ? "" : " (\(types.joined(separator: ", ")))"))
            }
        }
        #expect(
            missing.isEmpty,
            "New runtime file(s) need a test that names them: \(missing.joined(separator: ", "))"
        )
    }

    @Test
    func schemaRequiredKeysStayPresentOnEveryProfile() throws {
        let schema = try String(
            contentsOf: TestRepo.profilesDirectory.appendingPathComponent("_schema.json"),
            encoding: .utf8
        )
        let required = ["id", "steamAppId", "displayName", "role", "engine", "graphicsApi", "antiCheat", "macNative", "backend", "executables"]
        for key in required {
            #expect(schema.contains("\"\(key)\""), "schema lost required key \(key)")
        }
        for url in try profileJSONFiles() {
            let json = try String(contentsOf: url, encoding: .utf8)
            for key in required {
                #expect(json.contains("\"\(key)\""), "\(url.lastPathComponent) missing \(key)")
            }
        }
    }
}

private func profileJSONFiles() throws -> [URL] {
    try FileManager.default.contentsOfDirectory(
        at: TestRepo.profilesDirectory,
        includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix("_") }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

private func concatenatedTestSources() throws -> String {
    let files = try FileManager.default.contentsOfDirectory(
        at: TestRepo.testsDirectory,
        includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "TestSupport.swift" }
    var combined = ""
    for file in files {
        combined += (try String(contentsOf: file, encoding: .utf8)) + "\n"
    }
    return combined
}

private func publicTypeNames(in source: String) -> [String] {
    let regex = try? NSRegularExpression(
        pattern: #"^public\s+(?:final\s+)?(?:actor|class|enum|struct|protocol)\s+(\w+)"#,
        options: [.anchorsMatchLines]
    )
    guard let regex else { return [] }
    let ns = source as NSString
    let range = NSRange(location: 0, length: ns.length)
    return regex.matches(in: source, range: range).compactMap { match in
        guard match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }
}

/// One of each MoggedError. The tag switch is exhaustive — a new case is a compile error.
private func moggedErrorSamples() -> [MoggedError] {
    [
        .profilesNotFound,
        .invalidProfile("x.json", "boom"),
        .gameNotFound("x"),
        .executableNotFound("game.exe"),
        .runtimeUnavailable,
        .alreadyRunning("x"),
        .notRunning("x"),
        .launchFailed,
        .alreadyInstalling("x"),
        .installFailed("x"),
        .installNeedsAccount,
        .steamSignInNeeded,
        .steamGuardCodeNeeded,
        .steamAccountNeeded,
        .steamServicesMissing,
    ]
}

private func errorTag(_ error: MoggedError) -> Int {
    switch error {
    case .profilesNotFound: return 0
    case .invalidProfile: return 1
    case .gameNotFound: return 2
    case .executableNotFound: return 3
    case .runtimeUnavailable: return 4
    case .alreadyRunning: return 5
    case .notRunning: return 6
    case .launchFailed: return 7
    case .alreadyInstalling: return 8
    case .installFailed: return 9
    case .installNeedsAccount: return 10
    case .steamSignInNeeded: return 11
    case .steamGuardCodeNeeded: return 12
    case .steamAccountNeeded: return 13
    case .steamServicesMissing: return 14
    }
}
