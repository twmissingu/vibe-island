import Foundation

public enum AppTheme: String, Codable, Sendable, CaseIterable {
    case pixel
    case glass

    public var displayName: String {
        switch self {
        case .pixel: "像素复古"
        case .glass: "毛玻璃现代"
        }
    }
}

public enum IslandPositionMode: String, Codable, Sendable {
    case attached
    case detached
}

public struct AppSettings: Codable, Sendable {
    public var theme: AppTheme
    public var petEnabled: Bool
    public var selectedPetID: String
    public var pollingIntervalMinutes: Int
    public var launchAtLogin: Bool
    public var islandPositionMode: IslandPositionMode
    public var detachedPositionX: Double?
    public var detachedPositionY: Double?

    public init(
        theme: AppTheme = .glass,
        petEnabled: Bool = true,
        selectedPetID: String = "cat",
        pollingIntervalMinutes: Int = 5,
        launchAtLogin: Bool = false,
        islandPositionMode: IslandPositionMode = .attached,
        detachedPositionX: Double? = nil,
        detachedPositionY: Double? = nil
    ) {
        self.theme = theme
        self.petEnabled = petEnabled
        self.selectedPetID = selectedPetID
        self.pollingIntervalMinutes = min(max(pollingIntervalMinutes, 1), 60)
        self.launchAtLogin = launchAtLogin
        self.islandPositionMode = islandPositionMode
        self.detachedPositionX = detachedPositionX
        self.detachedPositionY = detachedPositionY
    }

    public static let `default` = AppSettings()
}
