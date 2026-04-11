import Foundation

/// 小米 MIMO Provider
/// Base URL: https://token-plan-cn.xiaomimimo.com/v1
/// MIMO 使用 Token Plan 订阅制，无公开余额查询 API
/// 通过 /v1/models 验证 Key 有效性
/// 余额需在控制台查看：https://platform.xiaomimimo.com/#/console/plan-manage
public struct MiMoProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .mimo
    public let displayName = "小米 MIMO"
    public let iconName = "logo-mimo"
    public let defaultBaseURL = "https://token-plan-cn.xiaomimimo.com/v1"
    public let quotaUnit: QuotaUnit = .tokens

    private let network = NetworkClient()

    public init() {}

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        let url = (baseURL ?? defaultBaseURL) + "/models"
        let (_, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        return response.statusCode == 200
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        let base = baseURL ?? defaultBaseURL

        // 验证 Key 有效
        let url = base + "/models"
        let (data, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )

        guard response.statusCode == 200 else {
            throw network.errorFromResponse(statusCode: response.statusCode, data: data)
        }

        // MIMO Token Plan 订阅制无公开余额 API
        // 返回 Key 有效状态，余额需在控制台查看
        return QuotaInfo(
            provider: .mimo,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: nil,
            usedQuota: nil,
            remainingQuota: nil,
            unit: .tokens,
            usageRatio: 0,
            error: .unknown("MIMO Token Plan 订阅制，请在控制台查看用量: platform.xiaomimimo.com")
        )
    }
}
