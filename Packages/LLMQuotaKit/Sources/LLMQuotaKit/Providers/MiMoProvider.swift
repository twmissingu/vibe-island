import Foundation

/// 小米 MIMO Provider
/// 两种 Key 类型，自动识别：
/// - tp- 前缀: Token Plan，Base URL: token-plan-cn.xiaomimimo.com/v1
/// - sk- 前缀: 标准 API，Base URL: api.xiaomimimo.com/v1
/// 无公开余额查询 API，余额需在控制台查看
public struct MiMoProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .mimo
    public let displayName = "小米 MIMO"
    public let iconName = "logo-mimo"
    public let defaultBaseURL = "https://api.xiaomimimo.com/v1"
    public let quotaUnit: QuotaUnit = .tokens

    private let network = NetworkClient()

    public init() {}

    /// 根据 Key 前缀自动选择 Base URL
    private func resolveBaseURL(_ key: String, customBase: String?) -> String {
        if let custom = customBase { return custom }
        if key.hasPrefix("tp-") { return "https://token-plan-cn.xiaomimimo.com/v1" }
        return defaultBaseURL
    }

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        let base = resolveBaseURL(key, customBase: baseURL)
        let url = base + "/models"
        let (_, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        return response.statusCode == 200
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        let base = resolveBaseURL(key, customBase: baseURL)
        let url = base + "/models"
        let (data, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )

        guard response.statusCode == 200 else {
            throw network.errorFromResponse(statusCode: response.statusCode, data: data)
        }

        // MIMO 无公开余额 API，返回 Key 有效状态
        let planType = key.hasPrefix("tp-") ? "Token Plan" : "按量计费"
        return QuotaInfo(
            provider: .mimo,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: nil,
            usedQuota: nil,
            remainingQuota: nil,
            unit: .tokens,
            usageRatio: 0,
            error: .unknown("MIMO \(planType)，余额在控制台查看: platform.xiaomimimo.com")
        )
    }
}
