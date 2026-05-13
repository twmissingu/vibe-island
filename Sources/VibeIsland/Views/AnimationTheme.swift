import SwiftUI

/// 统一动画曲线：所有灵动岛过渡动画使用同一组参数
/// 确保紧凑→展开、标签切换、设置面板等过渡有一致的手感
enum IslandAnimation {
    /// 岛的展开/收起（紧凑↔展开）
    static let expand = Spring(response: 0.45, dampingRatio: 0.75)
    /// 标签页切换（水平滑入）
    static let tabSwitch = Spring(response: 0.35, dampingRatio: 0.7)
    /// 标签指示器滑动
    static let tabIndicator = Spring(response: 0.35, dampingRatio: 0.7)
    /// 状态颜色变化
    static let colorChange = Spring(response: 0.35, dampingRatio: 0.8)
    /// 设置面板滑入/滑出
    static let settingsSlide = Spring(response: 0.5, dampingRatio: 0.8)
    /// 主题切换交叉淡入淡出时长
    static let themeChange: TimeInterval = 0.4
}
