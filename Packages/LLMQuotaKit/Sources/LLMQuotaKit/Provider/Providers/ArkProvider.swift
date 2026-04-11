import Foundation

/// 火山方舟 (Volcengine Ark) Provider
/// API: 需要火山云 API v4 签名认证
/// 基于 OpenAI 兼容接口，余额通过火山云控制台 API 获取
/// 备选方案：通过 Ark 模型列表接口探测可用额度
public struct ArkProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .ark
    public let displayName = "火山方舟"
    public let iconName = "logo-ark"
    public let defaultBaseURL = "https://ark.cn-beijing.volces.com"
    public let quotaUnit: QuotaUnit = .tokens

    private let network = NetworkClient()

    public init() {}

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        // 使用 OpenAI 兼容接口测试 Key 有效性
        let url = (baseURL ?? defaultBaseURL) + "/api/v3/models"
        let (_, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        return response.statusCode == 200
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        // 火山方舟 OpenAI 兼容接口不直接暴露余额
        // 通过调用 models 接口确认 Key 有效，余额信息需从火山云控制台获取
        // 此处返回 Key 有效但余额未知的状态
        let url = (baseURL ?? defaultBaseURL) + "/api/v3/models"
        let (data, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )

        guard response.statusCode == 200 else {
            throw network.errorFromResponse(statusCode: response.statusCode, data: data)
        }

        // 火山方舟余额需通过火山云 API 获取，此处返回未知状态
        // 用户可在设置中查看火山云控制台获取详细余额
        return QuotaInfo(
            provider: .ark,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: nil,
            usedQuota: nil,
            remainingQuota: nil,
            unit: .tokens,
            usageRatio: 0,
            error: .unknown("火山方舟余额需通过火山云控制台查看")
        )
    }
}
