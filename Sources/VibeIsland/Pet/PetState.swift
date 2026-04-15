import Foundation

/// 宠物状态机：与 SessionState 绑定
enum PetState: String, Codable {
    case idle           // 空闲 - 绿色
    case thinking       // 思考中 - 黄色
    case coding         // 编码中 - 蓝色
    case waiting        // 等待输入 - 橙色
    case celebrating    // 庆祝 - 绿色闪烁
    case error          // 错误 - 红色
    case compacting     // 压缩中 - 橙色闪烁
    case sleeping       // 睡眠 - 灰色
    
    /// 从 SessionState 映射
    static func from(sessionState: String) -> PetState {
        switch sessionState {
        case "idle": return .idle
        case "thinking": return .thinking
        case "coding": return .coding
        case "waiting": return .waiting
        case "celebrating": return .celebrating
        case "error": return .error
        case "compacting": return .compacting
        case "sleeping": return .sleeping
        default: return .idle
        }
    }
}
