import Foundation

/// 火山方舟 (Volcengine Ark) Provider
/// Base URL: https://ark.cn-beijing.volces.com
/// Ark API Key 验证: GET /api/v3/models
/// 火山方舟计费通过火山云控制台管理，Ark API 无公开余额接口
/// 控制台: https://console.volcengine.com/ark
public struct ArkProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .ark
    public let displayName = "火山方舟"
    public let iconName = "logo-ark"
    public let defaultBaseURL = "https://ark.cn-beijing.volces.com"
    public let quotaUnit: QuotaUnit = .tokens

    private let network = NetworkClient()

    public init() {}

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        let url = (baseURL ?? defaultBaseURL) + "/api/v3/models"
        let (_, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        return response.statusCode == 200
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        let url = (baseURL ?? defaultBaseURL) + "/api/v3/models"
        let (data, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )

        guard response.statusCode == 200 else {
            throw network.errorFromResponse(statusCode: response.statusCode, data: data)
        }

        // 火山方舟计费通过火山云控制台管理，Ark API 无公开余额接口
        return QuotaInfo(
            provider: .ark,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: nil,
            usedQuota: nil,
            remainingQuota: nil,
            unit: .tokens,
            usageRatio: 0,
            error: .unknown("火山方舟计费在火山云控制台管理: console.volcengine.com/ark")
        )
    }
}
