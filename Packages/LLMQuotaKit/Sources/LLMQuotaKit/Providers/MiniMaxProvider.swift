import Foundation

/// MiniMax Provider
/// Base URL: https://api.minimaxi.com/v1 (OpenAI 兼容)
/// Token Plan 订阅制，按请求/5小时滚动重置，无公开余额 API
/// 控制台: https://platform.minimaxi.com/user-center/basic-information
public struct MiniMaxProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .minimax
    public let displayName = "MiniMax"
    public let iconName = "logo-minimax"
    public let defaultBaseURL = "https://api.minimaxi.com/v1"
    public let quotaUnit: QuotaUnit = .requests

    private let network = NetworkClient()

    public init() {}

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        // 通过轻量请求验证 Key：发送一个极小的 chat 请求
        // 余额不足时返回 429，但说明 Key 有效
        let url = (baseURL ?? defaultBaseURL) + "/chat/completions"
        let body = """
        {"model":"MiniMax-M2.5","messages":[{"role":"user","content":"."}],"max_tokens":1}
        """
        let (_, response) = try await network.request(
            url: url,
            method: "POST",
            headers: ["Authorization": "Bearer \(key)"],
            body: Data(body.utf8)
        )
        // 200=正常, 429=余额不足但Key有效, 401=Key无效
        return response.statusCode != 401
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        // 验证 Key 有效
        let url = (baseURL ?? defaultBaseURL) + "/chat/completions"
        let body = """
        {"model":"MiniMax-M2.5","messages":[{"role":"user","content":"."}],"max_tokens":1}
        """
        let (_, response) = try await network.request(
            url: url,
            method: "POST",
            headers: ["Authorization": "Bearer \(key)"],
            body: Data(body.utf8)
        )

        // 401 = Key 无效
        if response.statusCode == 401 {
            throw QuotaError.invalidKey
        }

        // 429 = 余额不足但 Key 有效
        if response.statusCode == 429 {
            return QuotaInfo(
                provider: .minimax,
                keyIdentifier: NetworkClient.maskKey(key),
                totalQuota: nil,
                usedQuota: nil,
                remainingQuota: 0,
                unit: .requests,
                usageRatio: 1.0,
                error: .unknown("MiniMax 余额不足，请在控制台查看: platform.minimaxi.com")
            )
        }

        // 200 = Key 有效且有余额，但无法获取具体剩余额度
        return QuotaInfo(
            provider: .minimax,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: nil,
            usedQuota: nil,
            remainingQuota: nil,
            unit: .requests,
            usageRatio: 0,
            error: .unknown("MiniMax Token Plan 订阅制，额度在控制台查看: platform.minimaxi.com")
        )
    }
}
