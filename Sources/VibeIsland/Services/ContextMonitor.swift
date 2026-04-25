import Foundation
import OSLog

// MARK: - 阈值常量

/// 警告阈值：上下文使用率超过此值时发出橙色警告
let contextWarningThreshold: Double = 0.80

/// 危险阈值：上下文使用率超过此值时发出红色警告
let contextCriticalThreshold: Double = 0.95

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
    /// 快照时间
    let timestamp: Date

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

    /// 处理会话更新事件（由 SessionFileWatcher 回调触发）
    func handleSessionUpdate(_ session: Session) {
        // 尝试从 session 的 notificationMessage 中解析上下文使用率
        // 这通常在 PreCompact 事件时被设置
        if let message = session.notificationMessage {
            if let snapshot = parseContextUsage(from: message, sessionId: session.sessionId) {
                updateSnapshot(sessionId: session.sessionId, snapshot: snapshot)

                // 同步更新 Session 模型的上下文属性
                updateSessionContext(session, snapshot: snapshot)
                return
            }
        }

        // 如果 session 模型已有上下文数据，也同步到快照
        if let usage = session.contextUsage {
            let snapshot = ContextUsageSnapshot(
                sessionId: session.sessionId,
                usageRatio: usage,
                tokensUsed: session.contextTokensUsed,
                tokensTotal: session.contextTokensTotal,
                timestamp: session.lastActivity
            )
            updateSnapshot(sessionId: session.sessionId, snapshot: snapshot)
        }
    }

    /// 手动设置会话的上下文使用情况
    func setContextUsage(
        sessionId: String,
        usage: Double,
        tokensUsed: Int? = nil,
        tokensTotal: Int? = nil
    ) {
        let snapshot = ContextUsageSnapshot(
            sessionId: sessionId,
            usageRatio: max(0, min(1, usage)),
            tokensUsed: tokensUsed,
            tokensTotal: tokensTotal,
            timestamp: Date()
        )
        updateSnapshot(sessionId: sessionId, snapshot: snapshot)
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
            tokensTotal: tokensTotal,
            timestamp: Date()
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

    /// 更新 Session 模型的上下文属性
    private func updateSessionContext(_ session: Session, snapshot: ContextUsageSnapshot) {
        // 通过 SessionManager 更新（因为 session 是值类型）
        // 这里直接记录日志，实际更新由调用方通过 SessionFileWatcher 完成
        Self.logger.debug(
            "更新会话 \(session.sessionId) 上下文: \(snapshot.usagePercent)%, tokens: \(snapshot.tokensUsed?.description ?? "n/a")/\(snapshot.tokensTotal?.description ?? "n/a")"
        )
    }
}
