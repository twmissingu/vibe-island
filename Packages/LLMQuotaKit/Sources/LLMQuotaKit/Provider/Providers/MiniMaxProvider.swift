import Foundation

/// MiniMax Provider
/// API: GET https://api.minimax.chat/v1/users/self 或 POST /v1/group/get
/// Header: Authorization: Bearer {api_key}
public struct MiniMaxProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .minimax
    public let displayName = "MiniMax"
    public let iconName = "logo-minimax"
    public let defaultBaseURL = "https://api.minimax.chat"
    public let quotaUnit: QuotaUnit = .tokens

    private let network = NetworkClient()

    public init() {}

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        let url = (baseURL ?? defaultBaseURL) + "/v1/users/self"
        let (_, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        return response.statusCode == 200
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        let url = (baseURL ?? defaultBaseURL) + "/v1/users/self"
        let (data, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )

        guard response.statusCode == 200 else {
            throw network.errorFromResponse(statusCode: response.statusCode, data: data)
        }

        let user = try network.decodeJSON(UserResponse.self, from: data)
        let total = user.subsidyBalance ?? user.totalBalance
        let used = user.totalUsed ?? 0
        let ratio = total > 0 ? used / total : 0

        return QuotaInfo(
            provider: .minimax,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: total,
            usedQuota: used,
            remainingQuota: total - used,
            unit: .tokens,
            usageRatio: ratio
        )
    }

    private struct UserResponse: Decodable {
        let totalBalance: Double?
        let subsidyBalance: Double?
        let totalUsed: Double?

        enum CodingKeys: String, CodingKey {
            case totalBalance = "total_balance"
            case subsidyBalance = "subsidy_balance"
            case totalUsed = "total_used"
        }
    }
}
