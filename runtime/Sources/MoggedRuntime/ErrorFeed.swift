import Foundation

/// Pulls failure lines out of operator logs so the app can show them without a terminal.
public enum ErrorFeed: Sendable {
    public static func lines(from text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && isError($0) }
    }

    public static func isError(_ raw: String) -> Bool {
        let line = raw.lowercased()
        let hits = [
            "error", "failed", "failure", "fatal", "crash", "exception",
            "panic", "denied", "invalid", "traceback", "err:",
            "launch.failed", "install.failed", "install.stopped",
        ]
        return hits.contains { line.contains($0) }
    }

    public static func digest(runtimeLog: String, titleLog: String, extra: [String] = []) -> String {
        var seen = Set<String>()
        var out: [String] = []
        for line in extra + lines(from: runtimeLog) + lines(from: titleLog) {
            if seen.insert(line).inserted {
                out.append(line)
            }
        }
        return out.suffix(80).joined(separator: "\n")
    }
}
