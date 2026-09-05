import Foundation
import MoggedRuntime

/// Local file in Application Support. Keychain re-prompts on every unsigned rebuild.
enum SteamKeychain {
    private static var fileURL: URL {
        RuntimePaths.standard().root.appendingPathComponent("steam-login")
    }

    static func save(user: String, password: String, guardCode: String) {
        let user = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else { return }
        let blob = encode(user: user, password: password, guardCode: guardCode)
        guard let data = blob.data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(
            at: RuntimePaths.standard().root,
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    static func load() -> (user: String, password: String, guard: String)? {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        return decode(text)
    }

    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func encode(user: String, password: String, guardCode: String) -> String {
        "\(user)\n\(password)\n\(guardCode)"
    }

    static func decode(_ text: String) -> (user: String, password: String, guard: String)? {
        let parts = text.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let user = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let password = String(parts[1])
        let guardCode = parts.count > 2 ? String(parts[2]) : ""
        guard !user.isEmpty, !password.isEmpty else { return nil }
        return (user, password, guardCode)
    }
}
