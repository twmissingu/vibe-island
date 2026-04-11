import Foundation

/// 小米 MIMO Provider
/// MIMO API 兼容 OpenAI 格式
/// 余额接口：尝试 OpenAI 标准 billing 接口
/// 需要用户用真实 Key 验证具体端点
public struct MiMoProvider: QuotaProvider, Sendable {
    public let type: ProviderType = .mimo
    public let displayName = "小米 MIMO"
    public let iconName = "logo-mimo"
    public let defaultBaseURL = "https://api.mimo.xiaomi.com"
    public let quotaUnit: QuotaUnit = .tokens

    private let network = NetworkClient()

    public init() {}

    public func validateKey(_ key: String, baseURL: String?) async throws -> Bool {
        // 尝试 OpenAI 兼容的 models 接口验证 Key
        let url = (baseURL ?? defaultBaseURL) + "/v1/models"
        let (_, response) = try await network.request(
            url: url,
            headers: ["Authorization": "Bearer \(key)"]
        )
        return response.statusCode == 200
    }

    public func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        let base = baseURL ?? defaultBaseURL

        // 尝试 OpenAI 兼容的 billing 接口
        let endpoints = [
            "/v1/dashboard/billing/subscription",
            "/v1/dashboard/billing/credit_grants",
        ]

        for endpoint in endpoints {
            let url = base + endpoint
            let (data, response) = try await network.request(
                url: url,
                headers: ["Authorization": "Bearer \(key)"]
            )

            if response.statusCode == 200 {
                return try parseBillingResponse(data: data, key: key)
            }
        }

        // 如果 billing 接口不可用，返回 Key 有效但余额未知
        return QuotaInfo(
            provider: .mimo,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: nil,
            usedQuota: nil,
            remainingQuota: nil,
            unit: .tokens,
            usageRatio: 0,
            error: .unknown("MIMO 余额接口待验证，请提供 Key 后确认")
        )
    }

    private func parseBillingResponse(data: Data, key: String) throws -> QuotaInfo {
        // 尝试解析 OpenAI 格式的 billing 响应
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // credit_grants 格式
            if let totalGranted = json["total_granted"] as? Double,
               let totalUsed = json["total_used"] as? Double {
                let remaining = totalGranted - totalUsed
                let ratio = totalGranted > 0 ? totalUsed / totalGranted : 0
                return QuotaInfo(
                    provider: .mimo,
                    keyIdentifier: NetworkClient.maskKey(key),
                    totalQuota: totalGranted,
                    usedQuota: totalUsed,
                    remainingQuota: remaining,
                    unit: .yuan,
                    usageRatio: ratio
                )
            }

            // subscription 格式
            if let hardLimit = json["hard_limit"] as? Double,
               let softLimit = json["soft_limit"] as? Double {
                let used = hardLimit - softLimit
                let ratio = hardLimit > 0 ? used / hardLimit : 0
                return QuotaInfo(
                    provider: .mimo,
                    keyIdentifier: NetworkClient.maskKey(key),
                    totalQuota: hardLimit,
                    usedQuota: used,
                    remainingQuota: softLimit,
                    unit: .yuan,
                    usageRatio: ratio
                )
            }
        }

        throw QuotaError.unknown("无法解析 MIMO 余额响应")
    }
}
