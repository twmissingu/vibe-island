// Shared models for CLI - re-exports from VibeIsland Models
// This file allows the CLI to compile independently

import Foundation

// MARK: - File Lock

func withSessionLock(at url: URL, body: () throws -> Void) throws {
    let lockPath = url.path + ".lock"
    let fd = open(lockPath, O_CREAT | O_WRONLY, 0o600)
    guard fd >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }
    defer { close(fd) }
    guard flock(fd, LOCK_EX) == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }
    defer { flock(fd, LOCK_UN) }
    try body()
}

// MARK: - SessionEventName

enum SessionEventName: String, CaseIterable, Codable {
    case sessionStart = "SessionStart"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case stop = "Stop"
    case notification = "Notification"
    case permissionRequest = "PermissionRequest"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case preCompact = "PreCompact"
    case postCompact = "PostCompact"
    case sessionError = "SessionError"
    case sessionEnd = "SessionEnd"
    
    var displayName: String {
        switch self {
        case .sessionStart: return "会话开始"
        case .userPromptSubmit: return "用户提交提示"
        case .preToolUse: return "工具使用前"
        case .postToolUse: return "工具使用后"
        case .postToolUseFailure: return "工具使用失败"
        case .stop: return "停止"
        case .notification: return "通知"
        case .permissionRequest: return "权限请求"
        case .subagentStart: return "子Agent开始"
        case .subagentStop: return "子Agent停止"
        case .preCompact: return "压缩前"
        case .postCompact: return "压缩后"
        case .sessionError: return "会话错误"
        case .sessionEnd: return "会话结束"
        }
    }
    
    func toSessionState() -> SessionState {
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
}

// MARK: - NotificationType

enum NotificationType: String, Codable {
    case idlePrompt = "idle_prompt"
    case permissionPrompt = "permission_prompt"
    case other = "other"
}

// MARK: - SessionEvent

struct SessionEvent: Codable {
    let sessionId: String
    let cwd: String
    let hookEventName: SessionEventName
    let source: String?
    let sessionName: String?
    let prompt: String?
    let toolName: String?
    let toolInput: [String: String]?
    let title: String?
    let error: String?
    let message: String?
    let notificationType: NotificationType?
    let agentId: String?
    let agentType: String?
    let transcriptPath: String?
    let permissionMode: String?
    let isInterrupt: Bool?
    let pid: UInt32?
    let pidStartTime: TimeInterval?
    
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
    }
}

// MARK: - SessionState

enum SessionState: String, Codable {
    case idle
    case thinking
    case coding
    case waiting
    case waitingPermission
    case completed
    case error
    case compacting
}

// MARK: - SubagentInfo

struct SubagentInfo: Codable {
    let agentId: String
    let agentType: String
    let startedAt: Date
}

// MARK: - Session

struct Session: Codable {
    let sessionId: String
    let cwd: String
    var status: SessionState
    var lastActivity: Date
    var branch: String?
    var source: String?
    var sessionName: String?
    var lastTool: String?
    var lastToolDetail: String?
    var lastPrompt: String?
    var notificationMessage: String?
    var activeSubagents: [SubagentInfo]?
    var pid: UInt32?
    var pidStartTime: TimeInterval?
    var endedAt: Date?
    var contextUsage: Double?
    var contextTokensUsed: Int?
    var contextTokensTotal: Int?
    var fileURL: URL?
    
    static func loadFromFile(url: URL) throws -> Session {
        let data = try Data(contentsOf: url)
        var session = try JSONDecoder().decode(Session.self, from: data)
        session.fileURL = url
        return session
    }
    
    func writeToFile(url: URL? = nil) throws {
        let writeURL = url ?? fileURL
        guard let writeURL else {
            throw NSError(domain: "Session", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file URL"])
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: writeURL)
    }
}
