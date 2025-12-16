import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ru

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }
}

final class LocalizationService: ObservableObject {
    static let storageKey = "sonus.language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        language = AppLanguage(rawValue: saved ?? "en") ?? .en
    }

    func t(_ en: String, ru: String) -> String {
        switch language {
        case .en: return en
        case .ru: return ru
        }
    }

    var locale: Locale {
        Locale(identifier: language.rawValue)
    }
}
