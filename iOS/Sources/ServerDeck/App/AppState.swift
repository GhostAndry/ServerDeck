import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var servers: [ServerConfig] = []
    @Published public var activeServerId: UUID
    @Published public var isUnlocked: Bool = true
    @Published public var showQuickActions: Bool = false
    @Published public var selectedTab: Int = 0

    public let apiClient: APIClient
    public let webSocketManager: WebSocketManager

    private let userDefaultsServersKey = "serverdeck_servers_list"
    private let userDefaultsActiveIdKey = "serverdeck_active_server_id"

    public var config: ServerConfig {
        get {
            servers.first(where: { $0.id == activeServerId }) ?? servers.first ?? ServerConfig()
        }
        set {
            updateConfig(newValue)
        }
    }

    public init() {
        // 1. Load multi-server list from Keychain or UserDefaults
        var loadedServers = KeychainService.getServers()
        if loadedServers == nil || loadedServers?.isEmpty == true {
            // Check legacy UserDefaults fallback
            if let data = UserDefaults.standard.data(forKey: "serverdeck_servers_list"),
               let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data), !decoded.isEmpty {
                loadedServers = decoded
            }
        }

        // 2. If no servers exist yet, initialize with default server srv-01
        if loadedServers == nil || loadedServers?.isEmpty == true {
            var savedToken = KeychainService.getToken() ?? ""
            if savedToken.trimmingCharacters(in: .whitespaces).isEmpty {
                savedToken = "serverdeck-secret-2026"
                _ = KeychainService.saveToken(savedToken)
            }

            var savedLocal = KeychainService.getLocalURL() ?? ""
            if savedLocal.trimmingCharacters(in: .whitespaces).isEmpty || savedLocal.contains("tailscale-net") {
                savedLocal = "http://10.0.0.99:8080"
                _ = KeychainService.saveLocalURL(savedLocal)
            }

            var savedTailscale = KeychainService.getTailscaleURL() ?? ""
            if savedTailscale.trimmingCharacters(in: .whitespaces).isEmpty || savedTailscale.contains("tailscale-net") {
                savedTailscale = "http://100.75.107.88:8080"
                _ = KeychainService.saveTailscaleURL(savedTailscale)
            }

            let initialServer = ServerConfig(
                id: UUID(),
                name: "srv-01",
                localURL: savedLocal,
                tailscaleURL: savedTailscale,
                token: savedToken,
                allowInsecureSSL: true,
                useMockData: false,
                requireBiometrics: false
            )

            loadedServers = [initialServer]
            _ = KeychainService.saveServers([initialServer])
        }

        let initialList = loadedServers ?? []
        self.servers = initialList

        // 3. Determine active server ID
        let savedActiveId = KeychainService.getActiveServerId()
        let activeId: UUID
        if let savedActiveId = savedActiveId, initialList.contains(where: { $0.id == savedActiveId }) {
            activeId = savedActiveId
        } else {
            activeId = initialList.first?.id ?? UUID()
        }

        self.activeServerId = activeId

        let currentActive = initialList.first(where: { $0.id == activeId }) ?? initialList.first ?? ServerConfig()

        self.apiClient = APIClient(config: currentActive)
        self.webSocketManager = WebSocketManager(config: currentActive)

        if currentActive.requireBiometrics {
            self.isUnlocked = false
        } else {
            self.isUnlocked = true
        }

        // Fast endpoint resolution and WS connect
        Task {
            let activeURL = await apiClient.resolveActiveBaseURL()
            webSocketManager.connect(preferredURL: activeURL)
        }
    }

    // MARK: - Multi-Server Management

    public func switchServer(to id: UUID) {
        guard let target = servers.first(where: { $0.id == id }) else { return }
        self.activeServerId = id
        _ = KeychainService.saveActiveServerId(id)

        UserDefaults.standard.set(id.uuidString, forKey: userDefaultsActiveIdKey)

        HapticManager.selection()

        Task {
            await apiClient.updateConfig(target)
            let activeURL = await apiClient.resolveActiveBaseURL()
            webSocketManager.updateConfig(target)
            webSocketManager.connect(preferredURL: activeURL)
        }
    }

    public func addServer(_ newServer: ServerConfig) {
        servers.append(newServer)
        persistServers()
        switchServer(to: newServer.id)
    }

    public func updateConfig(_ newConfig: ServerConfig) {
        if let idx = servers.firstIndex(where: { $0.id == newConfig.id }) {
            servers[idx] = newConfig
        } else {
            servers.append(newConfig)
        }
        persistServers()

        if activeServerId == newConfig.id {
            Task {
                await apiClient.updateConfig(newConfig)
                let activeURL = await apiClient.resolveActiveBaseURL()
                webSocketManager.updateConfig(newConfig)
                webSocketManager.connect(preferredURL: activeURL)
            }
        }
    }

    public func deleteServer(id: UUID) {
        guard servers.count > 1 else { return } // Keep at least one server configured
        servers.removeAll { $0.id == id }
        persistServers()

        if activeServerId == id {
            if let next = servers.first {
                switchServer(to: next.id)
            }
        }
    }

    private func persistServers() {
        _ = KeychainService.saveServers(servers)
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: userDefaultsServersKey)
        }
    }

    public func authenticateWithBiometrics() async {
        guard config.requireBiometrics else {
            isUnlocked = true
            return
        }

        let success = await BiometricAuthService.shared.authenticate(
            reason: "Sblocca ServerDeck per gestire il tuo homelab."
        )

        await MainActor.run {
            self.isUnlocked = success
        }
    }

    public func lockApp() {
        if config.requireBiometrics {
            isUnlocked = false
        }
    }
}
