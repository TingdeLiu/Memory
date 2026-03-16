import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return String(localized: "language.system")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        }
    }

    var locale: Locale? {
        switch self {
        case .system:
            return nil
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .traditionalChinese:
            return Locale(identifier: "zh-Hant")
        }
    }
}

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    private let languageKey = "appLanguage"

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            applyLanguage()
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: saved) {
            currentLanguage = language
        } else {
            currentLanguage = .system
        }
    }

    var effectiveLocale: Locale {
        if let locale = currentLanguage.locale {
            return locale
        }
        return Locale.current
    }

    var effectiveLanguageCode: String {
        switch currentLanguage {
        case .system:
            return Locale.current.language.languageCode?.identifier ?? "en"
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }

    private func applyLanguage() {
        guard currentLanguage != .system else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            return
        }

        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
    }
}

// MARK: - View Modifier

struct LanguageEnvironmentModifier: ViewModifier {
    private var languageManager: LanguageManager { LanguageManager.shared }

    func body(content: Content) -> some View {
        content
            .environment(\.locale, languageManager.effectiveLocale)
    }
}

extension View {
    func withLanguageEnvironment() -> some View {
        modifier(LanguageEnvironmentModifier())
    }
}
