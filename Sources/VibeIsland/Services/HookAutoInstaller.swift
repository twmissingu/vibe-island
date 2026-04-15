import Foundation
import OSLog
import AppKit

// MARK: - Hook 自动安装器

/// 自动检测和配置 Claude Code hooks 的服务
///
/// 功能：
/// - 检测 Claude Code 是否已安装
/// - 非破坏性地合并 hook 配置到 ~/.claude/settings.json
/// - 支持安装和卸载两种操作
/// - 包含备份和回滚机制
@MainActor
final class HookAutoInstaller {

    // MARK: - 单例

    static let shared = HookAutoInstaller()

    // MARK: - 常量
    
    /// Claude Code 全局配置路径
    static let claudeSettingsPath = NSString("~/").expandingTildeInPath + ".claude/settings.json"
    
    /// 配置备份目录
    static let backupDirectory = NSString("~/").expandingTildeInPath + ".claude/vibe-island-backups"
    
    /// 内置 hooks 配置资源名
    static let hooksConfigResourceName = "hooks-config"
    
    // MARK: - 日志
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "HookAutoInstaller"
    )
    
    // MARK: - 公开属性
    
    /// Claude Code 是否已安装
    var isClaudeCodeInstalled: Bool {
        detectClaudeCodeInstallation()
    }
    
    /// 当前是否已安装 VibeIsland hooks
    var isHookInstalled: Bool {
        guard let settings = readClaudeSettings() else { return false }
        return containsVibeIslandHooks(settings)
    }
    
    // MARK: - 安装
    
    /// 安装 hooks 到 Claude Code 配置
    /// - Returns: 安装结果
    func install() async -> InstallResult {
        // 1. 检测 Claude Code
        guard isClaudeCodeInstalled else {
            return .failure(.claudeCodeNotFound)
        }
        
        // 2. 读取现有配置
        let existingSettings: ClaudeSettings
        if let settings = readClaudeSettings() {
            existingSettings = settings
        } else {
            // 配置文件不存在，创建新文件
            existingSettings = ClaudeSettings(hooks: [:])
        }
        
        // 3. 备份原有配置
        let backupPath: String
        do {
            backupPath = try backupCurrentSettings(existingSettings)
        } catch {
            return .failure(.backupFailed(error))
        }
        
        // 4. 加载内置 hooks 配置
        guard let newHooks = loadBuiltInHooksConfig() else {
            return .failure(.configNotFound)
        }
        
        // 5. 合并配置（非破坏性更新）
        let mergedSettings = mergeHooks(existing: existingSettings, newHooks: newHooks)
        
        // 6. 写入配置
        do {
            try writeClaudeSettings(mergedSettings)
        } catch {
            // 写入失败，尝试回滚
            do {
                try restoreFromBackup(backupPath)
            } catch {
                Self.logger.error("回滚也失败了: \(error.localizedDescription)")
            }
            return .failure(.writeFailed(error))
        }
        
        // 7. 清理备份（成功时保留备份 7 天）
        scheduleBackupCleanup()
        
        Self.logger.info("Hooks 安装成功，备份位置: \(backupPath)")
        return .success(backupPath: backupPath)
    }
    
    // MARK: - 卸载
    
    /// 从 Claude Code 配置中移除 VibeIsland hooks
    /// - Returns: 卸载结果
    func uninstall() async -> UninstallResult {
        // 1. 检测 Claude Code
        guard isClaudeCodeInstalled else {
            return .failure(.claudeCodeNotFound)
        }
        
        // 2. 读取现有配置
        guard let settings = readClaudeSettings() else {
            return .failure(.settingsNotFound)
        }
        
        // 3. 检查是否已安装
        guard containsVibeIslandHooks(settings) else {
            return .failure(.notInstalled)
        }
        
        // 4. 备份
        let backupPath: String
        do {
            backupPath = try backupCurrentSettings(settings)
        } catch {
            return .failure(.backupFailed(error))
        }
        
        // 5. 移除 VibeIsland hooks
        let cleanedSettings = removeVibeIslandHooks(settings)
        
        // 6. 写入清理后的配置
        do {
            try writeClaudeSettings(cleanedSettings)
        } catch {
            // 写入失败，尝试回滚
            do {
                try restoreFromBackup(backupPath)
            } catch {
                Self.logger.error("回滚也失败了: \(error.localizedDescription)")
            }
            return .failure(.writeFailed(error))
        }
        
        Self.logger.info("Hooks 卸载成功，备份位置: \(backupPath)")
        return .success(backupPath: backupPath)
    }
    
    // MARK: - 回滚

    /// 从备份恢复配置
    /// - Parameter backupPath: 备份文件路径
    /// - Returns: 是否成功
    func restore(from backupPath: String) throws -> Bool {
        try restoreFromBackup(backupPath)
        return true
    }

    // MARK: - 带用户反馈的操作

    /// 安装 hooks 并显示用户反馈
    /// 此方法会调用安装并在主线程显示成功或失败提示
    func installWithFeedback() async {
        let result = await install()
        switch result {
        case .success(let backupPath):
            ErrorPresenter.showHookInstallSuccess(backupPath: backupPath)
        case .failure(let error):
            ErrorPresenter.showHookInstallFailure(error)
        }
    }

    /// 卸载 hooks 并显示用户反馈
    /// 此方法会调用卸载并在主线程显示成功或失败提示
    func uninstallWithFeedback() async {
        let result = await uninstall()
        switch result {
        case .success(let backupPath):
            ErrorPresenter.showHookUninstallSuccess(backupPath: backupPath)
        case .failure(let error):
            ErrorPresenter.showHookUninstallFailure(error)
        }
    }
    
    /// 列出所有可用的备份
    /// - Returns: 备份文件路径列表（按时间倒序）
    func listBackups() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: Self.backupDirectory) else {
            return []
        }
        return contents
            .filter { $0.hasPrefix("settings-") && $0.hasSuffix(".json") }
            .map { Self.backupDirectory + "/" + $0 }
            .sorted()
            .reversed()
    }
    
    // MARK: - 内部实现
    
    /// 检测 Claude Code 是否安装
    private func detectClaudeCodeInstallation() -> Bool {
        // 方法 1: 检查 ~/.claude 目录是否存在
        let claudeDir = NSString("~/").expandingTildeInPath + ".claude"
        if FileManager.default.fileExists(atPath: claudeDir) {
            return true
        }
        
        // 方法 2: 检查 claude 命令是否可用
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// 读取 Claude Code 配置
    private func readClaudeSettings() -> ClaudeSettings? {
        let path = Self.claudeSettingsPath
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            return try decoder.decode(ClaudeSettings.self, from: data)
        } catch {
            Self.logger.error("读取配置失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 写入 Claude Code 配置
    private func writeClaudeSettings(_ settings: ClaudeSettings) throws {
        let path = Self.claudeSettingsPath
        let dirPath = (path as NSString).deletingLastPathComponent
        
        // 确保目录存在
        let fm = FileManager.default
        if !fm.fileExists(atPath: dirPath) {
            try fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
    
    /// 备份当前配置
    private func backupCurrentSettings(_ settings: ClaudeSettings) throws -> String {
        let fm = FileManager.default
        let backupDir = Self.backupDirectory
        
        // 创建备份目录
        if !fm.fileExists(atPath: backupDir) {
            try fm.createDirectory(atPath: backupDir, withIntermediateDirectories: true)
        }
        
        // 生成备份文件名（带时间戳）
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupPath = backupDir + "/settings-\(timestamp).json"
        
        // 写入备份
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: URL(fileURLWithPath: backupPath), options: .atomic)
        
        return backupPath
    }
    
    /// 从备份恢复
    private func restoreFromBackup(_ backupPath: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupPath) else {
            throw HookError.backupNotFound(backupPath)
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: backupPath))
        try data.write(to: URL(fileURLWithPath: Self.claudeSettingsPath), options: .atomic)
    }
    
    /// 加载内置 hooks 配置
    private func loadBuiltInHooksConfig() -> [String: [HookRule]]? {
        // 从 bundle 中读取 hooks-config.json
        guard let url = Bundle.main.url(forResource: Self.hooksConfigResourceName, withExtension: "json") else {
            Self.logger.error("未找到 hooks-config.json 资源文件")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let config = try decoder.decode(HooksConfig.self, from: data)
            return config.hooks
        } catch {
            Self.logger.error("解析 hooks 配置失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 合并 hooks（非破坏性更新）
    private func mergeHooks(existing: ClaudeSettings, newHooks: [String: [HookRule]]) -> ClaudeSettings {
        var merged = existing.hooks ?? [:]
        
        for (event, newRules) in newHooks {
            if let existingRules = merged[event] {
                // 合并规则：如果 matcher 相同则替换，否则追加
                var existingMatchers = Set(existingRules.compactMap { $0.matcher })
                var updatedRules = existingRules
                
                for newRule in newRules {
                    if let m = newRule.matcher, !existingMatchers.contains(m) {
                        updatedRules.append(newRule)
                        existingMatchers.insert(m)
                    } else if newRule.matcher == nil {
                        // 空 matcher 表示匹配所有，追加到末尾
                        updatedRules.append(newRule)
                    }
                }
                
                merged[event] = updatedRules
            } else {
                merged[event] = newRules
            }
        }
        
        return ClaudeSettings(
            hooks: merged,
            disableAllHooks: existing.disableAllHooks ?? false,
            allowManagedHooksOnly: existing.allowManagedHooksOnly ?? false
        )
    }
    
    /// 检查是否包含 VibeIsland hooks
    private func containsVibeIslandHooks(_ settings: ClaudeSettings) -> Bool {
        guard let hooks = settings.hooks else { return false }
        
        let vibeIslandMarker = "vibe-island"
        for (_, rules) in hooks {
            for rule in rules {
                for hook in rule.hooks ?? [] {
                    if hook.command?.contains(vibeIslandMarker) == true {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    /// 移除 VibeIsland hooks
    private func removeVibeIslandHooks(_ settings: ClaudeSettings) -> ClaudeSettings {
        guard var hooks = settings.hooks else { return settings }
        
        let vibeIslandMarker = "vibe-island"
        
        for event in Array(hooks.keys) {
            let originalRules = hooks[event] ?? []
            let filteredRules = originalRules.filter { rule in
                let hasVibeIslandHook = (rule.hooks ?? []).contains { hook in
                    hook.command?.contains(vibeIslandMarker) == true
                }
                return !hasVibeIslandHook
            }
            
            if filteredRules.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = filteredRules
            }
        }
        
        return ClaudeSettings(
            hooks: hooks.isEmpty ? nil : hooks,
            disableAllHooks: settings.disableAllHooks,
            allowManagedHooksOnly: settings.allowManagedHooksOnly
        )
    }
    
    /// 清理过期备份（保留最近 7 天）
    private func scheduleBackupCleanup() {
        let fm = FileManager.default
        let backupDir = Self.backupDirectory
        
        guard let contents = try? fm.contentsOfDirectory(atPath: backupDir) else { return }
        
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        for item in contents where item.hasPrefix("settings-") && item.hasSuffix(".json") {
            let path = backupDir + "/" + item
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modificationDate = attrs[.modificationDate] as? Date,
               modificationDate < sevenDaysAgo {
                try? fm.removeItem(atPath: path)
            }
        }
    }
}

// MARK: - 数据模型

/// Claude Code 配置结构
struct ClaudeSettings: Codable {
    var hooks: [String: [HookRule]]?
    var disableAllHooks: Bool?
    var allowManagedHooksOnly: Bool?
    
    enum CodingKeys: String, CodingKey {
        case hooks
        case disableAllHooks
        case allowManagedHooksOnly
    }
}

/// Hook 规则
struct HookRule: Codable {
    var matcher: String?
    var hooks: [HookAction]?
    
    enum CodingKeys: String, CodingKey {
        case matcher
        case hooks
    }
}

/// Hook 动作
struct HookAction: Codable {
    var type: String?           // "command", "http", "prompt", "agent"
    var command: String?
    var url: String?
    var prompt: String?
    var timeout: Int?
    var async: Bool?
    var headers: [String: String]?
    var allowedEnvVars: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case command
        case url
        case prompt
        case timeout
        case async
        case headers
        case allowedEnvVars
    }
}

/// Hooks 配置文件结构
struct HooksConfig: Codable {
    var hooks: [String: [HookRule]]
}

// MARK: - 结果类型

/// 安装结果
enum InstallResult {
    case success(backupPath: String)
    case failure(HookError)
}

/// 卸载结果
enum UninstallResult {
    case success(backupPath: String)
    case failure(HookError)
}

/// Hook 错误类型
enum HookError: LocalizedError, __HookErrorIdentifiable {
    case claudeCodeNotFound
    case settingsNotFound
    case notInstalled
    case configNotFound
    case backupFailed(Error)
    case writeFailed(Error)
    case backupNotFound(String)
    case rollbackFailed(Error)

    var errorDescription: String? {
        switch self {
        case .claudeCodeNotFound:
            return NSLocalizedString("hook.error.claudeNotFound", value: "未检测到 Claude Code，请先安装 Claude Code", comment: "")
        case .settingsNotFound:
            return NSLocalizedString("hook.error.settingsNotFound", value: "未找到 Claude Code 配置文件 (~/.claude/settings.json)", comment: "")
        case .notInstalled:
            return NSLocalizedString("hook.error.notInstalled", value: "VibeIsland hooks 未安装", comment: "")
        case .configNotFound:
            return NSLocalizedString("hook.error.configNotFound", value: "未找到内置 hooks 配置文件 (hooks-config.json)", comment: "")
        case .backupFailed(let error):
            return String(format: NSLocalizedString("hook.error.backupFailed", value: "备份失败: %@", comment: ""), error.localizedDescription)
        case .writeFailed(let error):
            return String(format: NSLocalizedString("hook.error.writeFailed", value: "写入配置失败: %@", comment: ""), error.localizedDescription)
        case .backupNotFound(let path):
            return String(format: NSLocalizedString("hook.error.backupNotFound", value: "未找到备份文件: %@", comment: ""), path)
        case .rollbackFailed(let error):
            return String(format: NSLocalizedString("hook.error.rollbackFailed", value: "回滚失败: %@", comment: ""), error.localizedDescription)
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .claudeCodeNotFound:
            return NSLocalizedString("hook.recovery.claudeNotFound", value: "请确保已安装 Claude Code，并在终端中运行 `claude` 命令验证安装。", comment: "")
        case .settingsNotFound:
            return NSLocalizedString("hook.recovery.settingsNotFound", value: "请先运行一次 Claude Code 以创建配置文件，然后再尝试安装 Hook。", comment: "")
        case .notInstalled:
            return NSLocalizedString("hook.recovery.notInstalled", value: "请先安装 Hook 后再尝试卸载。", comment: "")
        case .configNotFound:
            return NSLocalizedString("hook.recovery.configNotFound", value: "内置配置文件缺失，请检查应用完整性或重新安装 Vibe Island。", comment: "")
        case .backupFailed:
            return NSLocalizedString("hook.recovery.backupFailed", value: "请确保 ~/.claude/vibe-island-backups 目录可写，并检查磁盘空间。", comment: "")
        case .writeFailed:
            return NSLocalizedString("hook.recovery.writeFailed", value: "请检查 ~/.claude/settings.json 文件的写入权限。", comment: "")
        case .backupNotFound:
            return NSLocalizedString("hook.recovery.backupNotFound", value: "备份文件不存在，无法恢复。请手动检查配置。", comment: "")
        case .rollbackFailed:
            return NSLocalizedString("hook.recovery.rollbackFailed", value: "自动回滚失败，请手动恢复 ~/.claude/settings.json 文件。", comment: "")
        }
    }
}

// MARK: - HookError Equatable

extension HookError: Equatable {
    static func == (lhs: HookError, rhs: HookError) -> Bool {
        switch (lhs, rhs) {
        case (.claudeCodeNotFound, .claudeCodeNotFound): return true
        case (.settingsNotFound, .settingsNotFound): return true
        case (.notInstalled, .notInstalled): return true
        case (.configNotFound, .configNotFound): return true
        case (.backupFailed, .backupFailed): return true
        case (.writeFailed, .writeFailed): return true
        case (.backupNotFound, .backupNotFound): return true
        case (.rollbackFailed, .rollbackFailed): return true
        default: return false
        }
    }
}
