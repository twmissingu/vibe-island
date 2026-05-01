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
    static let claudeSettingsPath = NSString("~/.claude/settings.json").expandingTildeInPath
    
    /// 配置备份目录
    static let backupDirectory = NSString("~/.claude/vibe-island-backups").expandingTildeInPath
    
    /// 内置 hooks 配置资源名
    static let hooksConfigResourceName = "hooks-config"
    
    // MARK: - 安全书签相关常量
    
    /// 用户默认设置中存储安全书签的 key
    private static let claudeDirBookmarkKey = "claude-dir-bookmark"
    
    /// Claude 目录路径
    static let claudeDirPath = NSString("~/.claude").expandingTildeInPath
    
    // MARK: - 安全书签管理
    
    /// 缓存的目录访问权限
    private var claudeDirAccessGranted = false
    
    /// 当前正在访问的安全范围 URL（用于平衡 stopAccessingSecurityScopedResource）
    private var currentSecurityScopedURL: URL?
    
    /// 请求目录授权（弹出 NSOpenPanel）
    func requestDirectoryAuthorization() async -> Bool {
        NSLog("[HookAutoInstaller] requestDirectoryAuthorization 开始")
        
        // 如果已经授权，直接返回
        if claudeDirAccessGranted {
            NSLog("[HookAutoInstaller] 已有目录授权，跳过")
            return true
        }
        
        // 尝试从书签恢复权限
        NSLog("[HookAutoInstaller] 尝试从书签恢复权限")
        if await restoreBookmarkAccess() {
            claudeDirAccessGranted = true
            NSLog("[HookAutoInstaller] 从书签恢复权限成功")
            return true
        }
        
        // 弹出 NSOpenPanel 让用户选择目录
        NSLog("[HookAutoInstaller] 弹出目录选择面板")
        return await showDirectorySelectionPanel()
    }
    
    /// 显示目录选择面板
    private func showDirectorySelectionPanel() async -> Bool {
        NSLog("[HookAutoInstaller] showDirectorySelectionPanel 开始")
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                NSLog("[HookAutoInstaller] 在主线程创建 NSOpenPanel")
                
                let panel = NSOpenPanel()
                panel.title = NSLocalizedString("hook.auth.title", value: "授权访问 Claude 配置目录", comment: "")
                panel.message = NSLocalizedString("hook.auth.message", value: "请选择 ~/.claude 目录以授权 Vibe Island 访问 Claude Code 配置文件", comment: "")
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.canCreateDirectories = false
                panel.allowsMultipleSelection = false
                panel.showsHiddenFiles = true
                
                // 设置默认目录为 ~/.claude
                let claudeDir = URL(fileURLWithPath: Self.claudeDirPath)
                if FileManager.default.fileExists(atPath: Self.claudeDirPath) {
                    panel.directoryURL = claudeDir
                }
                
                NSLog("[HookAutoInstaller] 准备显示面板")
                
                // 使用 runModal 同步显示面板
                let response = panel.runModal()
                NSLog("[HookAutoInstaller] 面板响应: \(response.rawValue)")
                
                guard response == .OK, let url = panel.url else {
                    NSLog("[HookAutoInstaller] 用户取消了目录授权")
                    continuation.resume(returning: false)
                    return
                }
                
                NSLog("[HookAutoInstaller] 用户选择的目录: \(url.path)")
                
                // 验证选择的目录是否为 ~/.claude
                let selectedPath = url.path
                if selectedPath != Self.claudeDirPath {
                    NSLog("[HookAutoInstaller] 用户选择了错误的目录: \(selectedPath)")
                    continuation.resume(returning: false)
                    return
                }
                
                // 保存安全书签
                if self?.saveBookmark(for: url) == true {
                    self?.claudeDirAccessGranted = true
                    NSLog("[HookAutoInstaller] 目录授权成功")
                    continuation.resume(returning: true)
                } else {
                    NSLog("[HookAutoInstaller] 保存安全书签失败")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// 保存安全书签
    private func saveBookmark(for url: URL) -> Bool {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: Self.claudeDirBookmarkKey)
            Self.logger.info("安全书签保存成功")
            return true
        } catch {
            Self.logger.error("保存安全书签失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 从书签恢复访问权限
    private func restoreBookmarkAccess() async -> Bool {
        guard let bookmarkData = UserDefaults.standard.data(forKey: Self.claudeDirBookmarkKey) else {
            return false
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                Self.logger.warning("安全书签已过期，需要重新授权")
                return false
            }
            
            // 开始访问目录
            if url.startAccessingSecurityScopedResource() {
                currentSecurityScopedURL = url
                Self.logger.info("从书签恢复目录访问成功")
                return true
            } else {
                Self.logger.error("无法访问安全范围资源")
                return false
            }
        } catch {
            Self.logger.error("解析安全书签失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 停止访问安全范围资源
    private func stopAccessingSecurityScopedResource() {
        if let url = currentSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
            currentSecurityScopedURL = nil
            Self.logger.info("已停止访问安全范围资源")
        }
    }
    
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
        NSLog("[HookAutoInstaller] install() 开始")
        
        // 0. 检查并修复权限
        let permissionResult = await checkAndFixPermissions()
        if case .failure(let error) = permissionResult {
            NSLog("[HookAutoInstaller] 权限检查失败: %@", error.localizedDescription)
            return .failure(error)
        }
        
        // 1. 检测 Claude Code
        guard isClaudeCodeInstalled else {
            NSLog("[HookAutoInstaller] Claude Code 未安装")
            return .failure(.claudeCodeNotFound)
        }
        
        NSLog("[HookAutoInstaller] Claude Code 已安装")
        
        // 2. 读取现有配置
        let existingSettings: ClaudeSettings
        if let settings = readClaudeSettings() {
            existingSettings = settings
            NSLog("[HookAutoInstaller] 读取现有配置成功")
        } else {
            // 配置文件不存在，创建新文件
            existingSettings = ClaudeSettings(hooks: [:])
            NSLog("[HookAutoInstaller] 配置文件不存在，创建新配置")
        }
        
        // 3. 备份原有配置（可选，失败不阻断安装）
        var backupPath: String? = nil
        do {
            backupPath = try backupCurrentSettings(existingSettings)
            NSLog("[HookAutoInstaller] 配置备份成功: %@", backupPath ?? "nil")
        } catch {
            NSLog("[HookAutoInstaller] 配置备份失败（沙盒限制），继续安装: %@", error.localizedDescription)
            backupPath = nil
        }
        
        // 4. 加载内置 hooks 配置
        guard let newHooks = loadBuiltInHooksConfig() else {
            NSLog("[HookAutoInstaller] 加载内置配置失败")
            return .failure(.configNotFound)
        }
        
        NSLog("[HookAutoInstaller] 加载内置配置成功")
        
        // 5. 合并配置（非破坏性更新）
        let mergedSettings = mergeHooks(existing: existingSettings, newHooks: newHooks)
        NSLog("[HookAutoInstaller] 配置合并完成")
        
        // 6. 写入配置
        do {
            try writeClaudeSettings(mergedSettings)
            NSLog("[HookAutoInstaller] 配置写入成功")
        } catch {
            NSLog("[HookAutoInstaller] 配置写入失败: %@", error.localizedDescription)
            // 写入失败，尝试回滚
            if let bp = backupPath {
                do {
                    try restoreFromBackup(bp)
                } catch {
                    Self.logger.error("回滚也失败了: \(error.localizedDescription)")
                }
            }
            return .failure(.writeFailed(error))
        }
        
        // 7. 清理备份（成功时保留备份 7 天）
        scheduleBackupCleanup()
        
        // 8. 停止访问安全范围资源
        stopAccessingSecurityScopedResource()
        
        Self.logger.info("Hooks 安装成功，备份位置: \(backupPath ?? "无")")
        return .success(backupPath: backupPath)
    }
    
    // MARK: - 卸载
    
    /// 从 Claude Code 配置中移除 VibeIsland hooks
    /// - Returns: 卸载结果
    func uninstall() async -> UninstallResult {
        // 0. 检查并修复权限
        let permissionResult = await checkAndFixPermissions()
        if case .failure(let error) = permissionResult {
            return .failure(error)
        }
        
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
        
        // 4. 备份（可选，失败不阻断卸载）
        var backupPath: String? = nil
        do {
            backupPath = try backupCurrentSettings(settings)
            Self.logger.info("配置备份成功: \(backupPath ?? "nil")")
        } catch {
            Self.logger.warning("配置备份失败，继续卸载: \(error.localizedDescription)")
        }
        
        // 5. 移除 VibeIsland hooks
        let cleanedSettings = removeVibeIslandHooks(settings)
        
        // 6. 写入清理后的配置
        do {
            try writeClaudeSettings(cleanedSettings)
        } catch {
            // 写入失败，尝试回滚
            if let bp = backupPath {
                do {
                    try restoreFromBackup(bp)
                } catch {
                    Self.logger.error("回滚也失败了: \(error.localizedDescription)")
                }
            }
            return .failure(.writeFailed(error))
        }
        
        // 7. 停止访问安全范围资源
        stopAccessingSecurityScopedResource()
        
        Self.logger.info("Hooks 卸载成功，备份位置: \(backupPath ?? "无")")
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
        _ = await install()
        // 提示逻辑在UI层实现
    }

    /// 卸载 hooks 并显示用户反馈
    /// 此方法会调用卸载并在主线程显示成功或失败提示
    func uninstallWithFeedback() async {
        _ = await uninstall()
        // 提示逻辑在UI层实现
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
        let fm = FileManager.default
        let homeDir = NSString("~/").expandingTildeInPath
        let claudeDir = homeDir + ".claude"
        
        // 方法 1: 检查 ~/.claude 目录是否存在
        let dirExists = fm.fileExists(atPath: claudeDir)
        Self.logger.debug("检测 ~/.claude 目录: \(dirExists ? "存在" : "不存在")，路径: \(claudeDir)")
        if dirExists {
            return true
        }
        
        // 方法 2: 检查常见安装路径的 claude 可执行文件
        let commonPaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            homeDir + ".local/bin/claude",
            "/usr/bin/claude",
            "/bin/claude"
        ]
        for path in commonPaths {
            if fm.isExecutableFile(atPath: path) {
                Self.logger.debug("在常见路径找到 claude 可执行文件: \(path)")
                return true
            }
        }
        
        // 方法 3: 运行 command -v claude 检测（比 which 更可靠）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v claude"]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let status = process.terminationStatus
            let outputData = try outputPipe.fileHandleForReading.readToEnd()
            let output = outputData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            Self.logger.debug("command -v claude 执行结果: status=\(status), output=\(output)")
            if status == 0 && !output.isEmpty {
                return true
            }
        } catch {
            Self.logger.error("运行检测命令失败: \(error.localizedDescription)")
        }
        
        Self.logger.warning("所有检测方法都未找到 Claude Code")
        return false
    }
    
    /// 读取 Claude Code 配置
    private func readClaudeSettings() -> ClaudeSettings? {
        let path = Self.claudeSettingsPath
        guard FileManager.default.fileExists(atPath: path) else {
            Self.logger.error("配置文件不存在: \(path)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            // 打印原始JSON方便调试
            if let jsonStr = String(data: data, encoding: .utf8) {
                Self.logger.debug("读取到配置内容: \(jsonStr)")
            }
            let decoder = JSONDecoder()
            let settings = try decoder.decode(ClaudeSettings.self, from: data)
            Self.logger.debug("解析成功: \(settings.hooks ?? [:])")
            return settings
        } catch {
            Self.logger.error("读取配置失败: \(error.localizedDescription)")
            // 打印JSON解析错误详情
            if let decodingError = error as? DecodingError {
                Self.logger.error("JSON解析错误详情: \(decodingError)")
            }
            return nil
        }
    }
    
    /// 写入 Claude Code 配置
    private func writeClaudeSettings(_ settings: ClaudeSettings) throws {
        let path = Self.claudeSettingsPath
        let dirPath = (path as NSString).deletingLastPathComponent
        
        NSLog("[HookAutoInstaller] writeClaudeSettings 开始, path=%@", path)
        
        // 确保目录存在
        let fm = FileManager.default
        if !fm.fileExists(atPath: dirPath) {
            NSLog("[HookAutoInstaller] 创建目录: %@", dirPath)
            try fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        
        NSLog("[HookAutoInstaller] 写入配置文件, 大小=%lu bytes", data.count)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        NSLog("[HookAutoInstaller] writeClaudeSettings 完成")
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
            allowManagedHooksOnly: existing.allowManagedHooksOnly ?? false,
            env: existing.env
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
        
        let allHooksRemoved = hooks.isEmpty
        return ClaudeSettings(
            hooks: allHooksRemoved ? nil : hooks,
            // 删除所有 hooks 时也清除这两个字段（恢复到用户未配置状态）
            disableAllHooks: allHooksRemoved ? nil : settings.disableAllHooks,
            allowManagedHooksOnly: allHooksRemoved ? nil : settings.allowManagedHooksOnly,
            // env 是用户的环境变量配置，删除 hooks 时应保留
            env: settings.env
        )
    }
    
    /// 检查并自动修复 ~/.claude 目录权限
    private func checkAndFixPermissions() async -> Result<Void, HookError> {
        let fm = FileManager.default
        
        NSLog("[HookAutoInstaller] checkAndFixPermissions 开始, claudeDirPath=%@", Self.claudeDirPath)
        
        // 1. 检查 ~/.claude 目录是否存在
        guard fm.fileExists(atPath: Self.claudeDirPath) else {
            NSLog("[HookAutoInstaller] ~/.claude 目录不存在, 路径=%@", Self.claudeDirPath)
            return .failure(.permissionDenied("未找到 Claude Code 配置目录 (~/.claude)。请先安装并运行 Claude Code。"))
        }
        
        NSLog("[HookAutoInstaller] ~/.claude 目录存在，请求授权")
        
        // 2. 请求目录授权（弹出 NSOpenPanel 或从书签恢复）
        let authorized = await requestDirectoryAuthorization()
        NSLog("[HookAutoInstaller] 授权结果: \(authorized)")
        
        if !authorized {
            return .failure(.permissionDenied("需要授权访问 ~/.claude 目录才能安装 Hook。"))
        }
        
        // 3. 验证写入权限
        let settingsPath = Self.claudeDirPath + "/settings.json"
        if fm.fileExists(atPath: settingsPath) {
            do {
                let testWrite = settingsPath + ".test"
                try "test".write(toFile: testWrite, atomically: true, encoding: .utf8)
                try fm.removeItem(atPath: testWrite)
                NSLog("[HookAutoInstaller] 目录写入权限验证通过")
            } catch {
                NSLog("[HookAutoInstaller] 写入测试失败: \(error.localizedDescription)")
                return .failure(.permissionDenied("无法写入 ~/.claude 目录。请确保已获得访问权限。"))
            }
        }
        
        NSLog("[HookAutoInstaller] checkAndFixPermissions 完成")
        return .success(())
    }
    
    /// 用管理员权限运行修复命令
    private func runPermissionFixCommand() async -> Bool {
        let userName = NSUserName()
        let claudeDir = NSString("~/.claude").expandingTildeInPath
        // AppleScript里双引号需要转义
        let script = """
        do shell script "mkdir -p '\(claudeDir)' && chown -R \(userName):staff '\(claudeDir)' && chmod -R 755 '\(claudeDir)' && chmod 644 '\(claudeDir)'/* 2>/dev/null || true" with administrator privileges
        """
        
        return await withCheckedContinuation { continuation in
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                continuation.resume(returning: false)
                return
            }
            
            let result = appleScript.executeAndReturnError(&error)
            if let error = error {
                Self.logger.error("权限修复失败: \(error.description)")
                // 如果执行失败，尝试使用更宽松的权限命令
                let fallbackScript = """
                do shell script "chmod -R 777 '\(claudeDir)'" with administrator privileges
                """
                if let fallbackAppleScript = NSAppleScript(source: fallbackScript) {
                    var fallbackError: NSDictionary?
                    _ = fallbackAppleScript.executeAndReturnError(&fallbackError)
                    if fallbackError == nil {
                        Self.logger.info("降级权限修复成功")
                        continuation.resume(returning: true)
                        return
                    }
                }
                continuation.resume(returning: false)
            } else {
                Self.logger.info("权限修复成功")
                continuation.resume(returning: true)
            }
        }
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

// MARK: - OpenCode 插件安装器

extension HookAutoInstaller {

    // MARK: - 常量

    /// OpenCode 插件目录
    static let opencodePluginDirectory = NSString("~/.config/opencode/plugins").expandingTildeInPath

    /// OpenCode 插件文件路径
    static let opencodePluginPath = opencodePluginDirectory + "/vibe-island.js"

    // MARK: - 公开属性

    /// OpenCode 插件是否已安装
    var isOpenCodePluginInstalled: Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.opencodePluginPath) else { return false }
        // 检查是否是我们的插件
        guard let content = try? String(contentsOfFile: Self.opencodePluginPath, encoding: .utf8) else { return false }
        return content.contains("vibe-island") || content.contains("vibeIsland")
    }

    /// OpenCode 是否已安装
    var isOpenCodeInstalled: Bool {
        detectOpenCodeInstallation()
    }

    // MARK: - 安装

    /// 安装 OpenCode 插件
    func installOpenCodePlugin() async -> OpenCodePluginResult {
        // 1. 检测 OpenCode
        guard isOpenCodeInstalled else {
            return .failure(.openCodeNotFound)
        }

        // 2. 确保插件目录存在
        let fm = FileManager.default
        if !fm.fileExists(atPath: Self.opencodePluginDirectory) {
            do {
                try fm.createDirectory(atPath: Self.opencodePluginDirectory, withIntermediateDirectories: true)
            } catch {
                return .failure(.createDirectoryFailed(error))
            }
        }

        // 3. 备份已有插件（如果存在）
        var backupPath: String?
        if fm.fileExists(atPath: Self.opencodePluginPath) {
            if isOpenCodePluginInstalled {
                // 已是我们的插件，提示覆盖
            } else {
                // 其他插件存在，报错
                return .failure(.pluginConflict)
            }
            backupPath = backupOpenCodePlugin()
        }

        // 4. 写入插件文件
        let pluginContent = Self.openCodePluginSource
        do {
            try pluginContent.write(toFile: Self.opencodePluginPath, atomically: true, encoding: .utf8)
        } catch {
            // 写入失败，尝试恢复
            if let backup = backupPath {
                try? restoreOpenCodePlugin(from: backup)
            }
            return .failure(.writePluginFailed(error))
        }

        Self.logger.info("OpenCode 插件安装成功: \(Self.opencodePluginPath)")
        return .success(backupPath: backupPath)
    }

    // MARK: - 卸载

    /// 卸载 OpenCode 插件
    func uninstallOpenCodePlugin() async -> OpenCodePluginResult {
        let fm = FileManager.default

        // 1. 检查插件是否存在
        guard fm.fileExists(atPath: Self.opencodePluginPath) else {
            return .failure(.pluginNotFound)
        }

        // 2. 检查是否是我们的插件
        guard isOpenCodePluginInstalled else {
            return .failure(.notOurPlugin)
        }

        // 3. 备份
        let backupPath = backupOpenCodePlugin()

        // 4. 删除插件
        do {
            try fm.removeItem(atPath: Self.opencodePluginPath)
        } catch {
            return .failure(.deletePluginFailed(error))
        }

        Self.logger.info("OpenCode 插件卸载成功")
        return .success(backupPath: backupPath)
    }

    // MARK: - 内部实现

    /// 检测 OpenCode 是否安装
    private func detectOpenCodeInstallation() -> Bool {
        let fm = FileManager.default

        // 方法 1: 检查常见安装路径
        let commonPaths = [
            "/usr/local/bin/opencode",
            "/opt/homebrew/bin/opencode",
            NSString("~/.local/bin/opencode").expandingTildeInPath,
            "/usr/bin/opencode",
            "/bin/opencode",
            NSString("~/.opencode/bin/opencode").expandingTildeInPath,
        ]
        for path in commonPaths {
            if fm.isExecutableFile(atPath: path) {
                Self.logger.debug("在常见路径找到 opencode 可执行文件: \(path)")
                return true
            }
        }

        // 方法 2: 运行 command -v opencode 检测
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v opencode"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let status = process.terminationStatus
            let outputData = try outputPipe.fileHandleForReading.readToEnd()
            let output = outputData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if status == 0 && !output.isEmpty {
                return true
            }
        } catch {
            Self.logger.error("运行检测命令失败: \(error.localizedDescription)")
        }

        return false
    }

    /// 备份 OpenCode 插件（可选，失败返回 nil）
    private func backupOpenCodePlugin() -> String? {
        let fm = FileManager.default
        let backupDir = Self.backupDirectory + "/opencode-plugins"

        do {
            try fm.createDirectory(atPath: backupDir, withIntermediateDirectories: true)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let timestamp = formatter.string(from: Date())
            let backupPath = backupDir + "/vibe-island-\(timestamp).js"

            try fm.copyItem(atPath: Self.opencodePluginPath, toPath: backupPath)
            return backupPath
        } catch {
            Self.logger.warning("OpenCode 插件备份跳过（沙盒限制）: \(error.localizedDescription)")
            return nil
        }
    }

    /// 从备份恢复 OpenCode 插件
    private func restoreOpenCodePlugin(from backupPath: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupPath) else { return }
        try fm.copyItem(atPath: backupPath, toPath: Self.opencodePluginPath)
    }

    // MARK: - OpenCode 插件源码

    /// OpenCode 插件源码（内联在 App 中）
    private static let openCodePluginSource = """
// vibe-island plugin for opencode
import { execFileSync } from "child_process";
import { existsSync, unlinkSync, readFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const sessionsDir = join(homedir(), ".vibe-island", "sessions");

const TOOL_NAME_MAP = {
  bash: "Bash", read: "Read", edit: "Edit", write: "Write",
  grep: "Grep", glob: "Glob", webfetch: "WebFetch", websearch: "WebSearch", task: "Task",
};
const KEY_MAP = { filePath: "file_path" };

function findHookBinary() {
  const candidates = [
    join(homedir(), ".vibe-island/bin/vibe-island"),
    "/Applications/VibeIsland.app/Contents/MacOS/vibe-island",
    join(homedir(), "Applications/VibeIsland.app/Contents/MacOS/vibe-island"),
    "/usr/local/bin/vibe-island", "/opt/homebrew/bin/vibe-island",
  ];
  for (const p of candidates) { if (existsSync(p)) return p; }
  return null;
}

function normalizeTool(name) {
  if (!name) return null;
  const lower = name.toLowerCase();
  if (TOOL_NAME_MAP[lower]) return TOOL_NAME_MAP[lower];
  return name.charAt(0).toUpperCase() + name.slice(1);
}

function normalizeToolInput(args) {
  if (!args || typeof args !== "object") return args;
  const result = {};
  for (const [k, v] of Object.entries(args)) {
    const mapped = KEY_MAP[k] || k;
    if (typeof v === "string") result[mapped] = v;
  }
  return result;
}

function callHook(hookBin, eventName, payload) {
  try {
    const json = JSON.stringify({ ...payload, hook_event_name: eventName });
    execFileSync(hookBin, ["hook", eventName], { input: json, timeout: 5000, stdio: ["pipe", "pipe", "pipe"] });
  } catch { /* Best-effort — never crash opencode */ }
}

function readModelContextLimit() {
  try {
    const configPath = join(homedir(), '.config', 'opencode', 'opencode.json');
    if (!existsSync(configPath)) return null;
    const config = JSON.parse(readFileSync(configPath, 'utf8'));
    if (config.provider) {
      for (const providerName of Object.keys(config.provider)) {
        const provider = config.provider[providerName];
        if (provider.models) {
          for (const modelId of Object.keys(provider.models)) {
            const model = provider.models[modelId];
            if (model.limit?.context) return model.limit.context;
          }
        }
      }
    }
    return null;
  } catch { return null; }
}

export const vibeIsland = async ({ directory }) => {
  const hookBin = findHookBinary();
  if (!hookBin) return {};
  const sessionId = `opencode-${process.pid}`;
  let sessionName = null;
  const defaultContextLimit = readModelContextLimit() || 200000;
  let modelContextLimit = defaultContextLimit;
  let toolCounts = {};
  let skillCounts = {};

  function basePayload() {
    return { session_id: sessionId, cwd: directory, source: "opencode", ...(sessionName && { session_name: sessionName }) };
  }

  function handleTokenUpdate(tokens, source) {
    if (!tokens) return;
    const inputTokens = tokens.input || 0;
    const outputTokens = tokens.output || 0;
    const reasoningTokens = tokens.reasoning || 0;
    const cacheRead = tokens.cache?.read || 0;
    const cacheWrite = tokens.cache?.write || 0;
    // cacheRead represents tokens retrieved from cache, not stored in context
    const totalTokens = inputTokens + outputTokens + reasoningTokens + cacheWrite;
    const usagePercent = modelContextLimit > 0 ? Math.round((totalTokens / modelContextLimit) * 100) : 0;
    const sortedToolUsage = Object.entries(toolCounts).sort((a, b) => b[1] - a[1]).map(([name, count]) => ({ name, count }));
    const sortedSkillUsage = Object.entries(skillCounts).sort((a, b) => b[1] - a[1]).map(([name, count]) => ({ name, count }));
    const contextMsg = `Context usage: ${usagePercent}% (${totalTokens}/${modelContextLimit} tokens)`;
    callHook(hookBin, "ContextUpdate", {
      ...basePayload(), message: contextMsg,
      context_usage: usagePercent / 100, context_tokens_used: totalTokens, context_tokens_total: modelContextLimit,
      context_input_tokens: inputTokens, context_output_tokens: outputTokens, context_reasoning_tokens: reasoningTokens,
      tool_usage: sortedToolUsage, skill_usage: sortedSkillUsage,
    });
  }

  function checkRefreshFile() {
    const refreshFile = join(sessionsDir, `${sessionId}.refresh`);
    if (existsSync(refreshFile)) {
      try { unlinkSync(refreshFile); } catch {}
      callHook(hookBin, "RefreshContext", basePayload());
    }
  }

  callHook(hookBin, "SessionStart", basePayload());

  return {
    "chat.params": async ({ params }) => {
      if (params?.model?.limit?.context) modelContextLimit = params.model.limit.context;
    },
    event: async ({ event }) => {
      if (!event || !event.type) return;
      switch (event.type) {
        case "session.created":
          modelContextLimit = defaultContextLimit;
          toolCounts = {};
          skillCounts = {};
          callHook(hookBin, "SessionStart", basePayload());
          break;
        case "session.idle": callHook(hookBin, "Stop", basePayload()); break;
        case "session.error": {
          const errMsg = event.error?.message || event.message || null;
          callHook(hookBin, "SessionError", { ...basePayload(), ...(errMsg && { error: errMsg }), ...(event.message && { message: event.message }) });
          break;
        }
        case "session.status": {
          const type = event.properties?.status?.type || event.properties?.type || event.status?.type;
          if (type === "retry") callHook(hookBin, "SessionError", { ...basePayload(), error: "Retry" });
          break;
        }
        case "session.updated": { const t = event.properties?.info?.title; if (t) sessionName = t; break; }
        case "session.compacted":
          checkRefreshFile();
          callHook(hookBin, "PostCompact", basePayload());
          break;
        case "session.deleted":
        case "permission.replied":
          break;
      }
      checkRefreshFile();
    },
    "message.part.updated": async ({ part }) => {
      if (!part || part.type !== "step-finish") return;
      handleTokenUpdate(part.tokens, 'message.part.updated');
    },
    "message.updated": async ({ message }) => {
      if (!message) return;
      handleTokenUpdate(message.tokens, 'message.updated');
    },
    "chat.complete": async (_input, output) => {
      const message = output?.message;
      if (!message) return;
      handleTokenUpdate(message.tokens, 'chat.complete');
    },
    "chat.message": async (_input, output) => {
      const prompt = output?.message?.content || output?.content || (typeof output?.text === "string" ? output.text : null);
      callHook(hookBin, "UserPromptSubmit", { ...basePayload(), ...(prompt && { prompt }) });
    },
    "tool.execute.before": async (_input, output) => {
      const tool = normalizeTool(output?.tool || _input?.tool);
      const args = output?.args || _input?.args;
      if (tool) toolCounts[tool] = (toolCounts[tool] || 0) + 1;
      callHook(hookBin, "PreToolUse", { ...basePayload(), ...(tool && { tool_name: tool }), ...(args && { tool_input: normalizeToolInput(args) }) });
    },
    "tool.execute.after": async (_input, output) => {
      const tool = normalizeTool(output?.tool || _input?.tool);
      callHook(hookBin, "PostToolUse", { ...basePayload(), ...(tool && { tool_name: tool }) });
    },
    "skill.execute.before": async (_input, output) => {
      const skill = output?.skill || _input?.skill;
      if (skill) skillCounts[skill] = (skillCounts[skill] || 0) + 1;
    },
    "permission.ask": async (input) => {
      const tool = normalizeTool(input?.tool);
      const args = input?.args;
      callHook(hookBin, "PermissionRequest", { ...basePayload(), ...(tool && { tool_name: tool }), ...(input?.title && { title: input.title }), ...(args && { tool_input: normalizeToolInput(args) }) });
    },
    "experimental.session.compacting": async () => { callHook(hookBin, "PreCompact", basePayload()); },
  };
};
"""
}

