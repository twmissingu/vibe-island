import SwiftUI

// MARK: - 像素宠物视图（增强版）
/// 包含粒子效果、过渡动画和物理效果
struct PetView: View {
    @State private var petEngine: PetEngine
    @State private var currentFrameIndex = 0
    @State private var animationTimer: Timer?
    
    // 物理效果状态
    @State private var shakeOffset: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    // 粒子效果状态
    @State private var showConfetti = false
    @State private var showExclamation = false
    @State private var showCompression = false
    
    let scale: CGFloat  // 像素缩放倍数
    let petId: String // 宠物ID
    private let petLevel: PetLevel  // 皮肤等级
    /// 外部驱动的宠物状态（从 SessionState 映射而来）
    let externalState: PetState

    init(petId: String = "cat", level: PetLevel = .basic, scale: CGFloat = 4.0, initialState: PetState = .idle) {
        // 根据petId和level加载对应的动画集
        let petType = PetType(rawValue: petId) ?? .cat
        let animationSet = PetAnimationSet.forPet(petType, level: level)
        _petEngine = State(initialValue: PetEngine(state: initialState, animationSet: animationSet))
        self.scale = scale
        self.petId = petId
        self.petLevel = level
        self.externalState = initialState
    }

    // 支持 Int 类型的初始化
    init(petId: String, level: Int, scale: CGFloat = 4.0, initialState: PetState = .idle) {
        let petLevel = PetLevel(rawValue: level) ?? .basic
        let petType = PetType(rawValue: petId) ?? .cat
        let animationSet = PetAnimationSet.forPet(petType, level: petLevel)
        _petEngine = State(initialValue: PetEngine(state: initialState, animationSet: animationSet))
        self.scale = scale
        self.petId = petId
        self.petLevel = petLevel
        self.externalState = initialState
    }
    
    var body: some View {
        ZStack {
            // 粒子覆盖层
            particleOverlay
            
            // 宠物渲染
            petCanvas
        }
        // 外部状态变化时同步到内部引擎
        .onChange(of: externalState) { _, newState in
            petEngine.state = newState
        }
        // 状态变化时触发物理效果
        .onChange(of: petEngine.state) { oldValue, newValue in
            handleStateTransition(from: oldValue, to: newValue)
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    // MARK: - 粒子覆盖层
    
    @ViewBuilder
    private var particleOverlay: some View {
        // 庆祝 - 彩带粒子
        if showConfetti {
            ParticleOverlayView(type: .confetti, intensity: .high, autoStart: true)
                .allowsHitTesting(false)
        }
        
        // 错误 - 感叹号粒子
        if showExclamation {
            ParticleOverlayView(type: .exclamation, intensity: .medium, autoStart: true)
                .allowsHitTesting(false)
        }
        
        // 压缩 - 压缩粒子
        if showCompression {
            ParticleOverlayView(type: .compression, intensity: .medium, autoStart: true)
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - 宠物画布渲染
    
    private var petCanvas: some View {
        Canvas { context, size in
            let frames = petEngine.animationSet.frames(for: petEngine.state)
            guard !frames.isEmpty else { return }

            let frame = frames[currentFrameIndex % frames.count]
            let pixelSize = scale

            for pixel in frame.pixels {
                let rect = CGRect(
                    x: CGFloat(pixel.x) * pixelSize,
                    y: CGFloat(pixel.y) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )

                if let color = Color(hex: pixel.color) {
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(
            width: CGFloat(petEngine.animationSet.frames(for: petEngine.state).first?.width ?? 16) * scale,
            height: CGFloat(petEngine.animationSet.frames(for: petEngine.state).first?.height ?? 16) * scale
        )
        // 应用物理效果
        .offset(x: shakeOffset, y: bounceOffset)
        .scaleEffect(pulseScale)
    }
    
    // MARK: - 状态过渡处理
    
    private func handleStateTransition(from oldValue: PetState, to newValue: PetState) {
        // 1. 粒子效果触发
        handleParticleTrigger(for: newValue)
        
        // 2. 物理效果触发
        handlePhysicsEffect(for: newValue)
        
        // 3. 重置动画帧
        currentFrameIndex = 0
        startAnimation()
    }
    
    private func handleParticleTrigger(for state: PetState) {
        // 先清除所有粒子
        showConfetti = false
        showExclamation = false
        showCompression = false
        
        // 根据状态触发对应粒子效果
        switch state {
        case .celebrating:
            showConfetti = true
            // 2秒后自动停止
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showConfetti = false
            }
        case .error:
            showExclamation = true
            // 持续显示直到状态改变
        case .compacting:
            showCompression = true
        default:
            // 其他状态不显示特殊粒子
            break
        }
    }
    
    private func handlePhysicsEffect(for state: PetState) {
        // 停止所有当前物理效果
        stopAllPhysicsEffects()
        
        switch state {
        case .waiting:
            // 等待状态 - 抖动效果
            startShakeEffect()
        case .celebrating:
            // 庆祝状态 - 弹跳效果
            startBounceEffect()
        case .error:
            // 错误状态 - 脉冲效果
            startPulseEffect()
        default:
            break
        }
    }
    
    // MARK: - 物理效果实现
    
    private func startShakeEffect() {
        let shakeCount = 10
        let shakeDuration = 0.05
        
        for i in 0..<shakeCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * shakeDuration) {
                withAnimation(.easeInOut(duration: shakeDuration)) {
                    self.shakeOffset = i % 2 == 0 ? 3 : -3
                }
            }
        }
        
        // 复位
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(shakeCount) * shakeDuration) {
            withAnimation(.easeOut(duration: 0.1)) {
                self.shakeOffset = 0
            }
        }
    }
    
    private func startBounceEffect() {
        let bounceCount = 3
        let bounceDuration = 0.15
        
        for i in 0..<bounceCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * bounceDuration * 2) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                    self.bounceOffset = i % 2 == 0 ? -8 : 0
                }
            }
        }
        
