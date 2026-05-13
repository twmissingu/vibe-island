import Foundation
import SwiftUI
import OSLog

// MARK: - 设置状态

/// 引导设置状态机
enum SetupState: String, Codable, Sendable {
    /// 首次启动 — 无任何 AI 工具检测到
    case notStarted
    /// 检测到 Claude Code 在运行但未安装 hook
    case claudeDetected
    /// 检测到 OpenCode 项目但未安装插件
    case opencodeDetected
    /// 全部配置完成
    case completed
}

@MainActor
@Observable
final class StateManager {
    var settings: AppSettings
    var islandState: IslandState = .compact

    // MARK: - 新服务集成

    let soundManager = SoundManager.shared
    let hookInstaller = HookAutoInstaller.shared
    let processDetector = ProcessDetector.shared
    let contextMonitor = ContextMonitor.shared

    /// 宠物解锁通知（由 PetUnlockNotificationManager 回调设置）
    var petNotification: PetUnlockNotification?

    /// 当前引导设置状态
    var setupState: SetupState = .completed

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

        // 启动上下文监控
        contextMonitor.start()

        // 启动状态变化监听
        startStateObservation()

        // 评估引导状态
        evaluateSetupState()

        // 订阅宠物解锁通知（替换 SettingsView 中的订阅）
        PetUnlockNotificationManager.shared.onNewNotification = { [weak self] notification in
            Task { @MainActor in
                self?.petNotification = notification
                self?.handlePetNotification(notification)
            }
        }

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

        Self.logger.info("StateManager 已停止所有监控服务")
    }

    /// 评估当前设置状态（应在 startMonitoring 和工具检测后调用）
    func evaluateSetupState() {
        let hasClaude = isClaudeCodeRunning()
        let hasOpenCode = isOpenCodeInstalled()
        let claudeHookInstalled = hookInstaller.isHookInstalled
        let opencodePluginInstalled = isOpenCodePluginInstalled()

        // 优先检查 hook/plugin 安装状态：已配置 = completed
        if claudeHookInstalled || opencodePluginInstalled {
            setupState = .completed
        } else if hasClaude && !claudeHookInstalled {
            setupState = .claudeDetected
        } else if hasOpenCode && !opencodePluginInstalled {
            setupState = .opencodeDetected
        } else if hasClaude || hasOpenCode {
            // 工具有在运行但状态未匹配到上述分支（理论不应到达）
            setupState = .notStarted
        } else {
            setupState = .notStarted
        }
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
        case .waitingPermission:
            _ = await soundManager.play(.permissionRequest, force: true)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)，播放权限提示音")
        case .error:
            _ = await soundManager.play(.error, force: true)
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)，播放错误提示音")
        default:
            Self.logger.debug("状态变化: \(oldState.rawValue) → \(newState.rawValue)")
        }
    }

    // MARK: - 宠物通知处理

    private func handlePetNotification(_ notification: PetUnlockNotification) {
        // 打印日志 — 后续可扩展为岛内动画或声音
        Self.logger.info("🎉 宠物通知: \(notification.type.rawValue) - \(notification.pet.displayName)")
        // 3秒后自动清除
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if self.petNotification?.id == notification.id {
                self.petNotification = nil
            }
        }
    }

    // MARK: - Hook 管理方法

    /// 安装 hooks（返回 Result，调用方自行处理 UI 反馈）
    func installHooks() async -> Result<String, Error> {
        let result = await hookInstaller.install()
        switch result {
        case .success(let backupPath):
            let msg = backupPath != nil 
                ? String(format: NSLocalizedString("hook.install.success.detail", value: "插件安装成功，备份位置: %@", comment: ""), backupPath!)
                : NSLocalizedString("hook.install.success.title", value: "插件安装成功", comment: "")
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
            let msg = backupPath != nil
                ? String(format: NSLocalizedString("hook.uninstall.success.detail", value: "插件卸载成功，备份位置: %@", comment: ""), backupPath!)
                : NSLocalizedString("hook.uninstall.success.title", value: "插件卸载成功", comment: "")
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

    // MARK: - 完整设置窗口

    private var settingsWindowController: NSWindowController?

    func openFullSettings() {
        if let controller = settingsWindowController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(
            rootView: SettingsView()
                .environment(self)
                .frame(width: 480, height: 440)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("settings.title", comment: "Settings")
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .screenSaver + 1
        // 窗口关闭时清理引用
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindowController = nil
        }
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        settingsWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Toggle State

    func toggleIslandState() {
        islandState = islandState == .compact ? .expanded : .compact
        // 通知 panel 更新内容（实际动画在 DynamicIslandPanelContent 中执行）
        let isExpanded = islandState == .expanded
        NotificationCenter.default.post(
            name: .islandStateDidChange,
            object: nil,
            userInfo: ["isExpanded": isExpanded]
        )
    }
}


