import Foundation

public final class SharedDefaults: Sendable {
    private static let suiteName = "group.com.twmissingu.LLMQuotaIsland"
    private static let quotaKey = "cachedQuotas"
    private static let settingsKey = "appSettings"
    private static let enrolledKey = "enrolledProviders"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Quota Cache

    public static func saveQuotas(_ quotas: [QuotaInfo]) {
        guard let defaults, let data = try? JSONEncoder().encode(quotas) else { return }
        defaults.set(data, forKey: quotaKey)
    }

    public static func loadQuotas() -> [QuotaInfo] {
        guard let defaults, let data = defaults.data(forKey: quotaKey),
              let quotas = try? JSONDecoder().decode([QuotaInfo].self, from: data)
        else { return [] }
        return quotas
    }

    // MARK: - Settings

    public static func saveSettings(_ settings: AppSettings) {
        guard let defaults, let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }

    public static func loadSettings() -> AppSettings {
        guard let defaults, let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .default }
        return settings
    }

    // MARK: - Enrolled Providers

    public static func saveEnrolled(_ types: Set<ProviderType>) {
        guard let defaults, let data = try? JSONEncoder().encode(types) else { return }
        defaults.set(data, forKey: enrolledKey)
    }

    public static func loadEnrolled() -> Set<ProviderType> {
        guard let defaults, let data = defaults.data(forKey: enrolledKey),
              let types = try? JSONDecoder().decode(Set<ProviderType>.self, from: data)
        else { return [] }
        return types
    }
}
