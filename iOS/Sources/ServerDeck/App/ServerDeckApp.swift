import SwiftUI

#if os(iOS)
@main
#endif
public struct ServerDeckApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some Scene {
        WindowGroup {
            Group {
                if !appState.isUnlocked {
                    BiometricsLockView(
                        biometricType: .faceID,
                        onUnlock: {
                            Task {
                                await appState.authenticateWithBiometrics()
                            }
                        }
                    )
                } else {
                    MainTabView()
                }
            }
            .environmentObject(appState)
            .onChange(of: scenePhase) {
                if scenePhase == .background {
                    appState.lockApp()
                } else if scenePhase == .active && !appState.isUnlocked {
                    Task {
                        await appState.authenticateWithBiometrics()
                    }
                }
            }
        }
    }
}
