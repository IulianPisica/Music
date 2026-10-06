import Foundation

/// Reads the options chosen in the Settings screen (stored in UserDefaults via @AppStorage).
enum Settings {
    static func isEnabled(_ source: TrackSource) -> Bool {
        UserDefaults.standard.object(forKey: "enabled.\(source.rawValue)") as? Bool ?? true
    }

    /// Key typed in the app wins; otherwise the one baked in at build time (Secrets.swift).
    static var jamendoKey: String {
        let typed = (UserDefaults.standard.string(forKey: "jamendoKey") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        let baked = Secrets.jamendoClientID
        return baked == "YOUR_JAMENDO_CLIENT_ID" ? "" : baked
    }
}
