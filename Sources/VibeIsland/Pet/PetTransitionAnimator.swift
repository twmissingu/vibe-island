import SwiftUI

// MARK: - 宠物过渡动画系统

/// 过渡动画类型
enum PetTransitionType {
    case fade           // 淡入淡出
    case scale          // 缩放
    case slide          // 滑动
    case shake          // 抖动
    case bounce         // 弹跳
    case pulse          // 脉冲
    case spin           // 旋转
    case flip           // 翻转
    
    /// 默认持续时间
    var defaultDuration: Double {
        switch self {
        case .fade: return 0.3
        case .scale: return 0.25
        case .slide: return 0.3
        case .shake: return 0.4
        case .bounce: return 0.5
        case .pulse: return 0.6
        case .spin: return 0.5
        case .flip: return 0.4
        }
    }
}

/// 过渡动画配置
struct PetTransitionConfig {
    let type: PetTransitionType
    let duration: Double
    let delay: Double
    let spring: Bool
    let springResponse: Double
    let springDamping: Double
    
    init(
        type: PetTransitionType,
        duration: Double? = nil,
        delay: Double = 0,
        spring: Bool = true,
        springResponse: Double = 0.3,
        springDamping: Double = 0.7
    ) {
        self.type = type
        self.duration = duration ?? type.defaultDuration
        self.delay = delay
        self.spring = spring
        self.springResponse = springResponse
        self.springDamping = springDamping
    }
    
    /// 预设配置
    static let fade = PetTransitionConfig(type: .fade)
    static let scale = PetTransitionConfig(type: .scale)
    static let bounce = PetTransitionConfig(type: .bounce)
    static let shake = PetTransitionConfig(type: .shake, spring: false)
}

// MARK: - 过渡动画修饰器

struct PetTransitionModifier: ViewModifier {
    let config: PetTransitionConfig
    @State private var isAnimating = false
    @State private var shakeOffset: CGFloat = 0
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                withDelay(config.delay) {
                    performAnimation()
                }
            }
    }
    
    @ViewBuilder
    private func applyTransition() -> some View {
        switch config.type {
        case .fade:
            applyFade()
        case .scale:
            applyScale()
        case .slide:
            applySlide()
        case .shake:
            applyShake()
        case .bounce:
            applyBounce()
        case .pulse:
            applyPulse()
        case .spin:
            applySpin()
        case .flip:
            applyFlip()
        }
    }
    
    // MARK: - 各种过渡效果
    
    private func applyFade() -> some View {
        EmptyView()
    }
    
    private func applyScale() -> some View {
        EmptyView()
    }
    
    private func applySlide() -> some View {
        EmptyView()
    }
    
    // 抖动效果 - 通过 offset 应用
    private func applyShake() -> some View {
        EmptyView()
    }
    
    // 弹跳效果
    private func applyBounce() -> some View {
        EmptyView()
    }
    
    // 脉冲效果
    private func applyPulse() -> some View {
        EmptyView()
    }
    
    private func applySpin() -> some View {
        EmptyView()
    }
    
    private func applyFlip() -> some View {
        EmptyView()
    }
    
    // MARK: - 动画执行
    
    private func performAnimation() {
        isAnimating = true
        
        switch config.type {
        case .shake:
            performShake()
        case .spin:
            performSpin()
        default:
            break
        }
    }
    
    private func performShake() {
        let shakeCount = 5
        let shakeDuration = config.duration / Double(shakeCount)
        
        for i in 0..<shakeCount {
            withDelay(Double(i) * shakeDuration) {
                withAnimation(.easeInOut(duration: shakeDuration)) {
                    self.shakeOffset = i % 2 == 0 ? 3 : -3
                }
            }
        }
        
        // 复位
        withDelay(config.duration) {
            withAnimation(.easeOut(duration: 0.1)) {
                self.shakeOffset = 0
            }
            self.isAnimating = false
        }
    }
    
    private func performSpin() {
        withAnimation(.linear(duration: config.duration)) {
            rotation = 360
        }
        
        withDelay(config.duration) {
            rotation = 0
            isAnimating = false
        }
    }
}

// MARK: - View 扩展

extension View {
    /// 应用宠物过渡动画
    func petTransition(_ config: PetTransitionConfig) -> some View {
        modifier(PetTransitionModifier(config: config))
    }
    
    /// 快捷过渡动画
    func petFade(duration: Double = 0.3) -> some View {
        petTransition(.fade)
    }
    
    func petShake(duration: Double = 0.4) -> some View {
        petTransition(.init(type: .shake, duration: duration, spring: false))
    }
    
    func petBounce(duration: Double = 0.5) -> some View {
        petTransition(.bounce)
    }
}

// MARK: - 辅助函数

private func withDelay(_ delay: Double, execute: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: execute)
}

// MARK: - 预览

#Preview {
    VStack(spacing: 30) {
        Text("宠物过渡动画测试")
            .font(.headline)
        
        HStack(spacing: 20) {
            // 抖动效果
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red)
                .frame(width: 50, height: 50)
                .petShake()
                .overlay(Text("抖").font(.caption).foregroundColor(.white))
            
            // 弹跳效果
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green)
                .frame(width: 50, height: 50)
                .petBounce()
                .overlay(Text("弹").font(.caption).foregroundColor(.white))
        }
    }
    .padding()
}