        // 复位
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(bounceCount) * bounceDuration * 2) {
            withAnimation(.easeOut(duration: 0.1)) {
                self.bounceOffset = 0
            }
        }
    }
    
    private func startPulseEffect() {
        let pulseCount = 3
        let pulseDuration = 0.2
        
        for i in 0..<pulseCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * pulseDuration) {
                withAnimation(.easeInOut(duration: pulseDuration / 2)) {
                    self.pulseScale = 1.15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + pulseDuration / 2) {
                    withAnimation(.easeInOut(duration: pulseDuration / 2)) {
                        self.pulseScale = 1.0
                    }
                }
            }
        }
    }
    
    private func stopAllPhysicsEffects() {
        shakeOffset = 0
        bounceOffset = 0
        pulseScale = 1.0
    }
    
    // MARK: - 动画控制
    
    private func startAnimation() {
        animationTimer?.invalidate()
        let frames = petEngine.animationSet.frames(for: petEngine.state)
        // 单帧状态无需帧动画定时器，但保留以支持状态切换后的帧重置
        guard frames.count > 1 else { return }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [self] _ in
            Task { @MainActor [self] in
                self.currentFrameIndex = (self.currentFrameIndex + 1) % frames.count
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    /// 更新宠物状态
    func updateState(_ state: PetState) {
        petEngine.state = state
    }
}

// MARK: - Color hex 初始化扩展
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - 宠物引擎 - 管理状态和动画
class PetEngine: ObservableObject {
    @Published var state: PetState
    let animationSet: PetAnimationSet
    
    init(state: PetState, animationSet: PetAnimationSet? = nil) {
        self.state = state
        self.animationSet = animationSet ?? PixelPetGenerator.generateAnimationSet()
    }
    
    func updateState(_ newState: PetState) {
        state = newState
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        Text("像素宠物渲染原型测试")
            .font(.headline)
        
        PetView(scale: 4.0)
            .frame(width: 100, height: 100)
        
        Text("状态: idle")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .frame(width: 200, height: 200)
}