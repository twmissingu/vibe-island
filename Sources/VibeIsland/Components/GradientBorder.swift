import SwiftUI

// MARK: - 渐变边框修饰器

/// 为视图添加渐变边框效果，支持根据 SessionState 动态变化颜色
struct GradientBorder: ViewModifier {
    let borderWidth: CGFloat
    let colors: [Color]
    var lineWidth: CGFloat = 2
    
    @State private var gradientRotation: Double = 0
    
    init(borderWidth: CGFloat = 10, colors: [Color] = [.blue, .purple, .pink], lineWidth: CGFloat = 2) {
        self.borderWidth = borderWidth
        self.colors = colors
        self.lineWidth = lineWidth
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: borderWidth)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: colors),
                            center: .center,
                            startAngle: .degrees(gradientRotation),
                            endAngle: .degrees(gradientRotation + 360)
                        ),
                        lineWidth: lineWidth
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    gradientRotation = 360
                }
            }
    }
}

// MARK: - GradientBorder 工厂

struct GradientBorderStyle {
    static func forState(_ state: SessionState, borderWidth: CGFloat = 10, lineWidth: CGFloat = 2) -> some ViewModifier {
        GradientBorder(borderWidth: borderWidth, colors: state.gradientColors, lineWidth: lineWidth)
    }
}

// MARK: - View 扩展

extension View {
    /// 添加渐变边框
    func gradientBorder(
        borderWidth: CGFloat = 10,
        colors: [Color] = [.blue, .purple, .pink],
        lineWidth: CGFloat = 2
    ) -> some View {
        modifier(GradientBorder(borderWidth: borderWidth, colors: colors, lineWidth: lineWidth))
    }
    
    /// 根据 SessionState 添加渐变边框
    func gradientBorder(for state: SessionState, borderWidth: CGFloat = 10, lineWidth: CGFloat = 2) -> some View {
        modifier(GradientBorder(borderWidth: borderWidth, colors: state.gradientColors, lineWidth: lineWidth))
    }
}