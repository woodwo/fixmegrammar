import Foundation

struct AppSettings: Codable {
    var enabled: Bool
    var translateToEnglish: Bool
    var skipCode: Bool

    static var shared: AppSettings = AppSettings.load()

    static func load() -> AppSettings {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "AppSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            shared = settings
            return settings
        }
        let initial = AppSettings(enabled: true, translateToEnglish: true, skipCode: true)
        shared = initial
        return initial
    }

    static func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(shared) {
            defaults.set(data, forKey: "AppSettings")
        }
    }
}
