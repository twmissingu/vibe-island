import Foundation

/// 智谱 Z.AI (BigModel) Provider
/// API: GET https://open.bigmodel.cn/api/paas/v4/users/balance
/// Header: Authorization: Bearer {api_key}
public struct ZaiProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .zai
    public let displayName = "智谱 Z.AI"
    public let iconName = "logo-zai"
    public let defaultBaseURL = "https://open.bigmodel.cn"
    public let quotaUnit: QuotaUnit = .yuan

    private let network = NetworkClient()

    public init() {}

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        let url = (baseURL ?? defaultBaseURL) + "/api/paas/v4/users/balance"
        let (_, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        return response.statusCode == 200
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        let url = (baseURL ?? defaultBaseURL) + "/api/paas/v4/users/balance"
        let (data, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )

        guard response.statusCode == 200 else {
            throw network.errorFromResponse(statusCode: response.statusCode, data: data)
        }

        let balance = try network.decodeJSON(BalanceResponse.self, from: data)
        let total = balance.data.totalBalance
        let used = balance.data.totalUsed ?? 0
        let remaining = total - used
        let ratio = total > 0 ? used / total : 0

        return QuotaInfo(
            provider: .zai,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: total,
            usedQuota: used,
            remainingQuota: remaining,
            unit: .yuan,
            usageRatio: ratio
        )
    }

    private struct BalanceResponse: Decodable {
        let data: BalanceData
        struct BalanceData: Decodable {
            let totalBalance: Double
            let totalUsed: Double?
        }
    }
}
