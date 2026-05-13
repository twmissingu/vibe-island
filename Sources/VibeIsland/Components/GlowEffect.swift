import SwiftUI

// MARK: - 发光效果修饰器

/// 为视图添加发光效果，支持根据 SessionState 动态变化颜色
struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    var opacity: Double = 0.8
    
    @State private var pulseOpacity: Double = 1
    
    init(color: Color = .blue, radius: CGFloat = 20, opacity: Double = 0.8) {
        self.color = color
        self.radius = radius
        self.opacity = opacity
    }
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(pulseOpacity * opacity), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(pulseOpacity * opacity * 0.5), radius: radius * 2, x: 0, y: 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            }
    }
}

// MARK: - 脉冲发光效果（带动画）

struct PulsingGlow: ViewModifier {
    let color: Color
    let baseRadius: CGFloat
    var maxRadius: CGFloat = 30
    var duration: Double = 1.5
    
    @State private var currentRadius: CGFloat = 0
    @State private var opacity: Double = 1
    
    init(color: Color = .blue, baseRadius: CGFloat = 10, maxRadius: CGFloat = 30, duration: Double = 1.5) {
        self.color = color
        self.baseRadius = baseRadius
        self.maxRadius = maxRadius
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(color.opacity(0.3 * opacity))
                    .frame(width: currentRadius * 2, height: currentRadius * 2)
            )
            .shadow(color: color.opacity(opacity * 0.8), radius: currentRadius, x: 0, y: 0)
            .onAppear {
                withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                    currentRadius = maxRadius
                    opacity = 0
                }
            }
    }
}

// MARK: - 状态发光颜色工厂

struct GlowEffectColors {
    /// 获取状态对应的发光颜色
    static func color(for state: SessionState) -> Color {
        state.color.opacity(0.8)
    }
}

// MARK: - GlowEffect 工厂

struct GlowEffectStyle {
    static func forState(_ state: SessionState, radius: CGFloat = 20, opacity: Double = 0.8) -> some ViewModifier {
        GlowEffect(color: state.color, radius: radius, opacity: opacity)
    }
    
    static func pulsingForState(_ state: SessionState, baseRadius: CGFloat = 10, maxRadius: CGFloat = 30) -> some ViewModifier {
        PulsingGlow(color: state.color, baseRadius: baseRadius, maxRadius: maxRadius)
    }
}

// MARK: - View 扩展

extension View {
    /// 添加发光效果
    func glow(color: Color = .blue, radius: CGFloat = 20, opacity: Double = 0.8) -> some View {
        modifier(GlowEffect(color: color, radius: radius, opacity: opacity))
    }
    
    /// 根据 SessionState 添加发光效果
    func glow(for state: SessionState, radius: CGFloat = 20, opacity: Double = 0.8) -> some View {
        modifier(GlowEffect(color: state.color, radius: radius, opacity: opacity))
    }
    
    /// 添加脉冲发光效果
    func pulsingGlow(color: Color = .blue, baseRadius: CGFloat = 10, maxRadius: CGFloat = 30, duration: Double = 1.5) -> some View {
        modifier(PulsingGlow(color: color, baseRadius: baseRadius, maxRadius: maxRadius, duration: duration))
    }
    
    /// 根据 SessionState 添加脉冲发光效果
    func pulsingGlow(for state: SessionState, baseRadius: CGFloat = 10, maxRadius: CGFloat = 30) -> some View {
        modifier(PulsingGlow(color: state.color, baseRadius: baseRadius, maxRadius: maxRadius))
    }
}