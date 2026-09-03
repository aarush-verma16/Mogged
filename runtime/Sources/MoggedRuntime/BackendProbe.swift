import Foundation

/// Internal probe only. Never surface these names in the UI.
public struct BackendProbe: Sendable {
    public struct Detection: Sendable, Equatable {
        public let kind: Kind
        public let path: String
    }

    public enum Kind: String, Sendable {
        case wine
    }

    private let forcedWine: String?
    private let discover: Bool

    public init() {
        self.forcedWine = nil
        self.discover = true
    }

    /// Test seam: skip PATH lookup.
    public init(fixedWine: String?) {
        self.forcedWine = fixedWine
        self.discover = false
    }

    public func detect() -> [Detection] {
        if let wine = wineBinary() {
            return [Detection(kind: .wine, path: wine)]
        }
        return []
    }

    public var isAvailable: Bool { wineBinary() != nil }

    public func wineBinary() -> String? {
        if !discover { return forcedWine }

        if let env = ProcessInfo.processInfo.environment["MOGGED_WINE"],
           FileManager.default.isExecutableFile(atPath: env)
        {
            return env
        }

        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let extras = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/homebrew/opt/wine-stable/bin",
            "/usr/local/opt/wine-stable/bin",
        ]

        if let third = ThirdParty.root() {
            let bundled = third.appendingPathComponent("wine/bin").path
            if let found = which("wine64", pathDirs: [bundled]) ?? which("wine", pathDirs: [bundled]) {
                return found
            }
        }

        return which("wine64", pathDirs: pathDirs + extras)
            ?? which("wine", pathDirs: pathDirs + extras)
    }

    private func which(_ name: String, pathDirs: [String]) -> String? {
        for dir in pathDirs {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}
