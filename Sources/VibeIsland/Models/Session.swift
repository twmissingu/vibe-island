import Foundation

// MARK: - 会话数据模型

/// 单个会话完整数据模型，支持从 JSON 文件读写
struct Session: Codable, Equatable, Sendable {
    // MARK: 核心字段

    /// 会话唯一标识
    let sessionId: String
    /// 当前工作目录
    let cwd: String

    // MARK: 状态

    /// 当前会话状态
    var status: SessionState
    /// 最后活动时间
    var lastActivity: Date

    // MARK: 上下文信息

    /// Git 分支名（如果可用）
    var branch: String?
    /// 来源标识
    var source: String?
    /// 会话名称
    var sessionName: String?

    // MARK: 最后操作快照

    /// 最后使用的工具名
    var lastTool: String?
    /// 最后工具调用的详细输入（JSON 字符串）
    var lastToolDetail: String?
    /// 最后一条用户提示
    var lastPrompt: String?
    /// 当前通知消息
    var notificationMessage: String?

    // MARK: 子代理

    /// 活跃的子代理列表
    var activeSubagents: [SubagentInfo]

    // MARK: PID 追踪（CLI 写入，用于进程检测和会话清理）

    /// 父进程 ID
    var pid: UInt32?
    /// 父进程启动时间（用于检测 PID 复用）
    var pidStartTime: TimeInterval?

    // MARK: 上下文使用信息（由 ContextMonitor 解析 PreCompact 事件填充）

    /// 上下文使用率 (0.0 - 1.0)
    var contextUsage: Double?
    /// 已使用的上下文 token 数
    var contextTokensUsed: Int?
    /// 总上下文 token 上限
    var contextTokensTotal: Int?

    // MARK: 文件路径

    /// 对应的 JSON 文件路径
    var fileURL: URL?

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case status
        case lastActivity = "last_activity"
        case branch
        case source
        case sessionName = "session_name"
        case lastTool = "last_tool"
        case lastToolDetail = "last_tool_detail"
        case lastPrompt = "last_prompt"
        case notificationMessage = "notification_message"
        case activeSubagents = "active_subagents"
        case pid
        case pidStartTime = "pid_start_time"
        case contextUsage = "context_usage"
        case contextTokensUsed = "context_tokens_used"
        case contextTokensTotal = "context_tokens_total"
    }

    init(
        sessionId: String,
        cwd: String,
        status: SessionState = .idle,
        lastActivity: Date = Date(),
        branch: String? = nil,
        source: String? = nil,
        sessionName: String? = nil,
        lastTool: String? = nil,
        lastToolDetail: String? = nil,
        lastPrompt: String? = nil,
        notificationMessage: String? = nil,
        activeSubagents: [SubagentInfo] = [],
        pid: UInt32? = nil,
        pidStartTime: TimeInterval? = nil,
        contextUsage: Double? = nil,
        contextTokensUsed: Int? = nil,
        contextTokensTotal: Int? = nil,
        fileURL: URL? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.status = status
        self.lastActivity = lastActivity
        self.branch = branch
        self.source = source
        self.sessionName = sessionName
        self.lastTool = lastTool
        self.lastToolDetail = lastToolDetail
        self.lastPrompt = lastPrompt
        self.notificationMessage = notificationMessage
        self.activeSubagents = activeSubagents
        self.pid = pid
        self.pidStartTime = pidStartTime
        self.contextUsage = contextUsage
        self.contextTokensUsed = contextTokensUsed
        self.contextTokensTotal = contextTokensTotal
        self.fileURL = fileURL
    }

    // MARK: 事件处理

    /// 根据 hook 事件更新会话状态
    mutating func applyEvent(_ event: SessionEvent) {
        lastActivity = event.receivedAt

        // 状态转换
        status = SessionState.transition(from: status, event: event.hookEventName)

        // 更新上下文
        source = event.source ?? source
        sessionName = event.sessionName ?? sessionName
        notificationMessage = nil  // 默认清除

        switch event.hookEventName {
        case .userPromptSubmit:
            lastPrompt = event.prompt

        case .preToolUse:
            lastTool = event.toolName
            if let input = event.toolInput {
                lastToolDetail = String(data: try! JSONEncoder().encode(input), encoding: .utf8)
            }

        case .postToolUse:
            lastTool = event.toolName

        case .postToolUseFailure:
            lastTool = event.toolName
            notificationMessage = event.error

        case .permissionRequest:
            notificationMessage = event.title ?? event.toolName

        case .sessionError:
            notificationMessage = event.error ?? event.message

        case .notification:
            notificationMessage = event.message

        case .subagentStart:
            if let agentId = event.agentId {
                let subagent = SubagentInfo(
                    agentId: agentId,
                    agentType: event.agentType,
                    startedAt: event.receivedAt
                )
                activeSubagents.append(subagent)
            }

        case .subagentStop:
            if let agentId = event.agentId {
                activeSubagents.removeAll { $0.agentId == agentId }
            }

        case .preCompact:
            notificationMessage = event.message

        case .postCompact:
            notificationMessage = "上下文已压缩"

        case .sessionStart, .sessionEnd, .stop:
            break
        }
    }

    // MARK: 文件读写

    /// 将会话写入 JSON 文件
    func writeToFile() throws {
        guard let url = fileURL else {
            throw SessionError.fileURLMissing
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    /// 从 JSON 文件读取会话
    static func loadFromFile(url: URL) throws -> Session {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var session = try decoder.decode(Session.self, from: data)
        session.fileURL = url
        return session
    }
}

// MARK: - 子代理信息

struct SubagentInfo: Codable, Equatable, Sendable {
    let agentId: String
    let agentType: String?
    let startedAt: Date
}

// MARK: - 会话错误

enum SessionError: LocalizedError {
    case fileURLMissing
    case fileNotFound(URL)
    case decodeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileURLMissing:
            return "文件路径未设置"
        case .fileNotFound(let url):
            return "文件不存在: \(url.path)"
        case .decodeFailed(let error):
            return "解析失败: \(error.localizedDescription)"
        }
    }
}
