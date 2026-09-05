import Foundation

public struct SteamCredentials: Sendable, Equatable {
    public let user: String
    public let password: String
    public let guardCode: String

    public init(user: String, password: String, guardCode: String = "") {
        self.user = user
        self.password = password
        self.guardCode = guardCode
    }
}

/// A local 0600 file, not the Keychain: an unsigned dev rebuild re-prompts on every
/// launch. Both the app and the runtime read it — the runtime needs it to sign a
/// Steam client in without Steam's own login window.
public enum SteamCredentialStore {
    public static func fileURL(paths: RuntimePaths = .standard()) -> URL {
        paths.root.appendingPathComponent("steam-login")
    }

    public static func save(
        user: String,
        password: String,
        guardCode: String,
        paths: RuntimePaths = .standard()
    ) {
        let user = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else { return }
        guard let data = encode(user: user, password: password, guardCode: guardCode).data(using: .utf8)
        else { return }
        let url = fileURL(paths: paths)
        try? FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func load(paths: RuntimePaths = .standard()) -> SteamCredentials? {
        guard let text = try? String(contentsOf: fileURL(paths: paths), encoding: .utf8) else { return nil }
        return decode(text)
    }

    public static func delete(paths: RuntimePaths = .standard()) {
        try? FileManager.default.removeItem(at: fileURL(paths: paths))
    }

    public static func encode(user: String, password: String, guardCode: String) -> String {
        "\(user)\n\(password)\n\(guardCode)"
    }

    public static func decode(_ text: String) -> SteamCredentials? {
        let parts = text.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let user = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let password = String(parts[1])
        let code = parts.count > 2 ? String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        guard !user.isEmpty, !password.isEmpty else { return nil }
        return SteamCredentials(user: user, password: password, guardCode: code)
    }
}
