import Foundation

public struct TelemetryEvent: Codable, Sendable {
    public let ts: String
    public let event: String
    public let titleId: String?
    public let detail: String?

    public init(event: String, titleId: String? = nil, detail: String? = nil) {
        self.ts = ISO8601DateFormatter().string(from: Date())
        self.event = event
        self.titleId = titleId
        self.detail = detail
    }
}

public struct TelemetryLog: Sendable {
    private let paths: RuntimePaths

    public init(paths: RuntimePaths = .standard()) {
        self.paths = paths
    }

    public func record(_ event: TelemetryEvent) {
        do {
            try paths.ensure()
            let url = jsonlURL
            var line = try JSONEncoder().encode(event)
            line.append(contentsOf: [0x0A])
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(line)
            } else {
                try line.write(to: url)
            }
        } catch {
            fputs("mogged telemetry write failed: \(error)\n", stderr)
        }
    }

    public var jsonlURL: URL {
        paths.logs.appendingPathComponent("runtime.jsonl")
    }

    public func tailJSONL(maxBytes: Int = 48_000) -> String {
        Self.tail(url: jsonlURL, maxBytes: maxBytes)
    }

    public static func tail(url: URL, maxBytes: Int = 48_000) -> String {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return "" }
        if data.count <= maxBytes {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return String(data: data.suffix(maxBytes), encoding: .utf8) ?? ""
    }
}
