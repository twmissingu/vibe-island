import Foundation

/// Kimi (Moonshot) Provider
/// API: GET https://api.moonshot.cn/v1/users/me/balance
/// Header: Authorization: Bearer {api_key}
public struct KimiProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .kimi
    public let displayName = "Kimi"
    public let iconName = "logo-kimi"
    public let defaultBaseURL = "https://api.moonshot.cn"
    public let quotaUnit: QuotaUnit = .yuan

    private let network = NetworkClient()

    public init() {}

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        let url = (baseURL ?? defaultBaseURL) + "/v1/users/me/balance"
        let (_, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        return response.statusCode == 200
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        let url = (baseURL ?? defaultBaseURL) + "/v1/users/me/balance"
        let (data, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )

        guard response.statusCode == 200 else {
            throw network.errorFromResponse(statusCode: response.statusCode, data: data)
        }

        let balance = try network.decodeJSON(BalanceResponse.self, from: data)
        let total = balance.totalBalance
        let available = balance.availableBalance
        let used = total - available
        let ratio = total > 0 ? used / total : 0

        return QuotaInfo(
            provider: .kimi,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: total,
            usedQuota: used,
            remainingQuota: available,
            unit: .yuan,
            usageRatio: ratio
        )
    }

    private struct BalanceResponse: Decodable {
        let totalBalance: Double
        let availableBalance: Double

        enum CodingKeys: String, CodingKey {
            case totalBalance = "total_balance"
            case availableBalance = "available_balance"
        }
    }
}
