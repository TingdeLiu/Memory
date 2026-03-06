import Foundation
import LocalAuthentication

/// Utility for Face ID / Touch ID authentication.
enum BiometricAuth {

    enum BiometricType {
        case faceID
        case touchID
        case opticID
        case none

        var displayName: String {
            switch self {
            case .faceID: return String(localized: "biometric.faceID")
            case .touchID: return String(localized: "biometric.touchID")
            case .opticID: return String(localized: "biometric.opticID")
            case .none: return String(localized: "biometric.passcode")
            }
        }

        var systemImage: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .opticID: return "opticid"
            case .none: return "lock.fill"
            }
        }
    }

    /// Determine the available biometric type.
    static var availableType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    /// Whether any form of biometric is available.
    static var isBiometricAvailable: Bool {
        availableType != .none
    }

    /// Whether device passcode is set (required for any auth).
    static var isPasscodeSet: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Authenticate the user with biometrics, falling back to device passcode.
    static func authenticate(reason: String = String(localized: "biometric.reason")) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "biometric.fallback")
        var error: NSError?

        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        do {
            return try await context.evaluatePolicy(policy, localizedReason: reason)
        } catch {
            return false
        }
    }

    /// Authenticate specifically for viewing private content (stricter reason).
    static func authenticateForPrivateContent() async -> Bool {
        await authenticate(reason: String(localized: "biometric.reasonPrivate"))
    }
}
