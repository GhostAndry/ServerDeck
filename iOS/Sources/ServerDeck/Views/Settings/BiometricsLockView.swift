import SwiftUI

public struct BiometricsLockView: View {
    let biometricType: BiometricType
    var onUnlock: () -> Void

    public init(biometricType: BiometricType, onUnlock: @escaping () -> Void) {
        self.biometricType = biometricType
        self.onUnlock = onUnlock
    }

    public var body: some View {
        ZStack {
            Theme.systemBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 100, height: 100)

                    Image(systemName: biometricIcon)
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                }

                VStack(spacing: 8) {
                    Text("ServerDeck Locked")
                        .font(.system(size: 24, weight: .bold))

                    Text("Authentication is required to access your homelab server.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    onUnlock()
                } label: {
                    Label("Unlock with \(biometricType.title)", systemImage: biometricIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 36)
            }
        }
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }
}
