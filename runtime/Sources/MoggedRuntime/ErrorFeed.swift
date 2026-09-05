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

    /// Text appended after a previous snapshot. Empty mark → treat everything as historical.
    public static func added(after mark: String, in full: String) -> String {
        if mark.isEmpty { return "" }
        if full.hasPrefix(mark) { return String(full.dropFirst(mark.count)) }
        return full
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