// MARK: - OpenCode 插件结果类型

enum OpenCodePluginResult {
    case success(backupPath: String?)
    case failure(OpenCodePluginError)
}

enum OpenCodePluginError: LocalizedError {
    case openCodeNotFound
    case createDirectoryFailed(Error)
    case pluginConflict
    case writePluginFailed(Error)
    case pluginNotFound
    case notOurPlugin
    case deletePluginFailed(Error)

    var errorDescription: String? {
        switch self {
        case .openCodeNotFound:
            return "未检测到 OpenCode，请先安装 OpenCode"
        case .createDirectoryFailed(let error):
            return "创建插件目录失败: \(error.localizedDescription)"
        case .pluginConflict:
            return "该位置已存在其他插件，请先移除后再安装"
        case .writePluginFailed(let error):
            return "写入插件文件失败: \(error.localizedDescription)"
        case .pluginNotFound:
            return "插件文件不存在"
        case .notOurPlugin:
            return "该插件不是由 Vibe Island 安装的"
        case .deletePluginFailed(let error):
            return "删除插件失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - 数据模型

/// Claude Code 配置结构
struct ClaudeSettings: Codable {
    var hooks: [String: [HookRule]]?
    var disableAllHooks: Bool?
    var allowManagedHooksOnly: Bool?
    var env: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case hooks
        case disableAllHooks
        case allowManagedHooksOnly
        case env
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
    case success(backupPath: String?)
    case failure(HookError)
}

/// 卸载结果
enum UninstallResult {
    case success(backupPath: String?)
    case failure(HookError)
}

/// Hook 错误类型
enum HookError: LocalizedError, Identifiable {
    var id: String { errorDescription ?? "" }
    case claudeCodeNotFound
    case settingsNotFound
    case notInstalled
    case configNotFound
    case backupFailed(Error)
    case writeFailed(Error)
    case backupNotFound(String)
    case rollbackFailed(Error)
    case permissionDenied(String)

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
        case .permissionDenied(let reason):
            return String(format: NSLocalizedString("hook.error.permissionDenied", value: "权限不足: %@", comment: ""), reason)
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
        case .permissionDenied:
            return NSLocalizedString("hook.recovery.permissionDenied", value: "✅ 自动修复说明：\n点击「确定」会自动请求管理员权限修复目录权限\n❌ 自动修复失败？按以下步骤操作：\n1. 打开「系统设置→隐私与安全性→完全磁盘访问」\n2. 点击+号添加Vibe Island并打开开关\n3. 重启App后重新安装即可\n4. 手动修复命令：sudo chown -R $(whoami):staff ~/.claude && chmod -R 755 ~/.claude", comment: "")
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
        case (.permissionDenied, .permissionDenied): return true
        default: return false
        }
    }
}
