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
    public init() {}

    public func record(_ event: TelemetryEvent) {
        do {
            try AppSupport.ensureDirectories()
            let url = AppSupport.logsDirectory.appendingPathComponent("runtime.jsonl")
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
}
