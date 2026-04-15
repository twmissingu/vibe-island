import SwiftUI

/// 像素宠物渲染器 - 使用 SwiftUI Canvas 渲染像素帧
struct PetView: View {
    @State private var petEngine: PetEngine
    @State private var currentFrameIndex = 0
    @State private var animationTimer: Timer?
    
    let scale: CGFloat  // 像素缩放倍数
    
    init(scale: CGFloat = 4.0) {
        _petEngine = State(initialValue: PetEngine(state: .idle))
        self.scale = scale
    }
    
    var body: some View {
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
        // 禁用抗锯齿，保持像素边缘锐利（与 UI 设计文档 4.3 节一致）
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: petEngine.state) { _, _ in
            currentFrameIndex = 0
            startAnimation()
        }
    }
    
    private func startAnimation() {
        animationTimer?.invalidate()
        let frames = petEngine.animationSet.frames(for: petEngine.state)
        guard frames.count > 1 else { return }
        
        let petView = self
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in
                petView.currentFrameIndex = (petView.currentFrameIndex + 1) % frames.count
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

/// Color hex 初始化扩展
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

/// 宠物引擎 - 管理状态和动画
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
