import Foundation
import Security

public final class KeychainStorage: Sendable {
    private let service = "com.twmissingu.LLMQuotaIsland"

    public init() {}

    public func save(key: String, for ref: String) throws {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw QuotaError.unknown("Keychain save failed: \(status)")
        }
    }

    public func load(for ref: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw QuotaError.invalidKey
        }
        guard let key = String(data: data, encoding: .utf8) else {
            throw QuotaError.unknown("Keychain data decode failed")
        }
        return key
    }

    public func delete(for ref: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref
        ]
        SecItemDelete(query as CFDictionary)
    }

    public func maskedKey(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)***\(suffix)"
    }
}
