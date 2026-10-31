import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var config: ServerConfig
    @Published public var isUnlocked: Bool = true
    @Published public var showQuickActions: Bool = false
    @Published public var selectedTab: Int = 0

    public let apiClient: APIClient
    public let webSocketManager: WebSocketManager

    private let userDefaultsLocalURLKey = "serverdeck_local_url"
    private let userDefaultsTailscaleURLKey = "serverdeck_tailscale_url"
    private let userDefaultsURLKey = "serverdeck_server_url"
    private let userDefaultsInsecureSSLKey = "serverdeck_allow_insecure_ssl"
    private let userDefaultsMockDataKey = "serverdeck_use_mock_data"
    private let userDefaultsBiometricsKey = "serverdeck_require_biometrics"

    public init() {
        // Load settings from Keychain & UserDefaults
        var savedToken = KeychainService.getToken() ?? ""
        if savedToken.trimmingCharacters(in: .whitespaces).isEmpty {
            savedToken = "serverdeck-secret-2026"
            _ = KeychainService.saveToken(savedToken)
        }

        var savedLocal = KeychainService.getLocalURL() ?? UserDefaults.standard.string(forKey: "serverdeck_local_url") ?? ""
        if savedLocal.trimmingCharacters(in: .whitespaces).isEmpty || savedLocal.contains("tailscale-net") {
            savedLocal = "http://10.0.0.99:8080"
            _ = KeychainService.saveLocalURL(savedLocal)
        }

        var savedTailscale = KeychainService.getTailscaleURL() ?? UserDefaults.standard.string(forKey: "serverdeck_tailscale_url") ?? ""
        if savedTailscale.trimmingCharacters(in: .whitespaces).isEmpty || savedTailscale.contains("tailscale-net") {
            savedTailscale = "http://100.75.107.88:8080"
            _ = KeychainService.saveTailscaleURL(savedTailscale)
        }

        let allowInsecure = UserDefaults.standard.object(forKey: "serverdeck_allow_insecure_ssl") as? Bool ?? true
        let useMock = UserDefaults.standard.object(forKey: "serverdeck_use_mock_data") as? Bool ?? false
        let requireBiometrics = UserDefaults.standard.bool(forKey: "serverdeck_require_biometrics")

        let initialConfig = ServerConfig(
            localURL: savedLocal,
            tailscaleURL: savedTailscale,
            token: savedToken,
            allowInsecureSSL: allowInsecure,
            useMockData: useMock,
            requireBiometrics: requireBiometrics
        )

        self.config = initialConfig
        self.apiClient = APIClient(config: initialConfig)
        self.webSocketManager = WebSocketManager(config: initialConfig)

        if requireBiometrics {
            self.isUnlocked = false
        } else {
            self.isUnlocked = true
        }

        // Resolve active endpoint (LAN vs Tailscale) and connect WebSocket
        Task {
            let activeURL = await apiClient.resolveActiveBaseURL()
            webSocketManager.connect(preferredURL: activeURL)
        }
    }

    public func updateConfig(_ newConfig: ServerConfig) {
        self.config = newConfig

        // Persist token in Keychain
        if !newConfig.token.isEmpty {
            _ = KeychainService.saveToken(newConfig.token)
        } else {
            _ = KeychainService.deleteToken()
        }

        // Persist URLs in Keychain & UserDefaults
        _ = KeychainService.saveLocalURL(newConfig.localURL)
        _ = KeychainService.saveTailscaleURL(newConfig.tailscaleURL)
        _ = KeychainService.saveServerURL(newConfig.localURL)

        UserDefaults.standard.set(newConfig.localURL, forKey: userDefaultsLocalURLKey)
        UserDefaults.standard.set(newConfig.tailscaleURL, forKey: userDefaultsTailscaleURLKey)
        UserDefaults.standard.set(newConfig.url, forKey: userDefaultsURLKey)
        UserDefaults.standard.set(newConfig.allowInsecureSSL, forKey: userDefaultsInsecureSSLKey)
        UserDefaults.standard.set(newConfig.useMockData, forKey: userDefaultsMockDataKey)
        UserDefaults.standard.set(newConfig.requireBiometrics, forKey: userDefaultsBiometricsKey)

        Task {
            await apiClient.updateConfig(newConfig)
            webSocketManager.updateConfig(newConfig)
        }
    }

    public func authenticateWithBiometrics() async {
        guard config.requireBiometrics else {
            isUnlocked = true
            return
        }

        let success = await BiometricAuthService.shared.authenticate(reason: "Authenticate to access ServerDeck")
        if success {
            isUnlocked = true
            HapticManager.success()
        } else {
            HapticManager.error()
        }
    }

    public func lock() {
        if config.requireBiometrics {
            isUnlocked = false
        }
    }
}
