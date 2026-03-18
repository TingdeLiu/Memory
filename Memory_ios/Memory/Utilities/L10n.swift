import Foundation

/// Localization helpers for dynamic strings with parameters.
enum L10n {
    // MARK: - Dynamic strings

    static func homeFilterFrom(_ date: String) -> String {
        String(localized: "home.filter.from \(date)")
    }

    static func homeFilterUntil(_ date: String) -> String {
        String(localized: "home.filter.until \(date)")
    }

    static func memoryListResults(_ count: Int) -> String {
        if count == 1 {
            return String(localized: "memoryList.result \(count)")
        }
        return String(localized: "memoryList.results \(count)")
    }

    static func draftSaved(_ relative: String) -> String {
        String(localized: "memoryEditor.draftSaved \(relative)")
    }

    static func tagAccessibilityLabel(_ tag: String) -> String {
        String(localized: "memoryEditor.tagLabel \(tag)")
    }

    static func contactImportButton(_ count: Int) -> String {
        String(localized: "contactImport.importButton \(count)")
    }

    static func contactsAvailable(_ count: Int) -> String {
        String(localized: "contactImport.contactsAvailable \(count)")
    }

    static func alreadyImported(_ count: Int) -> String {
        String(localized: "contactImport.alreadyImported \(count)")
    }

    static func contactDeleteMessage(_ name: String, _ count: Int) -> String {
        String(localized: "contactDetail.deleteConfirm.message \(name) \(count)")
    }

    static func contactEditorDeleteMessage(_ name: String) -> String {
        String(localized: "contactEditor.deleteConfirm.message \(name)")
    }

    static func messageTo(_ name: String) -> String {
        String(localized: "messageEditor.to \(name)")
    }

    static func messagePlaceholder(_ name: String) -> String {
        String(localized: "messageEditor.placeholder \(name)")
    }

    static func aiChatError(_ error: String) -> String {
        String(localized: "aiChat.error \(error)")
    }

    static func clearKeyMessage(_ provider: String) -> String {
        String(localized: "aiSettings.clearMessage \(provider)")
    }

    static func sealedCount(_ count: Int) -> String {
        String(localized: "contactList.sealed \(count)")
    }

    static func tagsCount(_ count: Int) -> String {
        String(localized: "timeline.tags \(count)")
    }

    static func lockScreenUnlock(_ biometric: String) -> String {
        String(localized: "lockScreen.unlock \(biometric)")
    }

    static func securityAppLockFooter(_ biometric: String) -> String {
        String(localized: "security.appLockFooter \(biometric)")
    }

    static func purchaseFor(_ price: String) -> String {
        String(localized: "purchase.purchaseFor \(price)")
    }

    // MARK: - Time Capsule

    static func capsuleCountdown(days: Int, hours: Int) -> String {
        String(localized: "capsule.countdown.daysHours \(days) \(hours)")
    }

    static func capsuleLocationRadius(_ meters: Int) -> String {
        String(localized: "capsule.location.radius \(meters)")
    }

    static func capsuleOpenedOn(_ date: String) -> String {
        String(localized: "capsule.openedOn \(date)")
    }

    static func homeCapsuleCount(_ count: Int) -> String {
        String(localized: "home.capsule.count \(count)")
    }
}
