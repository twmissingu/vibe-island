import Foundation
import OSLog

// MARK: - 阈值常量

/// 警告阈值：上下文使用率超过此值时发出橙色警告
let contextWarningThreshold: Double = 0.80

/// 危险阈值：上下文使用率超过此值时发出红色警告
let contextCriticalThreshold: Double = 0.95

// MARK: - 解析后的上下文数据

/// 从 notificationMessage 解析出的上下文数据，用于回写 Session 模型
struct ParsedContextData: Sendable {
    let usage: Double
    let tokensUsed: Int?
    let tokensTotal: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let reasoningTokens: Int?
}

// MARK: - 上下文使用快照

/// 单次上下文使用情况的快照数据
struct ContextUsageSnapshot: Equatable, Sendable {
    /// 会话 ID
    let sessionId: String
    /// 上下文使用率 (0.0 - 1.0)
    let usageRatio: Double
    /// 已使用的 token 数
    let tokensUsed: Int?
    /// 总 token 上限
    let tokensTotal: Int?
    /// 输入 token 数
    let inputTokens: Int?
    /// 输出 token 数
    let outputTokens: Int?
    /// 思考 token 数
    let reasoningTokens: Int?
    /// 工具使用列表
    let toolUsage: [ToolUsage]?
    /// 技能使用列表
    let skillUsage: [ToolUsage]?
    /// 快照时间
    let timestamp: Date

    init(
        sessionId: String,
        usageRatio: Double,
        tokensUsed: Int? = nil,
        tokensTotal: Int? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        toolUsage: [ToolUsage]? = nil,
        skillUsage: [ToolUsage]? = nil,
        timestamp: Date = Date()
    ) {
        self.sessionId = sessionId
        self.usageRatio = usageRatio
        self.tokensUsed = tokensUsed
        self.tokensTotal = tokensTotal
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.toolUsage = toolUsage
        self.skillUsage = skillUsage
        self.timestamp = timestamp
    }

    /// 使用率百分比 (0 - 100)
    var usagePercent: Int {
        Int(usageRatio * 100)
    }

    /// 剩余 token 估算
    var tokensRemaining: Int? {
        guard let total = tokensTotal, let used = tokensUsed else { return nil }
        return max(0, total - used)
    }

    /// 是否超过警告阈值
    var isWarning: Bool {
        usageRatio >= contextWarningThreshold
    }

    /// 是否超过危险阈值
    var isCritical: Bool {
        usageRatio >= contextCriticalThreshold
    }
}

// MARK: - 上下文监控服务

/// 监控 Claude Code 的上下文使用情况
///
/// 工作原理：
/// 1. 监听 `SessionFileWatcher` 发出的会话更新事件
/// 2. 从 PreCompact 事件的 message 字段中解析上下文使用率
/// 3. 当上下文使用率超过阈值时发出警告通知
///
/// PreCompact 事件 message 格式示例：
/// "Context usage: 85% (170000/200000 tokens)"
@MainActor
@Observable
final class ContextMonitor {
    // MARK: 单例

    static let shared = ContextMonitor()

    // MARK: 公开状态

    /// 所有会话的上下文使用快照
    private(set) var snapshots: [String: ContextUsageSnapshot] = [:]

    /// 获取指定会话的上下文快照
    func snapshot(for sessionId: String) -> ContextUsageSnapshot? {
        snapshots[sessionId]
    }

    /// 最高优先级的上下文使用快照（用于 UI 展示）
    var topSnapshot: ContextUsageSnapshot? {
        snapshots.values
            .filter { $0.usageRatio > 0 }
            .max { $0.usageRatio < $1.usageRatio }
    }

    /// 是否有任何会话超过警告阈值
    var hasWarning: Bool {
        snapshots.values.contains { $0.isWarning }
    }

    /// 是否有任何会话超过危险阈值
    var hasCritical: Bool {
        snapshots.values.contains { $0.isCritical }
    }

    /// 是否有需要闪烁警告的会话
    var shouldFlashWarning: Bool {
        hasWarning
    }

