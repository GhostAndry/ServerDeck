import SwiftUI
import Combine

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var localURL: String = ""
    @Published public var tailscaleURL: String = ""
    @Published public var serverURL: String = ""
    @Published public var token: String = ""
    @Published public var allowInsecureSSL: Bool = true
    @Published public var useMockData: Bool = false
    @Published public var requireBiometrics: Bool = false

    @Published public private(set) var isTestingConnection: Bool = false
    @Published public private(set) var testStatusMessage: String?
    @Published public private(set) var testSucceeded: Bool?
    @Published public private(set) var biometricType: BiometricType = .none
    @Published public var hasSavedSuccessfully: Bool = false

    public init(config: ServerConfig) {
        self.localURL = config.localURL
        self.tailscaleURL = config.tailscaleURL
        self.serverURL = config.url
        self.token = config.token
        self.allowInsecureSSL = config.allowInsecureSSL
        self.useMockData = config.useMockData
        self.requireBiometrics = config.requireBiometrics

        Task {
            let bioType = await BiometricAuthService.shared.biometricType()
            await MainActor.run {
                self.biometricType = bioType
            }
        }
    }

    public func testConnection() async {
        isTestingConnection = true
        testStatusMessage = nil
        testSucceeded = nil
        HapticManager.light()

        let testConfig = ServerConfig(
            localURL: localURL,
            tailscaleURL: tailscaleURL,
            token: token,
            allowInsecureSSL: allowInsecureSSL,
            useMockData: useMockData,
            requireBiometrics: requireBiometrics
        )

        let testClient = APIClient(config: testConfig)

        do {
            let result = try await testClient.testConnection()
            if result.success {
                testSucceeded = true
                testStatusMessage = "Connessione riuscita via \(result.modeDescription)! Latenza: \(result.latencyMs) ms"
                HapticManager.success()
            }
        } catch {
            testSucceeded = false
            testStatusMessage = "Failed: \(error.localizedDescription)"
            HapticManager.error()
        }

        isTestingConnection = false
    }

    public func save(appState: AppState) {
        let updated = ServerConfig(
            localURL: localURL,
            tailscaleURL: tailscaleURL,
            token: token,
            allowInsecureSSL: allowInsecureSSL,
            useMockData: useMockData,
            requireBiometrics: requireBiometrics
        )
        appState.updateConfig(updated)
        hasSavedSuccessfully = true
        HapticManager.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hasSavedSuccessfully = false
        }
    }
}
