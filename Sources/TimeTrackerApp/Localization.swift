import Foundation
import TimeTrackerCore

/// App-owned UI text, decoded from the bundled `Resources/Localization.json`.
///
/// The catalog is the single source of copy: `en` reproduces the strings that
/// used to be hardcoded, `es` translates them. A missing lookup falls back to
/// `en`, then to the key itself, so a dropped key degrades to readable text.
/// Views read it through `@EnvironmentObject`, so changing the language
/// re-renders every visible surface.
@MainActor
final class Localization: ObservableObject {
    static let shared = Localization()

    /// `UserDefaults` key holding the frozen language choice: `en` or `es`.
    static let localeKey = "uiLocale"

    @Published private(set) var code: String
    private let catalog: [String: [String: String]]

    init() {
        catalog = Self.loadCatalog()
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: Self.localeKey), stored == "en" || stored == "es" {
            code = stored
        } else {
            // First launch: resolve macOS's preferred language once, then freeze it.
            let preferred = Locale.preferredLanguages.first
                ?? Locale.current.language.languageCode?.identifier
                ?? "en"
            code = preferred.hasPrefix("es") ? "es" : "en"
            defaults.set(code, forKey: Self.localeKey)
        }
    }

    /// Switches the UI language and persists it; the dropdown only path in.
    func setLocale(_ newCode: String) {
        guard newCode != code, newCode == "en" || newCode == "es" else { return }
        code = newCode
        UserDefaults.standard.set(newCode, forKey: Self.localeKey)
    }

    func t(_ key: String) -> String {
        catalog[code]?[key] ?? catalog["en"]?[key] ?? key
    }

    /// Catalog value with `String(format:)` placeholders (`%@`, `%d`) filled in.
    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }

    /// Short weekday name from `weekday.<jsonKey>`, not `DateFormatter` locale data.
    func weekday(_ weekday: Weekday) -> String {
        t("weekday.\(weekday.jsonKey)")
    }

    private static func loadCatalog() -> [String: [String: String]] {
        guard let url = Bundle.module.url(forResource: "Localization", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else {
            assertionFailure("Localization.json missing or malformed")
            return [:]
        }
        return decoded
    }
}
