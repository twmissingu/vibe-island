import SwiftUI

// MARK: - 毛玻璃效果组件

/// 毛玻璃效果类型
enum GlassType {
    case ultraThin    // 最薄
    case thin         // 薄
    case regular      // 常规
    case thick        // 厚
    
    var material: some ShapeStyle {
        switch self {
        case .ultraThin:
            return .ultraThinMaterial
        case .thin:
            return .thinMaterial
        case .regular:
            return .regularMaterial
        case .thick:
            return .thickMaterial
        }
    }
}

/// 毛玻璃背景容器
struct GlassContainer<Content: View>: View {
    let type: GlassType
    let cornerRadius: CGFloat
    let borderColor: Color
    let borderOpacity: Double
    
    let content: Content
    
    init(
        type: GlassType = .ultraThin,
        cornerRadius: CGFloat = 12,
        borderColor: Color = .white,
        borderOpacity: Double = 0.3,
        @ViewBuilder content: () -> Content
    ) {
        self.type = type
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(type.material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor.opacity(borderOpacity), lineWidth: 0.5)
            )
    }
}

/// 动态毛玻璃效果（根据 SessionState 调整）
struct DynamicGlassContainer: View {
    let state: SessionState
    let cornerRadius: CGFloat
    let showBorder: Bool
    
    @State private var borderOpacity: Double = 0.3
    
    init(
        state: SessionState,
        cornerRadius: CGFloat = 12,
        showBorder: Bool = true
    ) {
        self.state = state
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                state.color.opacity(borderOpacity),
                                state.color.opacity(borderOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: state.color.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

/// 可配置的毛玻璃修饰器
struct Glassmorphism: ViewModifier {
    let type: GlassType
    let cornerRadius: CGFloat
    let borderColor: Color
    let borderOpacity: Double
    let shadowColor: Color
    let shadowRadius: CGFloat
    
    init(
        type: GlassType = .ultraThin,
        cornerRadius: CGFloat = 12,
        borderColor: Color = .white,
        borderOpacity: Double = 0.3,
        shadowColor: Color = .black,
        shadowRadius: CGFloat = 10
    ) {
        self.type = type
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
    }
    
    func body(content: Content) -> some View {
        content
            .padding(cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(type.material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor.opacity(borderOpacity), lineWidth: 0.5)
            )
            .shadow(color: shadowColor.opacity(0.2), radius: shadowRadius, x: 0, y: 5)
    }
}

// MARK: - 渐变毛玻璃

struct GradientGlass: ViewModifier {
    let colors: [Color]
    let cornerRadius: CGFloat
    let blur: CGFloat
    
    init(
        colors: [Color] = [.white.opacity(0.3), .white.opacity(0.1)],
        cornerRadius: CGFloat = 12,
        blur: CGFloat = 10
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.blur = blur
    }
    
    func body(content: Content) -> some View {
        content
            .padding(cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: blur)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
    }
}

// MARK: - Glassmorphism 工厂

struct GlassmorphismStyle {
    static func forState(_ state: SessionState, cornerRadius: CGFloat = 12) -> some ViewModifier {
        GradientGlass(colors: [
            state.color.opacity(0.3),
            state.color.opacity(0.1)
        ], cornerRadius: cornerRadius)
    }
}

// MARK: - View 扩展

extension View {
    /// 添加毛玻璃效果
    func glassmorphism(
        type: GlassType = .ultraThin,
        cornerRadius: CGFloat = 12,
        borderColor: Color = .white,
        borderOpacity: Double = 0.3,
        shadowColor: Color = .black,
        shadowRadius: CGFloat = 10
    ) -> some View {
        modifier(Glassmorphism(
            type: type,
            cornerRadius: cornerRadius,
            borderColor: borderColor,
            borderOpacity: borderOpacity,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius
        ))
    }
    
    /// 添加动态毛玻璃（根据 SessionState）
    func glassmorphism(
        for state: SessionState,
        cornerRadius: CGFloat = 12
    ) -> some View {
        modifier(GradientGlass(colors: [
            state.color.opacity(0.3),
            state.color.opacity(0.1)
        ], cornerRadius: cornerRadius))
    }
    
    /// 添加渐变毛玻璃
    func gradientGlass(
        colors: [Color] = [.white.opacity(0.3), .white.opacity(0.1)],
        cornerRadius: CGFloat = 12,
        blur: CGFloat = 10
    ) -> some View {
        modifier(GradientGlass(colors: colors, cornerRadius: cornerRadius, blur: blur))
    }
}

// MARK: - 预置毛玻璃样式

extension GlassType {
    /// 灵动岛专用毛玻璃样式
    static var island: GlassType { .ultraThin }
    
    /// 卡片专用毛玻璃样式
    static var card: GlassType { .regular }
    
    /// 弹窗专用毛玻璃样式
    static var popup: GlassType { .thick }
}