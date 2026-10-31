import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

public enum BiometricType: Sendable {
    case none
    case touchID
    case faceID
    case opticID

    public var title: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }
}

public actor BiometricAuthService {
    public static let shared = BiometricAuthService()

    private init() {}

    public func biometricType() -> BiometricType {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        default:
            return .none
        }
        #else
        return .none
        #endif
    }

    public func authenticate(reason: String = "Unlock ServerDeck") async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics unavailable or not enrolled
            return true
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
        #else
        return true
        #endif
    }
}
