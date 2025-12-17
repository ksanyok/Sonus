import Foundation

enum LanguageUtils {
    static func normalizeLanguageCode(_ raw: String) -> String? {
        let s = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !s.isEmpty else { return nil }

        // Common exact / prefix matches
        if s == "ru" || s.hasPrefix("ru-") || s.contains("рус") || s.contains("russian") { return "ru" }
        if s == "en" || s.hasPrefix("en-") || s.contains("англ") || s.contains("english") { return "en" }
        if s == "uk" || s.hasPrefix("uk-") || s.contains("укр") || s.contains("ukrain") { return "uk" }
        if s == "de" || s.hasPrefix("de-") || s.contains("нем") || s.contains("german") { return "de" }
        if s == "fr" || s.hasPrefix("fr-") || s.contains("фран") || s.contains("french") { return "fr" }
        if s == "es" || s.hasPrefix("es-") || s.contains("испан") || s.contains("spanish") { return "es" }
        if s == "it" || s.hasPrefix("it-") || s.contains("итал") || s.contains("italian") { return "it" }
        if s == "pt" || s.hasPrefix("pt-") || s.contains("порту") || s.contains("portugu") { return "pt" }
        if s == "tr" || s.hasPrefix("tr-") || s.contains("тур") || s.contains("turkish") { return "tr" }
        if s == "pl" || s.hasPrefix("pl-") || s.contains("поль") || s.contains("polish") { return "pl" }
        if s == "cs" || s.hasPrefix("cs-") || s.contains("чеш") || s.contains("czech") { return "cs" }
        if s == "ja" || s.hasPrefix("ja-") || s.contains("япон") || s.contains("japan") { return "ja" }
        if s == "ko" || s.hasPrefix("ko-") || s.contains("корей") || s.contains("korean") { return "ko" }
        if s == "zh" || s.hasPrefix("zh-") || s.contains("кит") || s.contains("chinese") { return "zh" }

        // If model already returns something like "en-US", take the primary subtag.
        if let primary = s.split(separator: "-").first, primary.count == 2 {
            return String(primary)
        }

        return nil
    }

    static func flagEmoji(forLanguageCode code: String?) -> String {
        guard let code else { return "🌐" }
        switch code.lowercased() {
        case "ru": return "🇷🇺"
        case "en": return "🇺🇸"
        case "uk": return "🇺🇦"
        case "de": return "🇩🇪"
        case "fr": return "🇫🇷"
        case "es": return "🇪🇸"
        case "it": return "🇮🇹"
        case "pt": return "🇵🇹"
        case "tr": return "🇹🇷"
        case "pl": return "🇵🇱"
        case "cs": return "🇨🇿"
        case "ja": return "🇯🇵"
        case "ko": return "🇰🇷"
        case "zh": return "🇨🇳"
        default: return "🌐"
        }
    }

    static func flagEmoji(forLanguageRaw raw: String) -> String {
        let code = normalizeLanguageCode(raw)
        return flagEmoji(forLanguageCode: code)
    }
}
