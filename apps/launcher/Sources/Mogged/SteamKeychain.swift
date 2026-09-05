import Foundation
import Security

/// Local Keychain only. Never writes Guard codes. Never sent off this Mac.
enum SteamKeychain {
    private static let service = "app.mogged.steam"
    private static let account = "steam-login"

    static func save(user: String, password: String) {
        let user = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else { return }
        let blob = "\(user)\n\(password)"
        guard let data = blob.data(using: .utf8) else { return }
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> (user: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data, let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let user = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let password = String(parts[1])
        guard !user.isEmpty, !password.isEmpty else { return nil }
        return (user, password)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
