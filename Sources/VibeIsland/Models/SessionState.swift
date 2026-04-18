import Foundation
import SwiftUI

// MARK: - 会话状态机

/// 会话的 8 种运行状态，与 PetState 一一对应
enum SessionState: String, Codable, Equatable, Sendable, CaseIterable {
    case idle               // 空闲 - 绿色
    case thinking           // 思考中 - 黄色
    case coding             // 编码中 - 蓝色
    case waiting            // 等待输入 - 橙色
    case waitingPermission  // 等待权限审批 - 橙色闪烁
    case completed          // 已完成 - 绿色
    case error              // 错误 - 红色
    case compacting         // 压缩中 - 橙色闪烁

    // MARK: 状态显示名

    var displayName: String {
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

    // MARK: 状态颜色（与设计文档对齐）

    var color: Color {
        switch self {
        case .idle: return .black         // ⚫ 空闲/待机
        case .thinking: return .yellow     // 🟡 思考中
        case .coding: return .green        // 🟢 编码中（正常运行）
        case .waiting: return .orange      // 🟠 等待输入
        case .waitingPermission: return .yellow // 🟡 等待权限审批（最高优先级，闪烁）
        case .completed: return .green     // 🟢 已完成
        case .error: return .red           // 🔴 错误
        case .compacting: return .orange   // 🟠 上下文压缩中（闪烁）
        }
    }

    /// 是否需要闪烁指示
    var isBlinking: Bool {
        switch self {
        case .waitingPermission, .compacting: return true
        default: return false
        }
    }

    // MARK: 状态转换逻辑

    /// 根据事件计算下一个状态
    static func transition(from current: SessionState, event: SessionEventName) -> SessionState {
        switch event {
        case .sessionStart:
            return .thinking

        case .userPromptSubmit:
            return .thinking

        case .preToolUse:
            // 从 thinking 或 waiting 进入 coding
            if current == .thinking || current == .waiting || current == .waitingPermission {
                return .coding
            }
            return current

        case .postToolUse:
            // 工具使用完毕后回到 thinking（继续处理 prompt）
            if current == .coding {
                return .thinking
            }
            return current

        case .postToolUseFailure:
            // 工具失败进入 error
            return .error

        case .stop:
            return .completed

        case .notification:
            // 通知不改变状态
            return current

        case .permissionRequest:
            return .waitingPermission

        case .subagentStart:
            // 子代理启动不改变主状态
            return current

        case .subagentStop:
            return current

        case .preCompact:
            return .compacting

        case .postCompact:
            // 压缩完成回到 thinking
            if current == .compacting {
                return .thinking
            }
            return current

        case .sessionError:
            return .error

        case .sessionEnd:
            return .completed
        }
    }

    // MARK: 优先级排序

    /// 状态优先级（用于多会话聚合显示）
    /// 审批 > 错误 > 运行 > 空闲
    var priority: Int {
        switch self {
        case .waitingPermission: return 0    // 最高：需要用户操作
        case .error: return 1                // 错误需要关注
        case .compacting: return 2           // 压缩中
        case .coding: return 3              // 正在工作
        case .thinking: return 4            // 思考中
        case .waiting: return 5             // 等待输入
        case .completed: return 6           // 已完成
        case .idle: return 7                // 最低：空闲
        }
    }
    
    /// 渐变颜色数组（用于边框）
    var gradientColors: [Color] {
        switch self {
        case .idle:
            return [.gray.opacity(0.5), .gray.opacity(0.3)]
        case .thinking:
            return [.yellow, .orange, .yellow.opacity(0.5)]
        case .coding:
            return [.green, .cyan, .green.opacity(0.5)]
        case .waiting:
            return [.orange, .yellow, .orange.opacity(0.5)]
        case .waitingPermission:
            return [.yellow, .white, .yellow.opacity(0.5)]
        case .completed:
            return [.green, .mint, .green.opacity(0.5)]
        case .error:
            return [.red, .pink, .red.opacity(0.5)]
        case .compacting:
            return [.orange, .yellow, .red.opacity(0.5)]
        }
    }
}


// MARK: - Color 扩展

extension Color {
    /// 获取渐变色（用于边框渐变）
    var stateGradientColors: (Color, Color) {
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
