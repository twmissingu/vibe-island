import Foundation

// MARK: - Hook 事件名称（与 Claude Code hook stdin JSON 格式对齐）

/// 14 种 hook 事件类型，覆盖 Claude Code 生命周期
enum SessionEventName: String, Codable, Sendable, CaseIterable {
    // 会话生命周期
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case stop = "Stop"
    case sessionError = "SessionError"

    // 用户交互
    case userPromptSubmit = "UserPromptSubmit"
    case permissionRequest = "PermissionRequest"

    // 工具调用
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"

    // 上下文压缩
    case preCompact = "PreCompact"
    case postCompact = "PostCompact"

    // 子代理
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"

    // 通知（idle / permission / other 通过 notificationType 区分）
    case notification = "Notification"

    var displayName: String {
        switch self {
        case .sessionStart: return "会话开始"
        case .sessionEnd: return "会话结束"
        case .stop: return "停止"
        case .sessionError: return "会话错误"
        case .userPromptSubmit: return "用户提交提示"
        case .permissionRequest: return "权限请求"
        case .preToolUse: return "工具调用前"
        case .postToolUse: return "工具调用后"
        case .postToolUseFailure: return "工具调用失败"
        case .preCompact: return "压缩前"
        case .postCompact: return "压缩后"
        case .subagentStart: return "子代理启动"
        case .subagentStop: return "子代理停止"
        case .notification: return "通知"
        }
    }
}

// MARK: - 通知类型

enum NotificationType: String, Codable, Sendable {
    case idlePrompt = "idle_prompt"
    case permissionPrompt = "permission_prompt"
    case other = "other"
}

// MARK: - Hook 事件数据模型

/// Claude Code hook stdin JSON 格式
/// 参考：https://docs.anthropic.com/en/docs/claude-code/settings#hooks
struct SessionEvent: Codable, Sendable {
    // MARK: 必需字段

    /// 会话唯一标识
    let sessionId: String
    /// 当前工作目录
    let cwd: String
    /// hook 事件名称
    let hookEventName: SessionEventName

    // MARK: 可选字段

    /// 来源标识
    let source: String?
    /// 会话名称
    let sessionName: String?

    // 用户提示
    let prompt: String?

    // 工具相关
    let toolName: String?
    let toolInput: [String: String]?
    let title: String?

    // 错误信息
    let error: String?
    let message: String?

    // 通知
    let notificationType: NotificationType?

    // 子代理
    let agentId: String?
    let agentType: String?

    // 其他
    let transcriptPath: String?
    let permissionMode: String?
    let isInterrupt: Bool?

    // MARK: 时间戳（由接收时填充）

    let receivedAt: Date

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
        case source
        case sessionName = "session_name"
        case prompt
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case title
        case error
        case message
        case notificationType = "notification_type"
        case agentId = "agent_id"
        case agentType = "agent_type"
        case transcriptPath = "transcript_path"
        case permissionMode = "permission_mode"
        case isInterrupt = "is_interrupt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        cwd = try container.decode(String.self, forKey: .cwd)
        hookEventName = try container.decode(SessionEventName.self, forKey: .hookEventName)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        sessionName = try container.decodeIfPresent(String.self, forKey: .sessionName)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolInput = try container.decodeIfPresent([String: String].self, forKey: .toolInput)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        notificationType = try container.decodeIfPresent(NotificationType.self, forKey: .notificationType)
        agentId = try container.decodeIfPresent(String.self, forKey: .agentId)
        agentType = try container.decodeIfPresent(String.self, forKey: .agentType)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        permissionMode = try container.decodeIfPresent(String.self, forKey: .permissionMode)
        isInterrupt = try container.decodeIfPresent(Bool.self, forKey: .isInterrupt)
        receivedAt = Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(cwd, forKey: .cwd)
        try container.encode(hookEventName, forKey: .hookEventName)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(sessionName, forKey: .sessionName)
        try container.encodeIfPresent(prompt, forKey: .prompt)
        try container.encodeIfPresent(toolName, forKey: .toolName)
        try container.encodeIfPresent(toolInput, forKey: .toolInput)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(notificationType, forKey: .notificationType)
        try container.encodeIfPresent(agentId, forKey: .agentId)
        try container.encodeIfPresent(agentType, forKey: .agentType)
        try container.encodeIfPresent(transcriptPath, forKey: .transcriptPath)
        try container.encodeIfPresent(permissionMode, forKey: .permissionMode)
        try container.encodeIfPresent(isInterrupt, forKey: .isInterrupt)
    }

    // MARK: 测试专用初始化器

    /// 内部初始化器，供测试使用
    init(
        sessionId: String,
        cwd: String,
        hookEventName: SessionEventName,
        source: String? = nil,
        sessionName: String? = nil,
        prompt: String? = nil,
        toolName: String? = nil,
        toolInput: [String: String]? = nil,
        title: String? = nil,
        error: String? = nil,
        message: String? = nil,
        notificationType: NotificationType? = nil,
        agentId: String? = nil,
        agentType: String? = nil,
        transcriptPath: String? = nil,
        permissionMode: String? = nil,
        isInterrupt: Bool? = nil,
        receivedAt: Date = Date()
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.hookEventName = hookEventName
        self.source = source
        self.sessionName = sessionName
        self.prompt = prompt
        self.toolName = toolName
        self.toolInput = toolInput
        self.title = title
        self.error = error
        self.message = message
        self.notificationType = notificationType
        self.agentId = agentId
        self.agentType = agentType
        self.transcriptPath = transcriptPath
        self.permissionMode = permissionMode
        self.isInterrupt = isInterrupt
        self.receivedAt = receivedAt
    }
}
