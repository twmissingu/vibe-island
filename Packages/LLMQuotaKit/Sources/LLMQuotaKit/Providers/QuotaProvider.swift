import Foundation

public protocol QuotaProvider: Sendable {
    var type: ProviderType { get }
    var displayName: String { get }
    var iconName: String { get }
    var defaultBaseURL: String { get }
    var quotaUnit: QuotaUnit { get }

    func validateKey(_ key: String, baseURL: String?) async throws -> Bool
    func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo
}
