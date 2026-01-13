import Foundation

struct AppSettings: Codable {
    var enabled: Bool
    var translateToEnglish: Bool
    var skipCode: Bool
    var presentationMode: Bool
    var filterAppsEnabled: Bool

    private static let suiteName = "com.yourcompany.FixMeGrammar"
    private static let defaultsInstance: UserDefaults = {
        if let ud = UserDefaults(suiteName: suiteName) {
            return ud
        }
        return .standard
    }()

    static var shared: AppSettings = AppSettings(enabled: true, translateToEnglish: true, skipCode: true, presentationMode: false, filterAppsEnabled: true)

    static func load() -> AppSettings {
        print("[AppSettings] load start")
        let defaults = defaultsInstance
        if let data = defaults.data(forKey: "AppSettings") {
            print("[AppSettings] found saved data: \(data.count) bytes")
            if let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
                print("[AppSettings] decoded settings")
                shared = settings
                return settings
            } else {
                print("[AppSettings] failed to decode settings, using defaults")
            }
        } else {
            print("[AppSettings] no saved data, using defaults")
        }
        let initial = AppSettings(enabled: true, translateToEnglish: true, skipCode: true, presentationMode: false, filterAppsEnabled: true)
        shared = initial
        return initial
    }

    static func save() {
        let defaults = defaultsInstance
        if let data = try? JSONEncoder().encode(shared) {
            defaults.set(data, forKey: "AppSettings")
        }
    }
}
