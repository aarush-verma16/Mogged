import Foundation

/// Internal probe only. Never surface these names in the UI.
public struct BackendProbe: Sendable {
    public struct Detection: Sendable, Equatable {
        public let kind: Kind
        public let path: String
    }

    public enum Kind: String, Sendable {
        case gptk
        case crossover
        case wine
    }

    public init() {}

    public func detect() -> [Detection] {
        var found: [Detection] = []
        let fm = FileManager.default

        let crossover = "/Applications/CrossOver.app"
        if fm.fileExists(atPath: crossover) {
            found.append(Detection(kind: .crossover, path: crossover))
        }

        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        for name in ["gameportingtoolkit", "gptk"] {
            if let bin = which(name, pathDirs: pathDirs) {
                found.append(Detection(kind: .gptk, path: bin))
            }
        }

        let cellarHints = [
            "/opt/homebrew/opt/game-porting-toolkit",
            "/usr/local/opt/game-porting-toolkit",
        ]
        for hint in cellarHints where fm.fileExists(atPath: hint) {
            found.append(Detection(kind: .gptk, path: hint))
        }

        if let wine = which("wine64", pathDirs: pathDirs) ?? which("wine", pathDirs: pathDirs) {
            found.append(Detection(kind: .wine, path: wine))
        }

        return found
    }

    public var isAvailable: Bool { !detect().isEmpty }

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
