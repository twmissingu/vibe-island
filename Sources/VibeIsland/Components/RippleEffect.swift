import SwiftUI

// MARK: - 波纹动画修饰器

/// 为视图添加波纹扩散动画效果
struct RippleEffect: ViewModifier {
    let color: Color
    let speed: Double
    let maxRadius: CGFloat
    
    @State private var ripples: [Ripple] = []
    @State private var timer: Timer?
    
    init(color: Color = .blue, speed: Double = 1.5, maxRadius: CGFloat = 50) {
        self.color = color
        self.speed = speed
        self.maxRadius = maxRadius
    }
    
    func body(content: Content) -> some View {
        ZStack {
            // 波纹层
            ForEach(ripples) { ripple in
                Circle()
                    .stroke(color.opacity(ripple.opacity), lineWidth: 2)
                    .frame(width: ripple.radius * 2, height: ripple.radius * 2)
            }
            
            // 原始内容
            content
        }
        .onAppear {
            startRipples()
        }
        .onDisappear {
            stopRipples()
        }
    }
    
    private func startRipples() {
        // 添加第一个波纹
        addRipple()
        
        // 定时添加新波纹
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { _ in
            addRipple()
        }
    }
    
    private func stopRipples() {
        timer?.invalidate()
        timer = nil
    }
    
    private func addRipple() {
        let newRipple = Ripple(
            id: UUID(),
            radius: 0,
            opacity: 0.8
        )
        ripples.append(newRipple)
        
        // 动画波纹扩散
        withAnimation(.linear(duration: speed * 2)) {
            if let index = ripples.firstIndex(where: { $0.id == newRipple.id }) {
                ripples[index].radius = maxRadius
                ripples[index].opacity = 0
            }
        }
        
        // 清理完成的波纹
        DispatchQueue.main.asyncAfter(deadline: .now() + speed * 2) {
            ripples.removeAll { $0.radius >= maxRadius }
        }
    }
}

// MARK: - 波纹数据模型

struct Ripple: Identifiable {
    let id: UUID
    var radius: CGFloat
    var opacity: Double
}

// MARK: - 单次波纹效果

struct SingleRipple: ViewModifier {
    let color: Color
    let maxRadius: CGFloat
    var duration: Double = 1.5
    
    @State private var radius: CGFloat = 0
    @State private var opacity: Double = 1
    
    init(color: Color = .blue, maxRadius: CGFloat = 50, duration: Double = 1.5) {
        self.color = color
        self.maxRadius = maxRadius
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(opacity), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
            
            content
        }
        .onAppear {
            withAnimation(.easeOut(duration: duration)) {
                radius = maxRadius
                opacity = 0
            }
        }
    }
}

// MARK: - 点击波纹效果

struct ClickRipple: ViewModifier {
    let color: Color
    
    @State private var ripplePosition: CGPoint = .zero
    @State private var rippleRadius: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var isAnimating: Bool = false
    
    init(color: Color = .blue) {
        self.color = color
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: RipplePreferenceKey.self,
                            value: geometry.frame(in: .global).center
                        )
                }
            )
            .onPreferenceChange(RipplePreferenceKey.self) { center in
                if !isAnimating {
                    triggerRipple(at: center)
                }
            }
            .overlay(
                Circle()
                    .stroke(color.opacity(rippleOpacity), lineWidth: 2)
                    .frame(width: rippleRadius * 2, height: rippleRadius * 2)
                    .position(ripplePosition)
            )
    }
    
    private func triggerRipple(at center: CGPoint) {
        isAnimating = true
        ripplePosition = center
        rippleRadius = 0
        rippleOpacity = 0.8
        
        withAnimation(.easeOut(duration: 0.8)) {
            rippleRadius = 50
            rippleOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isAnimating = false
        }
    }
}

// MARK: - Preference Key

struct RipplePreferenceKey: PreferenceKey {
    static let defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// MARK: - CGRect 扩展

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

// MARK: - RippleEffect 工厂

struct RippleEffectStyle {
    static func forState(_ state: SessionState, speed: Double = 1.5, maxRadius: CGFloat = 50) -> some ViewModifier {
        RippleEffect(color: state.color, speed: speed, maxRadius: maxRadius)
    }
    
    static func singleForState(_ state: SessionState, maxRadius: CGFloat = 50) -> some ViewModifier {
        SingleRipple(color: state.color, maxRadius: maxRadius)
    }
    
    static func clickForState(_ state: SessionState) -> some ViewModifier {
        ClickRipple(color: state.color)
    }
}

// MARK: - View 扩展

extension View {
    /// 添加波纹动画效果
    func rippleEffect(color: Color = .blue, speed: Double = 1.5, maxRadius: CGFloat = 50) -> some View {
        modifier(RippleEffect(color: color, speed: speed, maxRadius: maxRadius))
    }
    
    /// 根据 SessionState 添加波纹动画效果
    func rippleEffect(for state: SessionState, speed: Double = 1.5, maxRadius: CGFloat = 50) -> some View {
        modifier(RippleEffect(color: state.color, speed: speed, maxRadius: maxRadius))
    }
    
    /// 添加单次波纹效果
    func singleRipple(color: Color = .blue, maxRadius: CGFloat = 50, duration: Double = 1.5) -> some View {
        modifier(SingleRipple(color: color, maxRadius: maxRadius, duration: duration))
    }
    
    /// 根据 SessionState 添加单次波纹效果
    func singleRipple(for state: SessionState, maxRadius: CGFloat = 50) -> some View {
        modifier(SingleRipple(color: state.color, maxRadius: maxRadius))
    }
    
    /// 添加点击波纹效果
    func clickRipple(color: Color = .blue) -> some View {
        modifier(ClickRipple(color: color))
    }
    
    /// 根据 SessionState 添加点击波纹效果
    func clickRipple(for state: SessionState) -> some View {
        modifier(ClickRipple(color: state.color))
    }
}