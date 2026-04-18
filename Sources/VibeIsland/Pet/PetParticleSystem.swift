import SwiftUI

// MARK: - 粒子效果系统

/// 粒子类型
enum ParticleType {
    case confetti      // 庆祝 - 彩带
    case exclamation   // 错误 - 感叹号
    case compression   // 压缩 - 压缩指示
    case sparkle       // 通用 - 闪光
    case heart         // 完成 - 爱心
    case zzz           // 睡眠 - Zzz
    
    var colors: [Color] {
        switch self {
        case .confetti:
            return [.red, .yellow, .green, .blue, .purple, .orange]
        case .exclamation:
            return [.red, .orange]
        case .compression:
            return [.orange, .yellow]
        case .sparkle:
            return [.white, .yellow, .cyan]
        case .heart:
            return [.pink, .red]
        case .zzz:
            return [.blue, .cyan]
        }
    }
}

/// 单个粒子
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat
    var color: Color
    var opacity: Double
    var rotation: Double
    var rotationSpeed: Double
    var lifetime: Double
    var maxLifetime: Double
}

/// 粒子系统管理器
@MainActor
class PetParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    @Published var isEmitting = false
    
    private var emissionTimer: Timer?
    private var updateTimer: Timer?
    private var currentType: ParticleType = .sparkle
    private var emissionCount = 0
    private let maxEmissions = 50
    
    // MARK: - 发射控制
    
    func startEmission(type: ParticleType, intensity: Intensity = .medium) {
        stopEmission()
        
        currentType = type
        isEmitting = true
        emissionCount = 0
        
        let interval = emissionInterval(for: intensity)
        
        emissionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isEmitting else { return }
                
                self.emitParticle(type: type)
                self.emissionCount += 1
                
                // 限制最大发射数量
                if self.emissionCount >= self.maxEmissions {
                    self.stopEmission()
                }
            }
        }
        
        // 启动更新定时器
        startUpdateTimer()
    }
    
    func stopEmission() {
        isEmitting = false
        emissionTimer?.invalidate()
        emissionTimer = nil
    }
    
    func clearParticles() {
        particles.removeAll()
        stopEmission()
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - 粒子发射
    
    private func emitParticle(type: ParticleType) {
        let colors = type.colors
        let color = colors.randomElement() ?? .white
        
        let particle = Particle(
            position: randomEmissionPosition(),
            velocity: randomVelocity(for: type),
            size: randomSize(for: type),
            color: color,
            opacity: 1.0,
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -180...180),
            lifetime: 0,
            maxLifetime: randomLifetime(for: type)
        )
        
        particles.append(particle)
    }
    
    // MARK: - 粒子更新
    
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateParticles()
            }
        }
    }
    
    private func updateParticles() {
        let deltaTime: Double = 1.0/60.0
        
        for index in stride(from: particles.count - 1, through: 0, by: -1) {
            var particle = particles[index]
            
            // 更新位置
            particle.position.x += particle.velocity.dx * CGFloat(deltaTime)
            particle.position.y += particle.velocity.dy * CGFloat(deltaTime)
            
            // 更新旋转
            particle.rotation += particle.rotationSpeed * deltaTime
            
            // 更新生命周期
            particle.lifetime += deltaTime
            
            // 更新透明度（淡出效果）
            let lifeRatio = particle.lifetime / particle.maxLifetime
            particle.opacity = 1.0 - lifeRatio
            
            // 移除过期粒子
            if particle.lifetime >= particle.maxLifetime {
                particles.remove(at: index)
            } else {
                particles[index] = particle
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func randomEmissionPosition() -> CGPoint {
        // 在宠物周围随机位置发射
        let centerX: CGFloat = 32  // 16x16 像素的中心
        let centerY: CGFloat = 32
        let radius: CGFloat = 20
        
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = Double.random(in: 0...1) * radius
        
        return CGPoint(
            x: centerX + CGFloat(cos(angle) * distance),
            y: centerY + CGFloat(sin(angle) * distance)
        )
    }
    
    private func randomVelocity(for type: ParticleType) -> CGVector {
        let speed: CGFloat
        switch type {
        case .confetti: speed = 30
        case .exclamation: speed = 20
        case .compression: speed = 15
        case .sparkle: speed = 25
        case .heart: speed = 20
        case .zzz: speed = 10
        }
        
        let angle = Double.random(in: 0...(2 * .pi))
        return CGVector(
            dx: cos(angle) * speed,
            dy: sin(angle) * speed
        )
    }
    
    private func randomSize(for type: ParticleType) -> CGFloat {
        switch type {
        case .confetti: return CGFloat.random(in: 2...4)
        case .exclamation: return CGFloat.random(in: 3...5)
        case .compression: return CGFloat.random(in: 2...3)
        case .sparkle: return CGFloat.random(in: 2...4)
        case .heart: return CGFloat.random(in: 3...5)
        case .zzz: return CGFloat.random(in: 4...6)
        }
    }
    
    private func randomLifetime(for type: ParticleType) -> Double {
        switch type {
        case .confetti: return 1.5
        case .exclamation: return 1.0
        case .compression: return 0.8
        case .sparkle: return 1.2
        case .heart: return 1.5
        case .zzz: return 2.0
        }
    }
    
    private func emissionInterval(for intensity: Intensity) -> TimeInterval {
        switch intensity {
        case .low: return 0.1
        case .medium: return 0.05
        case .high: return 0.03
        }
    }
}

// MARK: - 强度枚举

enum Intensity {
    case low      // 低强度
    case medium   // 中强度
    case high     // 高强度
}

// MARK: - 粒子覆盖层视图

struct ParticleOverlayView: View {
    @StateObject private var particleSystem = PetParticleSystem()
    let type: ParticleType
    let intensity: Intensity
    let autoStart: Bool
    
    init(type: ParticleType, intensity: Intensity = .medium, autoStart: Bool = true) {
        self.type = type
        self.intensity = intensity
        self.autoStart = autoStart
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0, paused: false)) { timeline in
            Canvas { context, size in
                for particle in particleSystem.particles {
                    let rect = CGRect(
                        x: particle.position.x - particle.size/2,
                        y: particle.position.y - particle.size/2,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    context.opacity = particle.opacity
                    
                    // 根据粒子类型绘制不同形状
                    switch type {
                    case .confetti, .sparkle:
                        // 旋转矩形（彩带效果）
                        var transform = CGAffineTransform(translationX: particle.position.x, y: particle.position.y)
                        transform = transform.rotated(by: CGFloat(particle.rotation * .pi / 180))
                        transform = transform.translatedBy(x: -particle.position.x, y: -particle.position.y)
                        
                        let rotatedRect = rect.applying(transform)
                        context.fill(Path(rotatedRect), with: .color(particle.color))
                        
                    case .heart:
                        // 简化的心形（两个圆形+三角形）
                        let circle1 = CGRect(x: rect.midX - particle.size/3, y: rect.minY, width: particle.size/2, height: particle.size/2)
                        let circle2 = CGRect(x: rect.midX, y: rect.minY, width: particle.size/2, height: particle.size/2)
                        context.fill(Path(circle1), with: .color(particle.color))
                        context.fill(Path(circle2), with: .color(particle.color))
                        context.fill(Path(rect), with: .color(particle.color))
                        
                    case .zzz:
                        // Z 字形
                        let path = Path { path in
                            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                        }
                        context.stroke(path, with: .color(particle.color), lineWidth: 1)
                        
                    default:
                        // 默认圆形
                        context.fill(Path(rect), with: .color(particle.color))
                    }
                }
            }
        }
        .onAppear {
            if autoStart {
                particleSystem.startEmission(type: type, intensity: intensity)
            }
        }
        .onDisappear {
            particleSystem.clearParticles()
        }
    }
    
    // 外部控制方法
    func start() {
        particleSystem.startEmission(type: type, intensity: intensity)
    }
    
    func stop() {
        particleSystem.stopEmission()
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        Text("粒子效果测试")
            .font(.headline)
        
        HStack(spacing: 20) {
            VStack {
                Text("庆祝")
                    .font(.caption)
                ParticleOverlayView(type: .confetti, intensity: .high)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack {
                Text("错误")
                    .font(.caption)
                ParticleOverlayView(type: .exclamation, intensity: .medium)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack {
                Text("睡眠")
                    .font(.caption)
                ParticleOverlayView(type: .zzz, intensity: .low)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    .padding()
}