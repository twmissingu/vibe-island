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
    public var petScaleFactor: Double
    public var pollingIntervalMinutes: Int
    public var launchAtLogin: Bool
    public var islandPositionMode: IslandPositionMode
    public var detachedPositionX: Double?
    public var detachedPositionY: Double?

    // 多工具监控
    public var claudeMonitorEnabled: Bool
    public var openCodeMonitorEnabled: Bool


    // 上下文感知
    public var contextMonitorEnabled: Bool
    public var contextWarningThreshold: Double

    // 会话跟踪模式
    public var sessionTrackingMode: String  // "auto" 或 "manual"
    public var pinnedSessionId: String?

    public init(
        theme: AppTheme = .glass,
        petEnabled: Bool = true,
        selectedPetID: String = "cat",
        petScaleFactor: Double = 1.0,
        pollingIntervalMinutes: Int = 5,
        launchAtLogin: Bool = false,
        islandPositionMode: IslandPositionMode = .attached,
        detachedPositionX: Double? = nil,
        detachedPositionY: Double? = nil,
        claudeMonitorEnabled: Bool = true,
        openCodeMonitorEnabled: Bool = true,
        contextMonitorEnabled: Bool = true,
        contextWarningThreshold: Double = 80.0,
        sessionTrackingMode: String = "auto",
        pinnedSessionId: String? = nil
    ) {
        self.theme = theme
        self.petEnabled = petEnabled
        self.selectedPetID = selectedPetID
        self.petScaleFactor = petScaleFactor
        self.pollingIntervalMinutes = min(max(pollingIntervalMinutes, 1), 60)
        self.launchAtLogin = launchAtLogin
        self.islandPositionMode = islandPositionMode
        self.detachedPositionX = detachedPositionX
        self.detachedPositionY = detachedPositionY
        self.claudeMonitorEnabled = claudeMonitorEnabled
        self.openCodeMonitorEnabled = openCodeMonitorEnabled

        self.contextMonitorEnabled = contextMonitorEnabled
        self.contextWarningThreshold = contextWarningThreshold
        self.sessionTrackingMode = sessionTrackingMode
        self.pinnedSessionId = pinnedSessionId
    }

    public static let `default` = AppSettings()
}
