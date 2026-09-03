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

        if let wine = which("wine64", pathDirs: pathDirs + extras)
            ?? which("wine", pathDirs: pathDirs + extras)
        {
            return wine
        }

        let appBins = [
            "/Applications/Wine Staging.app/Contents/Resources/wine/bin",
            "/Applications/Wine Stable.app/Contents/Resources/wine/bin",
            "/Applications/Wine Devel.app/Contents/Resources/wine/bin",
            AppSupport.root.appendingPathComponent("engine/wine/bin").path,
            AppSupport.root.appendingPathComponent("engine/Wine Staging.app/Contents/Resources/wine/bin").path,
        ]
        return which("wine64", pathDirs: appBins) ?? which("wine", pathDirs: appBins)
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
