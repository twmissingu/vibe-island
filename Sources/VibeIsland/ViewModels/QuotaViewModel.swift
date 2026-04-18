import Foundation
import SwiftUI
import LLMQuotaKit
import OSLog

@MainActor
@Observable
final class StateManager {
    // MARK: - 额度相关属性（保持不变）

    var quotas: [QuotaInfo] = []
    var settings: AppSettings
    var islandState: IslandState = .compact
    var isLoading: Bool = false
    var lastRefresh: Date?

    let keychain = KeychainStorage()
    let network = NetworkClient()

    private var pollingTask: Task<Void, Never>?

    // MARK: - 新服务集成

    let sessionWatcher = SessionFileWatcher.shared
    let soundManager = SoundManager.shared
    let hookInstaller = HookAutoInstaller.shared
    let processDetector = ProcessDetector.shared
    let contextMonitor = ContextMonitor.shared

    private var stateObservationTask: Task<Void, Never>?
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twissingu.VibeIsland",
        category: "StateManager"
    )

    init() {
        self.settings = SharedDefaults.loadSettings()
        self.quotas = SharedDefaults.loadQuotas()
    }

    // MARK: - 生命周期

    func startMonitoring() {
        // 设置 SessionManager 的 StateManager 引用（用于持久化跟踪模式）
        SessionManager.shared.viewModel = self

        // 启动多工具聚合器（包含 Claude Code、OpenCode）
        MultiToolAggregator.shared.start()

        // 启动额度轮询
        startPolling()

        // 启动会话文件监听
        sessionWatcher.startWatching()

        // 启动上下文监控
        contextMonitor.start()

        // 启动状态变化监听
        startStateObservation()

        Self.logger.info("StateManager 已启动所有监控服务")
    }

    func stopMonitoring() {
        // 停止多工具聚合器
        MultiToolAggregator.shared.stop()

        // 停止状态观察
        stateObservationTask?.cancel()
        stateObservationTask = nil

        // 停止上下文监控
        contextMonitor.stop()

        // 停止会话监听
        sessionWatcher.stopWatching()

        // 停止额度轮询
        stopPolling()

        Self.logger.info("StateManager 已停止所有监控服务")
    }

    // MARK: - 状态变化监听

    private func startStateObservation() {
        stateObservationTask?.cancel()
        stateObservationTask = Task { [weak self] in
            guard let self else { return }
            var lastState: SessionState = .idle

            while !Task.isCancelled {
                let currentState = sessionWatcher.aggregateState

                if currentState != lastState {
                    await handleStateChange(from: lastState, to: currentState)
                    lastState = currentState
                }

                // 处理所有活跃会话的上下文监控
                for session in sessionWatcher.sessions.values {
                    contextMonitor.handleSessionUpdate(session)
                }

                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func handleStateChange(from oldState: SessionState, to newState: SessionState) async {
        switch newState {
        case .waitingPermission:
            _ = await soundManager.play(.permissionRequest)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue), 播放权限提示音")

        case .error:
            _ = await soundManager.play(.error)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue), 播放错误提示音")

        case .completed:
            _ = await soundManager.play(.completed)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue), 播放完成提示音")

        case .compacting:
            _ = await soundManager.play(.compacting)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue), 播放压缩提示音")

        default:
            break
        }
    }

    // MARK: - Hook 管理方法

    /// 安装 hooks（返回 Result，调用方自行处理 UI 反馈）
    func installHooks() async -> Result<String, Error> {
        let result = await hookInstaller.install()
        switch result {
        case .success(let backupPath):
            let msg = String(format: NSLocalizedString("hook.install.success.message", value: "Hooks 安装成功，备份: %@", comment: ""), backupPath)
            return .success(msg)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// 卸载 hooks（返回 Result，调用方自行处理 UI 反馈）
    func uninstallHooks() async -> Result<String, Error> {
        let result = await hookInstaller.uninstall()
        switch result {
        case .success(let backupPath):
            let msg = String(format: NSLocalizedString("hook.uninstall.success.message", value: "Hooks 卸载成功，备份: %@", comment: ""), backupPath)
            return .success(msg)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// 安装 hooks 并自动显示用户反馈（自动处理成功/失败提示）
    func installHooksWithFeedback() async {
        await hookInstaller.installWithFeedback()
    }

    /// 卸载 hooks 并自动显示用户反馈（自动处理成功/失败提示）
    func uninstallHooksWithFeedback() async {
        await hookInstaller.uninstallWithFeedback()
    }

    func isClaudeCodeRunning() -> Bool {
        !processDetector.detectClaudeCodeProcesses().isEmpty
    }

    func isOpenCodeRunning() -> Bool {
        OpenCodeMonitor.shared.isOpenCodeRunning()
    }

    /// 检查 OpenCode 插件是否已安装
    func isOpenCodePluginInstalled() -> Bool {
        hookInstaller.isOpenCodePluginInstalled
    }

    /// 检查 OpenCode 是否已安装
    func isOpenCodeInstalled() -> Bool {
        hookInstaller.isOpenCodeInstalled
    }

    /// 安装 OpenCode 插件
    func installOpenCodePlugin() async -> Result<String, Error> {
        let result = await hookInstaller.installOpenCodePlugin()
        switch result {
        case .success(let backupPath):
            let msg = backupPath.map { "插件安装成功，备份: \($0)" } ?? "插件安装成功"
            return .success(msg)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// 卸载 OpenCode 插件
    func uninstallOpenCodePlugin() async -> Result<String, Error> {
        let result = await hookInstaller.uninstallOpenCodePlugin()
        switch result {
        case .success(let backupPath):
            let msg = backupPath.map { "插件卸载成功，备份: \($0)" } ?? "插件卸载成功"
            return .success(msg)
        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Refresh（额度刷新，保持不变）

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        var results: [QuotaInfo] = []
        var failedProviders: [(ProviderType, Error)] = []
        let enrolled = SharedDefaults.loadEnrolled()

        for providerType in ProviderType.allCases {
            guard enrolled.contains(providerType) else { continue }
            do {
                let key = try keychain.load(for: providerType.rawValue)
                let provider = makeProvider(for: providerType)
                let info = try await provider.fetchQuota(key: key, baseURL: nil)
                results.append(info)
            } catch let error as QuotaError {
                failedProviders.append((providerType, error))
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
                failedProviders.append((providerType, error))
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
        lastRefresh = Date.now
        SharedDefaults.saveQuotas(results)

        // 如果有失败的 provider 且全部失败，显示错误提示
        if !failedProviders.isEmpty && failedProviders.count == enrolled.count {
            let firstError = failedProviders.first?.1 ?? NSError(domain: "unknown", code: -1)
            ErrorPresenter.presentAsync(
                firstError,
                title: NSLocalizedString("quota.refresh.failed.title", value: "额度刷新失败", comment: ""),
                level: .warning
            )
        } else if !failedProviders.isEmpty {
            // 部分失败时记录日志，不在每次刷新时弹出提示（避免打扰）
            for (provider, error) in failedProviders {
                Self.logger.warning("额度刷新失败 - \(provider.rawValue): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Polling（额度轮询，保持不变）

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
        switch type {
        case .mimo: MiMoProvider()
        case .kimi: KimiProvider()
        case .minimax: MiniMaxProvider()
        case .zai: ZaiProvider()
        case .ark: ArkProvider()
        }
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
