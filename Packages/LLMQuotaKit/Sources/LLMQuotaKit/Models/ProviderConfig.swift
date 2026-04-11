import Foundation

public struct ProviderConfig: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: ProviderType
    public var name: String
    public var apiKeyRef: String
    public var baseURL: String?
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        type: ProviderType,
        name: String? = nil,
        apiKeyRef: String,
        baseURL: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.name = name ?? type.displayName
        self.apiKeyRef = apiKeyRef
        self.baseURL = baseURL
        self.enabled = enabled
    }
}
