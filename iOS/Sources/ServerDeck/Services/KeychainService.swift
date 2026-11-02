import Foundation
import Security

public enum KeychainService {
    private static let serviceName = "com.serverdeck.credentials"
    private static let tokenAccount = "api_token"
    private static let serverURLAccount = "server_url"
    private static let localURLAccount = "local_url"
    private static let tailscaleURLAccount = "tailscale_url"
    private static let serversAccount = "servers_json"
    private static let activeServerAccount = "active_server_id"

    // MARK: - Multi-Server Storage
    public static func saveServers(_ servers: [ServerConfig]) -> Bool {
        guard let data = try? JSONEncoder().encode(servers),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return false
        }
        return save(key: serversAccount, value: jsonStr)
    }

    public static func getServers() -> [ServerConfig]? {
        guard let jsonStr = load(key: serversAccount),
              let data = jsonStr.data(using: .utf8),
              let servers = try? JSONDecoder().decode([ServerConfig].self, from: data) else {
            return nil
        }
        return servers
    }

    public static func saveActiveServerId(_ id: UUID) -> Bool {
        save(key: activeServerAccount, value: id.uuidString)
    }

    public static func getActiveServerId() -> UUID? {
        guard let str = load(key: activeServerAccount), let uuid = UUID(uuidString: str) else {
            return nil
        }
        return uuid
    }

    // MARK: - API Token
    public static func saveToken(_ token: String) -> Bool {
        save(key: tokenAccount, value: token)
    }

    public static func getToken() -> String? {
        load(key: tokenAccount)
    }

    public static func deleteToken() -> Bool {
        delete(key: tokenAccount)
    }

    // MARK: - Local & Tailscale URLs
    public static func saveLocalURL(_ url: String) -> Bool {
        save(key: localURLAccount, value: url)
    }

    public static func getLocalURL() -> String? {
        load(key: localURLAccount)
    }

    public static func saveTailscaleURL(_ url: String) -> Bool {
        save(key: tailscaleURLAccount, value: url)
    }

    public static func getTailscaleURL() -> String? {
        load(key: tailscaleURLAccount)
    }

    // MARK: - Server URL (Legacy / Active)
    public static func saveServerURL(_ url: String) -> Bool {
        save(key: serverURLAccount, value: url)
    }

    public static func getServerURL() -> String? {
        load(key: serverURLAccount)
    }

    public static func deleteServerURL() -> Bool {
        delete(key: serverURLAccount)
    }

    // MARK: - Generic Keychain Helper
    private static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        // Delete existing if present
        SecItemDelete(query as CFDictionary)

        var newAttributes = query
        newAttributes[kSecValueData as String] = data
        newAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(newAttributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