    // MARK: 内部状态

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twissingu.VibeIsland",
        category: "ContextMonitor"
    )

    // MARK: 正则表达式

    /// 匹配 PreCompact message 中的上下文使用率
    /// 格式: "Context usage: 85% (170000/200000 tokens)"
    /// 或: "上下文使用: 85% (170000/200000 tokens)"
    private static let usagePattern = try? NSRegularExpression(
        pattern: #"(?:Context usage|上下文使用)\s*:\s*(\d+(?:\.\d+)?)\s*%\s*(?:\((\d+)\s*/\s*(\d+)\s*tokens?\))?"#,
        options: .caseInsensitive
    )

    // MARK: 初始化

    private init() {}

    // MARK: 生命周期

    /// 启动监控
    func start() {
        Self.logger.info("ContextMonitor 已启动")
    }

    /// 停止监控
    func stop() {
        snapshots.removeAll()
        Self.logger.info("ContextMonitor 已停止")
    }

    // MARK: 事件处理

    /// 处理会话更新事件（由 SessionManager.updateSession 调用）
    ///
    /// - 返回: 如果从 notificationMessage 解析出了上下文数据，返回 `ParsedContextData` 供调用方回写 Session 模型；
    ///         如果 Session 模型本身已有 contextUsage 或无数据可解析，返回 nil。
    @discardableResult
    func handleSessionUpdate(_ session: Session) -> ParsedContextData? {
        // 路径 A: 从 notificationMessage 解析（PreCompact 事件的 "Context usage: 85% (...)" 格式）
        if let message = session.notificationMessage {
            if let snapshot = parseContextUsage(from: message, sessionId: session.sessionId) {
                let updatedSnapshot = ContextUsageSnapshot(
                    sessionId: snapshot.sessionId,
                    usageRatio: snapshot.usageRatio,
                    tokensUsed: snapshot.tokensUsed,
                    tokensTotal: snapshot.tokensTotal,
                    inputTokens: snapshot.inputTokens,
                    outputTokens: snapshot.outputTokens,
                    reasoningTokens: snapshot.reasoningTokens,
                    toolUsage: session.toolUsage,
                    skillUsage: session.skillUsage,
                    timestamp: session.lastActivity
                )
                updateSnapshot(sessionId: session.sessionId, snapshot: updatedSnapshot)

                // 返回解析数据，由调用方回写 Session 模型
                return ParsedContextData(
                    usage: updatedSnapshot.usageRatio,
                    tokensUsed: updatedSnapshot.tokensUsed,
                    tokensTotal: updatedSnapshot.tokensTotal,
                    inputTokens: updatedSnapshot.inputTokens,
                    outputTokens: updatedSnapshot.outputTokens,
                    reasoningTokens: updatedSnapshot.reasoningTokens
                )
            }
        }

        // 路径 B: Session 模型已有 contextUsage，同步到快照
        if let usage = session.contextUsage {
            let snapshot = ContextUsageSnapshot(
                sessionId: session.sessionId,
                usageRatio: usage,
                tokensUsed: session.contextTokensUsed,
                tokensTotal: session.contextTokensTotal,
                inputTokens: session.contextInputTokens,
                outputTokens: session.contextOutputTokens,
                reasoningTokens: session.contextReasoningTokens,
                toolUsage: session.toolUsage,
                skillUsage: session.skillUsage,
                timestamp: session.lastActivity
            )
            updateSnapshot(sessionId: session.sessionId, snapshot: snapshot)
        }

        return nil
    }

    /// 手动设置会话的上下文使用情况
    func setContextUsage(
        sessionId: String,
        usage: Double,
        tokensUsed: Int? = nil,
        tokensTotal: Int? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        toolUsage: [ToolUsage]? = nil,
        skillUsage: [ToolUsage]? = nil
    ) {
        let snapshot = ContextUsageSnapshot(
            sessionId: sessionId,
            usageRatio: max(0, min(1, usage)),
            tokensUsed: tokensUsed,
            tokensTotal: tokensTotal,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            reasoningTokens: reasoningTokens,
            toolUsage: toolUsage,
            skillUsage: skillUsage,
            timestamp: Date()
        )
        updateSnapshot(sessionId: sessionId, snapshot: snapshot)
    }
    
    /// 会话文件索引（sessionId → fileURL），批量查询时使用
    typealias SessionFileIndex = [String: URL]

    /// 构建 sessionId → fileURL 索引（读取一次目录，供多次查询复用）
    func buildSessionFileIndex() -> SessionFileIndex {
        let sessionsDir = SessionFileWatcher.sessionsDirectory
        var index: SessionFileIndex = [:]
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else { return index }
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }
            guard let data = try? Data(contentsOf: fileURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let sid = json["session_id"] as? String {
                index[sid] = fileURL
            } else if let pid = json["pid"] as? Int {
                index[String(pid)] = fileURL
            }
        }
        return index
    }

    /// 使用索引查询（O(1) 查找，批量场景使用）
    func fetchContextUsageFromFile(sessionId: String, index: SessionFileIndex) {
        // 先尝试直接匹配
        if let fileURL = index[sessionId] {
            parseAndSetContext(from: fileURL, sessionId: sessionId)
            return
        }
        // 回退：遍历索引做 contains 匹配
        for (key, fileURL) in index {
            if key.contains(sessionId) || sessionId.contains(key) {
                parseAndSetContext(from: fileURL, sessionId: sessionId)
                return
            }
        }
    }

    /// 从会话文件直接获取 context_usage（单次查询，遍历目录）
    func fetchContextUsageFromFile(sessionId: String) {
        let sessionsDir = SessionFileWatcher.sessionsDirectory

        // 查找匹配的 session 文件（pid 或 session_id）
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else { return }
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }
            
            do {
                let data = try Data(contentsOf: fileURL)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                
                // 检查 session_id 匹配
                let fileSessionId = json["session_id"] as? String
                let filePid = json["pid"] as? Int
                
                let matches: Bool
                if let fsId = fileSessionId {
                    matches = fsId == sessionId || fsId.contains(sessionId)
                } else if let pid = filePid {
                    let opencodeId = "opencode-\(pid)"
                    matches = String(pid) == sessionId || sessionId.hasPrefix("opencode-") && opencodeId == sessionId
                } else {
                    matches = false
                }
                
                guard matches else { continue }
                
                // 提取 context_usage
                if let usage = json["context_usage"] as? Double {
                    let tokensUsed = json["context_tokens_used"] as? Int
                    let tokensTotal = json["context_tokens_total"] as? Int
                    let inputTokens = json["context_input_tokens"] as? Int
                    let outputTokens = json["context_output_tokens"] as? Int
                    let reasoningTokens = json["context_reasoning_tokens"] as? Int
                    let toolUsageRaw = json["tool_usage"] as? [[String: Any]]
                    let toolUsage = toolUsageRaw?.compactMap { dict -> ToolUsage? in
                        guard let name = dict["name"] as? String, let count = dict["count"] as? Int else { return nil }
                        return ToolUsage(name: name, count: count)
                    }
                    let skillUsageRaw = json["skill_usage"] as? [[String: Any]]
                    let skillUsage = skillUsageRaw?.compactMap { dict -> ToolUsage? in
                        guard let name = dict["name"] as? String, let count = dict["count"] as? Int else { return nil }
                        return ToolUsage(name: name, count: count)
                    }
                    
                    setContextUsage(
                        sessionId: sessionId,
                        usage: usage,
                        tokensUsed: tokensUsed,
                        tokensTotal: tokensTotal,
                        inputTokens: inputTokens,
                        outputTokens: outputTokens,
                        reasoningTokens: reasoningTokens,
                        toolUsage: toolUsage,
                        skillUsage: skillUsage
                    )
                    Self.logger.debug("从文件获取上下文 usage: \(sessionId) = \(usage)")
                    return
                }
                
                // 回退：从 notificationMessage 解析
                if let message = json["notification_message"] as? String {
                    if let snapshot = parseContextUsage(from: message, sessionId: sessionId) {
                        updateSnapshot(sessionId: sessionId, snapshot: snapshot)
                        Self.logger.debug("从 notificationMessage 解析上下文: \(sessionId) = \(snapshot.usagePercent)%")
                        return
                    }
                }
                
            } catch {
                continue
            }
        }
    }

    /// 从单个文件解析并设置上下文数据
    private func parseAndSetContext(from fileURL: URL, sessionId: String) {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let usage = json["context_usage"] as? Double {
            let tokensUsed = json["context_tokens_used"] as? Int
            let tokensTotal = json["context_tokens_total"] as? Int
            let inputTokens = json["context_input_tokens"] as? Int
            let outputTokens = json["context_output_tokens"] as? Int
            let reasoningTokens = json["context_reasoning_tokens"] as? Int
            let toolUsageRaw = json["tool_usage"] as? [[String: Any]]
            let toolUsage = toolUsageRaw?.compactMap { dict -> ToolUsage? in
                guard let name = dict["name"] as? String, let count = dict["count"] as? Int else { return nil }
                return ToolUsage(name: name, count: count)
            }
            let skillUsageRaw = json["skill_usage"] as? [[String: Any]]
            let skillUsage = skillUsageRaw?.compactMap { dict -> ToolUsage? in
                guard let name = dict["name"] as? String, let count = dict["count"] as? Int else { return nil }
                return ToolUsage(name: name, count: count)
            }
            setContextUsage(
                sessionId: sessionId, usage: usage,
                tokensUsed: tokensUsed, tokensTotal: tokensTotal,
                inputTokens: inputTokens, outputTokens: outputTokens,
                reasoningTokens: reasoningTokens, toolUsage: toolUsage,
                skillUsage: skillUsage
            )
            return
        }
        if let message = json["notification_message"] as? String,
           let snapshot = parseContextUsage(from: message, sessionId: sessionId) {
            updateSnapshot(sessionId: sessionId, snapshot: snapshot)
        }
    }

    /// 清除指定会话的上下文快照
    func clearSnapshot(for sessionId: String) {
        snapshots.removeValue(forKey: sessionId)
    }

    /// 清除所有快照
    func clearAll() {
        snapshots.removeAll()
    }

    // MARK: 私有方法

    /// 从 PreCompact 事件的 message 中解析上下文使用信息
    private func parseContextUsage(from message: String, sessionId: String) -> ContextUsageSnapshot? {
        guard let regex = Self.usagePattern else { return nil }

        let nsString = message as NSString
        let range = NSRange(location: 0, length: nsString.length)

        guard let match = regex.firstMatch(in: message, options: [], range: range) else {
            return nil
        }

        // 提取使用率百分比
        guard let percentRange = Range(match.range(at: 1), in: message),
              let percent = Double(message[percentRange])
        else { return nil }

        let usageRatio = percent / 100.0

        // 提取 token 数据（如果有）
        var tokensUsed: Int?
        var tokensTotal: Int?

        if let usedRange = Range(match.range(at: 2), in: message),
           let used = Int(message[usedRange]) {
            tokensUsed = used
        }

        if let totalRange = Range(match.range(at: 3), in: message),
           let total = Int(message[totalRange]) {
            tokensTotal = total
        }

        return ContextUsageSnapshot(
            sessionId: sessionId,
            usageRatio: usageRatio,
            tokensUsed: tokensUsed,
            tokensTotal: tokensTotal
        )
    }

    /// 更新内部快照缓存
    private func updateSnapshot(sessionId: String, snapshot: ContextUsageSnapshot) {
        snapshots[sessionId] = snapshot

        // 记录警告日志
        if snapshot.isCritical {
            Self.logger.warning(
                "会话 \(sessionId) 上下文使用率过高: \(snapshot.usagePercent)% (危险)"
            )
        } else if snapshot.isWarning {
            Self.logger.info(
                "会话 \(sessionId) 上下文使用率较高: \(snapshot.usagePercent)% (警告)"
            )
        }
    }

}
