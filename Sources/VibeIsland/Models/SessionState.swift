import Foundation
import SwiftUI

// MARK: - 会话状态机

/// 会话的 8 种运行状态
public enum SessionState: String, Codable, Equatable, Sendable, CaseIterable {
    case idle
    case thinking
    case coding
    case waiting
    case waitingPermission
    case completed
    case error
    case compacting

    // MARK: 状态显示名

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .coding: return "Coding"
        case .waiting: return "Waiting"
        case .waitingPermission: return "Permission"
        case .completed: return "Completed"
        case .error: return "Error"
        case .compacting: return "Compacting"
        }
    }

    // MARK: 状态颜色

    public var color: Color {
        switch self {
        case .idle: return .gray
        case .thinking: return .cyan
        case .coding: return .blue
        case .waiting: return .orange
        case .waitingPermission: return .yellow
        case .completed: return .green
        case .error: return .red
        case .compacting: return .purple
        }
    }

    /// 是否需要闪烁指示
    public var isBlinking: Bool {
        switch self {
        case .waitingPermission, .compacting, .completed, .error: return true
        default: return false
        }
    }

    // MARK: 状态转换逻辑

    public static func transition(from current: SessionState, event: SessionEventName) -> SessionState {
        switch event {
        case .sessionStart: return .idle
        case .userPromptSubmit: return .coding
        case .preToolUse:
            return .waiting
        case .postToolUse:
            return .coding
        case .postToolUseFailure: return .error
        case .stop: return .completed
        case .notification: return current
        case .permissionRequest: return .waitingPermission
        case .subagentStart, .subagentStop: return current
        case .preCompact: return .compacting
        case .postCompact:
            return .completed
        case .sessionError: return .error
        case .sessionEnd: return .completed
        }
    }

    /// 默认优先级（用于排序，不影响显示）
    public var priority: Int { 0 }
    
    // MARK: 渐变色

    /// 渐变颜色数组（用于边框 - 默认灰色，不随状态变化）
    public var gradientColors: [Color] {
        return [.gray.opacity(0.5), .gray.opacity(0.3)]
    }
}

// MARK: - Color 扩展

extension Color {
    /// 获取渐变色（用于边框渐变）
    public var stateGradientColors: (Color, Color) {
        switch self {
        case .black: return (.gray.opacity(0.3), .black.opacity(0.5))
        case .yellow: return (.yellow.opacity(0.8), .orange)
        case .green: return (.green.opacity(0.8), .mint)
        case .orange: return (.orange.opacity(0.8), .red.opacity(0.5))
        case .red: return (.red.opacity(0.8), .red)
        default: return (self, self.opacity(0.7))
        }
    }
}

// MARK: - 会话聚合协议

/// 可聚合的会话集合
/// 提供统一的状态聚合计算方法
@MainActor
public protocol SessionAggregatable {
    associatedtype SessionType
    /// 所有会话
    var allSessions: [SessionType] { get }
    /// 获取单个会话的状态
    func sessionStatus(_ session: SessionType) -> SessionState
}

@MainActor
extension SessionAggregatable {
    /// 最高优先级状态（用于菜单栏/全局展示）
    public var aggregateState: SessionState {
        allSessions.map(sessionStatus)
            .min(by: { $0.priority < $1.priority })
            ?? .idle
    }

    /// 活跃会话数量（排除 idle 和 completed）
    public var activeCount: Int {
        allSessions.filter {
            let status = sessionStatus($0)
            return status != .idle && status != .completed
        }.count
    }

    /// 是否有等待权限审批的会话
    public var hasPendingPermission: Bool {
        allSessions.contains { sessionStatus($0) == .waitingPermission }
    }

    /// 是否有错误会话
    public var hasError: Bool {
        allSessions.contains { sessionStatus($0) == .error }
    }
}
