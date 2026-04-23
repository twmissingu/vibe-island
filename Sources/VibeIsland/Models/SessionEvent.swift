import Foundation

// MARK: - Hook 事件名称

/// 14 种 hook 事件类型，覆盖 Claude Code 生命周期
public enum SessionEventName: String, Codable, Sendable, CaseIterable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case stop = "Stop"
    case sessionError = "SessionError"
    case userPromptSubmit = "UserPromptSubmit"
    case permissionRequest = "PermissionRequest"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case preCompact = "PreCompact"
    case postCompact = "PostCompact"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case notification = "Notification"

    public var displayName: String {
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

    public func toSessionState() -> SessionState {
        switch self {
        case .sessionStart: return .idle
        case .userPromptSubmit, .preToolUse, .postToolUse: return .coding
        case .stop: return .completed
        case .notification: return .waiting
        case .permissionRequest: return .waitingPermission
        case .subagentStart, .subagentStop: return .thinking
        case .preCompact, .postCompact: return .compacting
        case .sessionError: return .error
        case .postToolUseFailure: return .error
        case .sessionEnd: return .idle
        }
    }

    /// 事件类型分组
    public var category: String {
        switch self {
        case .sessionStart, .sessionEnd, .stop, .sessionError:
            return "Lifecycle"
        case .userPromptSubmit, .permissionRequest:
            return "User Interaction"
        case .preToolUse, .postToolUse, .postToolUseFailure:
            return "Tool"
        case .preCompact, .postCompact:
            return "Compaction"
        case .subagentStart, .subagentStop:
            return "Subagent"
        case .notification:
            return "Notification"
        }
    }
}

// MARK: - 通知类型

public enum NotificationType: String, Codable, Sendable {
    case idlePrompt = "idle_prompt"
    case permissionPrompt = "permission_prompt"
    case other = "other"
}

// MARK: - Hook 事件数据模型

/// Claude Code hook stdin JSON 格式
public struct SessionEvent: Codable, Sendable {
    public let sessionId: String
    public let cwd: String
    public let hookEventName: SessionEventName
    public let source: String?
    public let sessionName: String?
    public let prompt: String?
    public let toolName: String?
    public let toolInput: [String: String]?
    public let title: String?
    public let error: String?
    public let message: String?
    public let notificationType: NotificationType?
    public let agentId: String?
    public let agentType: String?
    public let transcriptPath: String?
    public let permissionMode: String?
    public let isInterrupt: Bool?
    public let pid: UInt32?
    public let pidStartTime: TimeInterval?
    public let receivedAt: Date

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
        case pid
        case pidStartTime = "pid_start_time"
        case receivedAt = "received_at"
    }

    public init(from decoder: Decoder) throws {
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
        pid = try container.decodeIfPresent(UInt32.self, forKey: .pid)
        pidStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .pidStartTime)
        receivedAt = Date()
    }

    public func encode(to encoder: Encoder) throws {
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
        try container.encodeIfPresent(pid, forKey: .pid)
        try container.encodeIfPresent(pidStartTime, forKey: .pidStartTime)
        try container.encode(receivedAt, forKey: .receivedAt)
    }

    public init(
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
        pid: UInt32? = nil,
        pidStartTime: TimeInterval? = nil,
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
        self.pid = pid
        self.pidStartTime = pidStartTime
        self.receivedAt = receivedAt
    }
}
