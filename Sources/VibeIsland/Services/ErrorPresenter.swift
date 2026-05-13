import Cocoa
import OSLog

// MARK: - ErrorPresenter

/// 统一的错误提示服务
///
/// 提供分级错误提示（info/warning/error），使用 NSAlert 在主线程展示。
/// 所有错误消息通过 NSLocalizedString 支持国际化。
@MainActor
final class ErrorPresenter {

    // MARK: - 单例

    static let shared = ErrorPresenter()

    // MARK: - 日志

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "ErrorPresenter"
    )

    // MARK: - 错误级别

    /// 错误级别定义
    enum Level {
        /// 信息提示 - 仅展示信息
        case info
        /// 警告提示 - 提醒用户注意
        case warning
        /// 错误提示 - 表示操作失败
        case error

        var alertIcon: NSAlert.Style {
            switch self {
            case .info:
                return .informational
            case .warning:
                return .warning
            case .error:
                return .critical
            }
        }
    }

    // MARK: - 配置

    /// 提示配置
    struct AlertConfig {
        let title: String
        let message: String
        let informativeText: String?
        let level: Level
        let buttonText: String?

        init(
            title: String,
            message: String = "",
            informativeText: String? = nil,
            level: Level = .info,
            buttonText: String? = nil
        ) {
            self.title = title
            self.message = message
            self.informativeText = informativeText
            self.level = level
            self.buttonText = buttonText
        }
    }

    // MARK: - 公开方法

    /// 显示信息提示
    static func showInfo(
        title: String,
        message: String = "",
        informativeText: String? = nil
    ) {
        shared.presentAlert(
            title: L(title),
            message: L(message),
            informativeText: informativeText.map { L($0) },
            style: .informational,
            buttonText: L("button.ok", fallback: "确定")
        )
    }

    /// 显示警告提示
    static func showWarning(
        title: String,
        message: String = "",
        informativeText: String? = nil
    ) {
        shared.presentAlert(
            title: L(title),
            message: L(message),
            informativeText: informativeText.map { L($0) },
            style: .warning,
            buttonText: L("button.ok", fallback: "确定")
        )
    }

    /// 显示错误提示
    static func showError(
        title: String,
        message: String = "",
        informativeText: String? = nil
    ) {
        shared.presentAlert(
            title: L(title),
            message: L(message),
            informativeText: informativeText.map { L($0) },
            style: .critical,
            buttonText: L("button.ok", fallback: "确定")
        )
    }

    /// 从 Error 对象显示错误
    static func show(
        _ error: Error,
        title: String? = nil,
        level: Level = .error
    ) {
        let message: String
        let informativeText: String?

        if let localizedError = error as? LocalizedError {
            message = localizedError.errorDescription ?? error.localizedDescription
            informativeText = localizedError.failureReason ?? localizedError.recoverySuggestion
        } else {
            message = error.localizedDescription
            informativeText = nil
        }

        let finalTitle = title ?? L("error.title", fallback: "错误")
        shared.presentAlert(
            title: finalTitle,
            message: message,
            informativeText: informativeText,
            style: level.alertIcon,
            buttonText: L("button.ok", fallback: "确定")
        )
    }

    /// 显示自定义配置的提示
    static func show(config: AlertConfig) {
        shared.presentAlert(
            title: config.title,
            message: config.message,
            informativeText: config.informativeText,
            style: config.level.alertIcon,
            buttonText: config.buttonText ?? L("button.ok", fallback: "确定")
        )
    }

    /// 异步显示提示（不阻塞当前任务）
    static func presentAsync(config: AlertConfig) {
        Task { @MainActor in
            show(config: config)
        }
    }

    /// 异步显示错误（不阻塞当前任务）
    static func presentAsync(
        _ error: Error,
        title: String? = nil,
        level: Level = .error
    ) {
        Task { @MainActor in
            show(error, title: title, level: level)
        }
    }

    // MARK: - Hook 安装相关

    /// 显示 Hook 安装成功提示
    static func showHookInstallSuccess(backupPath: String) {
        showInfo(
            title: "hook.install.success.title",
            message: "hook.install.success.message",
            informativeText: String(format: L("hook.install.success.detail", fallback: "备份位置: %@"), backupPath)
        )
    }

    /// 显示 Hook 安装失败提示
    static func showHookInstallFailure(_ error: Error) {
        let recoverySuggestion = defaultRecoverySuggestion(for: error)

        show(
            error,
            title: L("hook.install.failed.title", fallback: "Hook 安装失败"),
            level: .error
        )

        // 如果有恢复建议，再次显示包含建议的提示
        if !recoverySuggestion.isEmpty {
            showWarning(
                title: "hook.install.recovery.title",
                message: error.localizedDescription,
                informativeText: recoverySuggestion
            )
        }
    }

    /// 显示 Hook 卸载成功提示
    static func showHookUninstallSuccess(backupPath: String) {
        showInfo(
            title: "hook.uninstall.success.title",
            message: "hook.uninstall.success.message",
            informativeText: String(format: L("hook.uninstall.success.detail", fallback: "备份位置: %@"), backupPath)
        )
    }

    /// 显示 Hook 卸载失败提示
    static func showHookUninstallFailure(_ error: Error) {
        show(
            error,
            title: L("hook.uninstall.failed.title", fallback: "Hook 卸载失败"),
            level: .error
        )
    }

    // MARK: - 额度刷新相关

    /// 显示额度刷新失败提示
    static func showQuotaRefreshFailure(_ error: Error) {
        showError(
            title: "quota.refresh.failed.title",
            message: "quota.refresh.failed.message",
            informativeText: String(format: L("quota.refresh.failed.detail", fallback: "错误详情：%@"), error.localizedDescription)
        )
    }

    // MARK: - 内部实现

    /// 呈现 NSAlert
    private func presentAlert(
        title: String,
        message: String,
        informativeText: String?,
        style: NSAlert.Style,
        buttonText: String
    ) {
        // 确保在主线程运行
        dispatchPrecondition(condition: .onQueue(.main))

        let alert = NSAlert()
        alert.messageText = title

        // 组合 message 和 informativeText
        var fullText = message
        if let informativeText = informativeText, !informativeText.isEmpty {
            fullText += "\n\n" + informativeText
        }
        alert.informativeText = fullText
        alert.alertStyle = style

        alert.addButton(withTitle: buttonText)

        // 获取主窗口作为父窗口
        if let window = NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first {
            alert.beginSheetModal(for: window) { _ in
                Self.logger.debug("Alert dismissed: \(title)")
            }
        } else {
            // 没有窗口时以模态方式显示
            _ = alert.runModal()
            Self.logger.debug("Alert dismissed (modal): \(title)")
        }
    }

    /// 获取本地化字符串的辅助方法
    /// 使用 NSLocalizedString 的 value 参数作为 fallback
    static func L(_ key: String, fallback: String = "") -> String {
        let result = NSLocalizedString(key, value: fallback, comment: "")
        return result.isEmpty ? fallback : result
    }

    /// 根据错误类型返回恢复建议
    private static func defaultRecoverySuggestion(for error: Error) -> String {
        // 尝试匹配 HookError 的描述
        let desc = error.localizedDescription

        // 通过错误类型或描述匹配
        if let hookError = error as? __HookErrorIdentifiable {
            return hookError.recoverySuggestion
        }

        // 通过描述关键字匹配（作为 fallback）
        if desc.contains("未检测到 Claude Code") || desc.contains("Claude Code not detected") {
            return L("hook.recovery.claudeNotFound", fallback: "请确保已安装 Claude Code，并在终端中运行 `claude` 命令验证安装。")
        } else if desc.contains("未找到 Claude Code 配置文件") || desc.contains("configuration file not found") {
            return L("hook.recovery.settingsNotFound", fallback: "请先运行一次 Claude Code 以创建配置文件，然后再尝试安装 Hook。")
        } else if desc.contains("未安装") || desc.contains("not installed") {
            return L("hook.recovery.notInstalled", fallback: "请先安装 Hook 后再尝试卸载。")
        } else if desc.contains("配置文件") || desc.contains("config") {
            return L("hook.recovery.configNotFound", fallback: "内置配置文件缺失，请检查应用完整性或重新安装 Vibe Island。")
        } else if desc.contains("备份失败") || desc.contains("Backup failed") {
            return L("hook.recovery.backupFailed", fallback: "请确保 ~/.claude/vibe-island-backups 目录可写，并检查磁盘空间。")
        } else if desc.contains("写入") || desc.contains("write") {
            return L("hook.recovery.writeFailed", fallback: "请检查 ~/.claude/settings.json 文件的写入权限。")
        }

        return ""
    }

    private init() {}
}

// MARK: - HookError 协议桥接

/// 用于在 ErrorPresenter 中识别 HookError 类型的协议
protocol __HookErrorIdentifiable: Error {
    var recoverySuggestion: String { get }
}
