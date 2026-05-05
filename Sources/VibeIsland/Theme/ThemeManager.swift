import SwiftUI

// MARK: - 主题颜色管理器

/// 统一管理两种主题的颜色方案，确保对比度足够高
struct ThemeManager {
    let theme: AppTheme

    // MARK: - 文字颜色

    /// 主要文字颜色（标题、重要内容）
    var primaryText: Color {
        switch theme {
        case .pixel: return .white
        case .glass: return .white  // 统一使用白色，确保在毛玻璃背景上清晰可见
        }
    }

    /// 次要文字颜色（描述、辅助信息）
    var secondaryText: Color {
        switch theme {
        case .pixel: return .white.opacity(0.85)
        case .glass: return .white.opacity(0.85)  // 统一使用高对比度的白色
        }
    }

    /// 第三级文字颜色（标签、提示）
    var tertiaryText: Color {
        switch theme {
        case .pixel: return .white.opacity(0.7)
        case .glass: return .white.opacity(0.7)  // 统一使用较高对比度的白色
        }
    }

    /// 弱化文字颜色（时间戳、百分比等）
    var mutedText: Color {
        switch theme {
        case .pixel: return .white.opacity(0.6)
        case .glass: return .white.opacity(0.6)  // 统一使用中等对比度的白色
        }
    }

    // MARK: - 状态颜色

    /// 状态指示器颜色（保持原有状态语义）
    func stateColor(for state: SessionState) -> Color {
        return state.color
    }

    /// 上下文使用率颜色
    func contextColor(percent: Int) -> Color {
        if percent < 40 {
            return .green
        } else if percent < 70 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - 背景颜色

    /// 卡片背景颜色
    var cardBackground: Color {
        switch theme {
        case .pixel: return Color(white: 0.15)
        case .glass: return .white.opacity(0.08)  // 稍微增加不透明度，提高可读性
        }
    }

    /// 选中项背景颜色
    var selectedBackground: Color {
        switch theme {
        case .pixel: return .blue.opacity(0.3)
        case .glass: return .blue.opacity(0.2)
        }
    }

    /// 普通项背景颜色
    var normalBackground: Color {
        switch theme {
        case .pixel: return Color(white: 0.12)
        case .glass: return .white.opacity(0.05)
        }
    }

    // MARK: - 边框颜色

    /// 普通边框颜色
    var normalBorder: Color {
        switch theme {
        case .pixel: return .white.opacity(0.2)
        case .glass: return .white.opacity(0.15)
        }
    }

    /// 选中项边框颜色
    var selectedBorder: Color {
        switch theme {
        case .pixel: return .cyan.opacity(0.6)
        case .glass: return .blue.opacity(0.5)
        }
    }

    /// 高亮边框颜色
    var highlightBorder: Color {
        switch theme {
        case .pixel: return .cyan
        case .glass: return .blue
        }
    }

    // MARK: - 进度条颜色

    /// 进度条背景颜色
    var progressBackground: Color {
        switch theme {
        case .pixel: return .white.opacity(0.2)
        case .glass: return .white.opacity(0.15)
        }
    }

    /// 进度条填充颜色（根据状态）
    func progressFill(for percent: Int) -> Color {
        return contextColor(percent: percent)
    }

    // MARK: - 交互元素颜色

    /// 按钮/图标颜色
    var iconColor: Color {
        switch theme {
        case .pixel: return .white.opacity(0.8)
        case .glass: return .white.opacity(0.8)
        }
    }

    /// 禁用状态颜色
    var disabledColor: Color {
        switch theme {
        case .pixel: return .white.opacity(0.3)
        case .glass: return .white.opacity(0.3)
        }
    }

    // MARK: - 标签颜色

    /// 工具来源标签颜色
    var toolSourceColor: Color {
        switch theme {
        case .pixel: return .white.opacity(0.7)
        case .glass: return .white.opacity(0.7)
        }
    }

    /// 工具使用百分比颜色
    var toolPercentColor: Color {
        switch theme {
        case .pixel: return .white.opacity(0.6)
        case .glass: return .white.opacity(0.6)
        }
    }

    /// 技能使用百分比颜色
    var skillPercentColor: Color {
        switch theme {
        case .pixel: return .white.opacity(0.6)
        case .glass: return .white.opacity(0.6)
        }
    }

    // MARK: - 辅助方法

    /// 根据主题返回相应的圆角半径
    var cornerRadius: CGFloat {
        switch theme {
        case .pixel: return 6
        case .glass: return 8
        }
    }

    /// 进度条高度
    var progressBarHeight: CGFloat {
        switch theme {
        case .pixel: return 6
        case .glass: return 8
        }
    }

    /// 根据主题返回相应的间距
    var spacing: CGFloat {
        switch theme {
        case .pixel: return 6
        case .glass: return 8
        }
    }

    /// 根据主题返回相应的内边距
    var padding: CGFloat {
        switch theme {
        case .pixel: return 8
        case .glass: return 10
        }
    }
}

// MARK: - 扩展 AppTheme

extension AppTheme {
    /// 获取主题管理器
    var manager: ThemeManager {
        ThemeManager(theme: self)
    }
}

// MARK: - 视图扩展

extension View {
    /// 应用主题文字样式
    func themedText(_ style: ThemedTextStyle, theme: AppTheme) -> some View {
        let manager = theme.manager
        switch style {
        case .primary:
            return self.foregroundStyle(manager.primaryText)
        case .secondary:
            return self.foregroundStyle(manager.secondaryText)
        case .tertiary:
            return self.foregroundStyle(manager.tertiaryText)
        case .muted:
            return self.foregroundStyle(manager.mutedText)
        }
    }
}

// MARK: - 主题文字样式枚举

enum ThemedTextStyle {
    case primary
    case secondary
    case tertiary
    case muted
}
