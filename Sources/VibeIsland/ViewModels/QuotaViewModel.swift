import Foundation
import SwiftUI
import OSLog

@MainActor
@Observable
final class StateManager {
    var settings: AppSettings
    var islandState: IslandState = .compact

    // MARK: - 新服务集成

    let sessionWatcher = SessionFileWatcher.shared
    let soundManager = SoundManager.shared
    let hookInstaller = HookAutoInstaller.shared
    let processDetector = ProcessDetector.shared
    let contextMonitor = ContextMonitor.shared

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "StateManager"
    )

    init() {
        self.settings = SharedDefaults.loadSettings()
    }

    // MARK: - 生命周期

    func startMonitoring() {
        // 设置 SessionManager 的 StateManager 引用（用于持久化跟踪模式）
        SessionManager.shared.viewModel = self

        // 启动 SessionManager（Claude Code 会话监控）
        SessionManager.shared.start()

        // 启动 OpenCode 监控（会话自动注册到 SessionManager）
        OpenCodeMonitor.shared.start()

        // 启动会话文件监听
        sessionWatcher.startWatching()

        // 启动上下文监控
        contextMonitor.start()

        // 启动状态变化监听
        startStateObservation()

        Self.logger.info("StateManager 已启动所有监控服务")
    }

    func stopMonitoring() {
        // 停止 OpenCode 监控
        OpenCodeMonitor.shared.stop()

        // 停止 SessionManager
        SessionManager.shared.stop()

        // 停止状态观察
        SessionManager.shared.onAggregateStateChanged = nil

        // 停止上下文监控
        contextMonitor.stop()

        // 停止会话监听
        sessionWatcher.stopWatching()

        Self.logger.info("StateManager 已停止所有监控服务")
    }

    // MARK: - 状态变化监听

    private func startStateObservation() {
        // 通过 SessionManager 回调响应聚合状态变化（替代 200ms 轮询）
        // Task 包装是必要的：handleStateChange 内部 await soundManager.play
        SessionManager.shared.onAggregateStateChanged = { [weak self] oldState, newState in
            Task { [weak self] in
                await self?.handleStateChange(from: oldState, to: newState)
            }
        }
    }

    private func handleStateChange(from oldState: SessionState, to newState: SessionState) async {
        switch newState {
        case .idle:
            _ = await soundManager.play(.idle)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)")
        case .thinking:
            _ = await soundManager.play(.thinking)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)")
        case .coding:
            _ = await soundManager.play(.coding)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)")
        case .waiting:
            _ = await soundManager.play(.waiting)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)")
        case .waitingPermission:
            _ = await soundManager.play(.permissionRequest)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)，播放权限提示音")
        case .completed:
            _ = await soundManager.play(.completed)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)，播放完成提示音")
        case .error:
            _ = await soundManager.play(.error)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)，播放错误提示音")
        case .compacting:
            _ = await soundManager.play(.compacting)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)，播放压缩提示音")
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
        if OpenCodeMonitor.shared.isPluginAvailable && !OpenCodeMonitor.shared.sessions.isEmpty {
            return true
        }
        return isOpenCodeProcessRunning()
    }

    /// 检测 OpenCode 进程是否运行（兜底方案）
    private func isOpenCodeProcessRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "opencode"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 检查 OpenCode 插件是否可用（目录存在）
    func isOpenCodePluginAvailable() -> Bool {
        OpenCodeMonitor.shared.isPluginAvailable
    }
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

    // MARK: - Toggle State

    func toggleIslandState() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            islandState = islandState == .compact ? .expanded : .compact
        }
        // 通知 panel 更新大小
        let isExpanded = islandState == .expanded
        NotificationCenter.default.post(
            name: .islandStateDidChange,
            object: nil,
            userInfo: ["isExpanded": isExpanded]
        )
    }
}
