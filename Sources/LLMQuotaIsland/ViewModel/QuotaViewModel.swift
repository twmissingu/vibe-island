import Foundation
import SwiftUI
import LLMQuotaKit

@MainActor
@Observable
final class QuotaViewModel {
    var quotas: [QuotaInfo] = []
    var settings: AppSettings
    var islandState: IslandState = .compact
    var isLoading: Bool = false
    var lastRefresh: Date?

    let keychain = KeychainStorage()
    let network = NetworkClient()

    private var pollingTask: Task<Void, Never>?

    init() {
        self.settings = SharedDefaults.loadSettings()
        self.quotas = SharedDefaults.loadQuotas()
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        var results: [QuotaInfo] = []
        let enrolled = SharedDefaults.loadEnrolled()

        for providerType in ProviderType.allCases {
            guard enrolled.contains(providerType) else { continue }
            do {
                let key = try keychain.load(for: providerType.rawValue)
                let provider = makeProvider(for: providerType)
                let info = try await provider.fetchQuota(key: key, baseURL: nil)
                results.append(info)
            } catch let error as QuotaError {
                results.append(QuotaInfo(
                    provider: providerType,
                    keyIdentifier: "***",
                    totalQuota: nil,
                    usedQuota: nil,
                    remainingQuota: nil,
                    unit: .yuan,
                    usageRatio: 0,
                    error: error
                ))
            } catch {
                results.append(QuotaInfo(
                    provider: providerType,
                    keyIdentifier: "***",
                    totalQuota: nil,
                    usedQuota: nil,
                    remainingQuota: nil,
                    unit: .yuan,
                    usageRatio: 0,
                    error: .unknown(error.localizedDescription)
                ))
            }
        }

        quotas = results
        lastRefresh = .now
        SharedDefaults.saveQuotas(results)
    }

    // MARK: - Polling

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(settings.pollingIntervalMinutes * 60))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Toggle State

    func toggleIslandState() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            islandState = islandState == .compact ? .expanded : .compact
        }
    }

    // MARK: - Provider Factory

    private func makeProvider(for type: ProviderType) -> any QuotaProvider {
        // TODO: Phase 2 - 返回真实 Provider
        // PlaceholderProvider for Demo mode
        PlaceholderProvider(type: type)
    }
}

// MARK: - PlaceholderProvider (Demo)

private struct PlaceholderProvider: QuotaProvider {
    let type: ProviderType
    var displayName: String { type.displayName }
    var iconName: String { type.iconName }
    var defaultBaseURL: String { "https://api.example.com" }
    var quotaUnit: QuotaUnit { .yuan }

    func validateKey(_ key: String, baseURL: String?) async throws -> Bool { true }
    func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo {
        try await Task.sleep(for: .milliseconds(500))
        let ratio = Double.random(in: 0.1...0.9)
        return QuotaInfo(
            provider: type,
            keyIdentifier: NetworkClient.maskKey(key),
            totalQuota: 500,
            usedQuota: 500 * ratio,
            remainingQuota: 500 * (1 - ratio),
            unit: .yuan,
            usageRatio: ratio
        )
    }
}
