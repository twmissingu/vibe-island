import Foundation
import OSLog

// MARK: - 阈值常量

/// OpenCode 数据库路径
let openCodeDatabasePath: URL = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".local/share/opencode/opencode.db")
}()

/// 警告阈值：上下文使用率超过此值时发出橙色警告
let contextWarningThreshold: Double = 0.80

/// 危险阈值：上下文使用率超过此值时发出红色警告
let contextCriticalThreshold: Double = 0.95

// MARK: - 上下文使用快照

/// 单次上下文使用情况的快照数据
/// 由 ExpandedIslandView 直接从 Session 模型构建，ContextMonitor 不再维护快照存储
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
        Int((usageRatio * 100).rounded())
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

/// OpenCode 上下文数据读取服务
///
/// 职责：
/// 1. 从 OpenCode SQLite 数据库读取 token 使用量
/// 2. 检测 OpenCode 压缩事件
///
/// Claude Code 的上下文数据由 CLI 写入 Session 文件，App 端直接从 Session 模型读取，
/// 不需要经过 ContextMonitor 中转。
@MainActor
@Observable
final class ContextMonitor {
    // MARK: 单例

    static let shared = ContextMonitor()

    // MARK: 内部状态

    /// 已处理的压缩事件时间戳（sessionId -> compactionTime）
    private var processedCompactions: [String: Int64] = [:]

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "ContextMonitor"
    )

    // MARK: 初始化

    private init() {}

    // MARK: 生命周期

    func start() {
        Self.logger.info("ContextMonitor 已启动")
    }

    func stop() {
        processedCompactions.removeAll()
        Self.logger.info("ContextMonitor 已停止")
    }

    // MARK: - OpenCode 数据库读取
    // 注意：runSQL / getOpenCodeModelContextLimit 与 HookHandler.swift 中的实现重复。
    // CLI 和 App 是独立 target，无法直接共享代码。如需修改请同步两处。

    /// OpenCode 数据库读取到的上下文数据
    struct OpenCodeContextData {
        let usage: Double
        let tokensUsed: Int
        let tokensTotal: Int?
        let inputTokens: Int
        let outputTokens: Int
        let reasoningTokens: Int
    }

    /// 获取 OpenCode 模型的上下文窗口大小
    nonisolated private func getOpenCodeModelContextLimit(cwd: String) async -> Int {
        let configPath = NSHomeDirectory() + "/.config/opencode/opencode.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let provider = json["provider"] as? [String: Any] else { return 200000 }

        // 从数据库获取当前使用的 provider 和 model
        let findSessionSQL = """
            SELECT id FROM session WHERE directory = '\(Self.escapeSQL(cwd))' ORDER BY time_updated DESC LIMIT 1;
            """
        guard let sessionIdResult = await Self.runSQL(findSessionSQL), !sessionIdResult.isEmpty else {
            return getDefaultContextLimit(provider: provider)
        }
        let ocSessionId = sessionIdResult.trimmingCharacters(in: .whitespacesAndNewlines)

        let modelSQL = """
            SELECT json_extract(data, '$.providerID'), json_extract(data, '$.modelID')
            FROM message WHERE session_id = '\(Self.escapeSQL(ocSessionId))'
            AND json_extract(data, '$.providerID') IS NOT NULL
            ORDER BY time_updated DESC LIMIT 1;
            """

        if let modelResult = await Self.runSQL(modelSQL), !modelResult.isEmpty {
            let parts = modelResult.components(separatedBy: "|")
            if parts.count >= 2 {
                let providerID = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let modelID = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

                // 查找匹配的 provider 和 model
                if let providerDict = provider[providerID] as? [String: Any],
                   let models = providerDict["models"] as? [String: Any],
                   let modelDict = models[modelID] as? [String: Any],
                   let limit = modelDict["limit"] as? [String: Any],
                   let context = limit["context"] as? Int {
                    return context
                }
            }
        }

        return getDefaultContextLimit(provider: provider)
    }

    /// 获取默认的上下文窗口大小（遍历所有 provider 找到第一个有效的）
    nonisolated private func getDefaultContextLimit(provider: [String: Any]) -> Int {
        for (_, providerConfig) in provider {
            guard let providerDict = providerConfig as? [String: Any],
                  let models = providerDict["models"] as? [String: Any] else { continue }
            for (_, model) in models {
                guard let modelDict = model as? [String: Any],
                      let limit = modelDict["limit"] as? [String: Any],
                      let context = limit["context"] as? Int else { continue }
                return context
            }
        }
        return 200000
    }

    /// 检查 OpenCode 压缩状态（由文件监听触发）
    func checkOpenCodeCompaction(sessionId: String, cwd: String) async {
        guard FileManager.default.fileExists(atPath: openCodeDatabasePath.path) else { return }

        // 从 messages 表检测压缩事件
        let sql = """
            SELECT m.time_created, m.data FROM message m
            JOIN session s ON m.session_id = s.id
            WHERE s.directory = '\(Self.escapeSQL(cwd))'
            AND json_extract(m.data, '$.mode') = 'compaction'
            ORDER BY m.time_updated DESC LIMIT 1;
            """

        guard let result = await Self.runSQL(sql), !result.isEmpty else { return }

        // 解析时间戳
        let lines = result.components(separatedBy: "|")
        guard let timeCreated = Int64(lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""), timeCreated > 0 else { return }

        // 检查是否已处理过此压缩事件
        if let lastProcessed = processedCompactions[sessionId], lastProcessed >= timeCreated {
            return
        }

        // 记录已处理的压缩时间
        processedCompactions[sessionId] = timeCreated

        SessionManager.shared.handleOpenCodeCompaction(sessionId: sessionId, compactionTime: timeCreated)
    }

    /// 从 OpenCode 数据库读取会话的 token 使用量
    /// - Returns: 解析出的上下文数据，无数据时返回 nil
    nonisolated func fetchContextUsageFromOpenCodeDB(cwd: String) async -> OpenCodeContextData? {
        guard FileManager.default.fileExists(atPath: openCodeDatabasePath.path) else { return nil }

        // 查找匹配的 session（通过 cwd 匹配 directory）
        let findSessionSQL = """
            SELECT id FROM session WHERE directory = '\(Self.escapeSQL(cwd))' ORDER BY time_updated DESC LIMIT 1;
            """

        guard let sessionIdResult = await Self.runSQL(findSessionSQL), !sessionIdResult.isEmpty else { return nil }
        let ocSessionId = sessionIdResult.trimmingCharacters(in: .whitespacesAndNewlines)

        // 取最后一条有 token 数据的消息的 total（累计值，不是求和）
        let tokenSQL = """
            SELECT
                json_extract(data, '$.tokens.total') as total,
                json_extract(data, '$.tokens.input') as input,
                json_extract(data, '$.tokens.output') as output,
                json_extract(data, '$.tokens.reasoning') as reasoning
            FROM message
            WHERE session_id = '\(Self.escapeSQL(ocSessionId))'
            AND json_extract(data, '$.tokens.total') > 0
            ORDER BY time_updated DESC LIMIT 1;
            """

        guard let tokenResult = await Self.runSQL(tokenSQL), !tokenResult.isEmpty else { return nil }

        let tokenLines = tokenResult.components(separatedBy: "|")
        guard tokenLines.count >= 4,
              let totalTokens = Int(tokenLines[0]),
              totalTokens > 0 else { return nil }

        let inputTokens = Int(tokenLines[1]) ?? 0
        let outputTokens = Int(tokenLines[2]) ?? 0
        let reasoningTokens = Int(tokenLines[3]) ?? 0

        let modelLimit = await getOpenCodeModelContextLimit(cwd: cwd)
        let usage = modelLimit > 0 ? Double(totalTokens) / Double(modelLimit) : 0

        return OpenCodeContextData(
            usage: usage,
            tokensUsed: totalTokens,
            tokensTotal: modelLimit > 0 ? modelLimit : nil,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            reasoningTokens: reasoningTokens
        )
    }

    // MARK: - SQL 工具方法

    /// 转义 SQLite 字符串中的特殊字符
    nonisolated private static func escapeSQL(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "''")
            .replacingOccurrences(of: "\"", with: "\"\"")
    }

    /// 运行 SQL 查询并返回结果（在后台线程执行，不阻塞主线程）
    nonisolated private static func runSQL(_ sql: String) async -> String? {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
            process.arguments = [openCodeDatabasePath.path, sql]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)
            } catch {
                return nil
            }
        }.value
    }
}
