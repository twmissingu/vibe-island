import Foundation

// MARK: - ProviderType

public enum ProviderType: String, Codable, CaseIterable, Sendable {
    case mimo
    case kimi
    case minimax
    case zai
    case ark

    public var displayName: String {
        switch self {
        case .mimo: "小米 MIMO"
        case .kimi: "Kimi"
        case .minimax: "MiniMax"
        case .zai: "智谱 Z.AI"
        case .ark: "火山方舟"
        }
    }

    public var iconName: String {
        switch self {
        case .mimo: "logo-mimo"
        case .kimi: "logo-kimi"
        case .minimax: "logo-minimax"
        case .zai: "logo-zai"
        case .ark: "logo-ark"
        }
    }
}

// MARK: - QuotaUnit

public enum QuotaUnit: String, Codable, Sendable {
    case yuan
    case tokens
    case requests

    public var displaySuffix: String {
        switch self {
        case .yuan: "元"
        case .tokens: "tokens"
        case .requests: "次"
        }
    }
}

// MARK: - QuotaError

public enum QuotaError: Error, Codable, Sendable, Equatable {
    case invalidKey
    case networkError(String)
    case rateLimited(retryAfter: Int?)
    case unknown(String)

    public var displayMessage: String {
        switch self {
        case .invalidKey: "API Key 无效或过期"
        case .networkError(let msg): "网络错误: \(msg)"
        case .rateLimited(let retry): "请求频率超限" + (retry.map { "，\($0)秒后重试" } ?? "")
        case .unknown(let msg): msg
        }
    }
}

// MARK: - QuotaInfo

public struct QuotaInfo: Codable, Sendable, Identifiable {
    public let id: UUID
    public let provider: ProviderType
    public let keyIdentifier: String
    public let totalQuota: Double?
    public let usedQuota: Double?
    public let remainingQuota: Double?
    public let unit: QuotaUnit
    public let usageRatio: Double
    public let fetchedAt: Date
    public let error: QuotaError?
    public let nextResetAt: Date?

    public init(
        id: UUID = UUID(),
        provider: ProviderType,
        keyIdentifier: String,
        totalQuota: Double?,
        usedQuota: Double?,
        remainingQuota: Double?,
        unit: QuotaUnit,
        usageRatio: Double,
        fetchedAt: Date = .now,
        error: QuotaError? = nil,
        nextResetAt: Date? = nil
    ) {
        self.id = id
        self.provider = provider
        self.keyIdentifier = keyIdentifier
        self.totalQuota = totalQuota
        self.usedQuota = usedQuota
        self.remainingQuota = remainingQuota
        self.unit = unit
        self.usageRatio = min(max(usageRatio, 0), 1)
        self.fetchedAt = fetchedAt
        self.error = error
        self.nextResetAt = nextResetAt
    }

    // MARK: - Computed

    public var usedPercent: Int { Int(usageRatio * 100) }
    public var remainingPercent: Int { 100 - usedPercent }
    public var isLowQuota: Bool { usageRatio >= 0.8 }
    public var isCritical: Bool { usageRatio >= 0.95 }
    public var hasError: Bool { error != nil }
    public var isHealthy: Bool { error == nil }

    // MARK: - Formatting

    public var formattedRemaining: String {
        guard let remaining = remainingQuota else { return "—" }
        return formatValue(remaining, unit: unit)
    }

    public var formattedTotal: String {
        guard let total = totalQuota else { return "—" }
        return formatValue(total, unit: unit)
    }

    public var formattedUsed: String {
        guard let used = usedQuota else { return "—" }
        return formatValue(used, unit: unit)
    }

    private func formatValue(_ value: Double, unit: QuotaUnit) -> String {
        switch unit {
        case .yuan:
            if value >= 10000 { return String(format: "¥%.1fK", value / 1000) }
            return String(format: "¥%.0f", value)
        case .tokens:
            if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
            if value >= 1000 { return String(format: "%.1fK", value / 1000) }
            return "\(Int(value))"
        case .requests:
            return "\(Int(value))次"
        }
    }

    // MARK: - Placeholder

    public static func placeholder(for provider: ProviderType) -> QuotaInfo {
        QuotaInfo(
            provider: provider,
            keyIdentifier: "sk-demo***test",
            totalQuota: 500,
            usedQuota: 189,
            remainingQuota: 311,
            unit: .yuan,
            usageRatio: 0.378
        )
    }
}
