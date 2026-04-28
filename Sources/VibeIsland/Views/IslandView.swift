import SwiftUI

// 全局单例存储屏幕参数
@MainActor
@Observable
final class ScreenParameters {
    static let shared = ScreenParameters()
    var notchWidth: CGFloat = 0
    var screenHeight: CGFloat = 0
    /// 菜单栏高度，通过屏幕可见区域差值计算
    var menuBarHeight: CGFloat = 24.0
    
    private init() {
        updateFromScreen()
    }
    
    func updateFromScreen() {
        if let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 24 }) 
            ?? NSScreen.main {
            if let leftArea = screen.auxiliaryTopLeftArea,
               let rightArea = screen.auxiliaryTopRightArea {
                notchWidth = screen.frame.width - leftArea.width - rightArea.width
            }
            screenHeight = screen.frame.height
            // 菜单栏高度 = 屏幕总高度 - 可见区域顶部Y坐标
            menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            // 兜底：如果计算结果异常，使用系统默认值
            if menuBarHeight < 10 { menuBarHeight = 24.0 }
        }
    }
}

// 自定义环境变量：控制紧凑/展开模式
struct IsExpandedModeKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var isExpandedMode: Bool? {
        get { self[IsExpandedModeKey.self] }
        set { self[IsExpandedModeKey.self] = newValue }
    }
}

struct IslandView: View {
    @Environment(StateManager.self) private var viewModel
    @Environment(\.isExpandedMode) private var isExpandedMode

    private var displayExpanded: Bool {
        if let forced = isExpandedMode {
            return forced
        }
        return viewModel.islandState == .expanded
    }
    
    var body: some View {
        Group {
            if displayExpanded {
                ExpandedIslandView()
                    .accessibilityIdentifier("expandedIslandView")
            } else {
                CompactIslandView()
                    .accessibilityIdentifier("compactIslandView")
            }
        }
        .onTapGesture {
            // 通知切换
            NotificationCenter.default.post(name: .toggleIslandState, object: nil)
        }
    }
}

// MARK: - Compact

struct CompactIslandView: View {
    @Environment(StateManager.self) private var viewModel
    private var sessionManager: SessionManager { .shared }
    private var contextMonitor: ContextMonitor { .shared }

    private var topSession: Session? {
        sessionManager.trackedSession
    }

    private var aggregateState: SessionState {
        sessionManager.trackedSessionState
    }

    private var contextSnapshot: ContextUsageSnapshot? {
        contextMonitor.topSnapshot
    }

    /// 当前会话的上下文使用百分比
    private var sessionContextPercent: String? {
        guard let percent = contextPercentInt else { return nil }
        return "\(percent)%"
    }
    
    /// 当前会话的上下文使用率（0-100 整数）
    private var contextPercentInt: Int? {
        guard let session = topSession else { return nil }
        
        // 优先从快照获取
        if let snapshot = contextMonitor.snapshot(for: session.sessionId), snapshot.usageRatio > 0 {
            return snapshot.usagePercent
        }
        
        // 回退到 Session 模型的 contextUsage 字段
        if let usage = session.contextUsage, usage > 0 {
            return Int(usage * 100)
        }
        
        return nil
    }
    
    /// 上下文百分比的颜色（<40% 绿色，40%-70% 橙色，>70% 红色）
    private var contextPercentColor: Color {
        guard let percent = contextPercentInt else { return .gray }
        if percent < 40 {
            return .green
        } else if percent < 70 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// 上下文百分比是否需要闪烁
    private var shouldBlinkContext: Bool {
        guard let percent = contextPercentInt else { return false }
        return percent >= 40
    }
    
    /// 上下文百分比闪烁间隔（40%-70% 为 1s，>70% 为 0.5s）
    private var contextBlinkInterval: Double {
        guard let percent = contextPercentInt else { return 0 }
        if percent >= 70 {
            return 0.5
        } else if percent >= 40 {
            return 1.0
        }
        return 0
    }

    /// Whether the session state should blink
    private var shouldBlink: Bool {
        aggregateState.isBlinking
    }
    
    /// 是否需要动画括号（等待权限/错误/压缩中/完成）
    private var shouldAnimateBrackets: Bool {
        switch aggregateState {
        case .waitingPermission, .error, .compacting, .completed: return true
        default: return false
        }
    }
    
    /// 括号动画服务
    @State private var bracketAnimation = BracketAnimationService()

    var body: some View {
        // 获取菜单栏高度和刘海宽度
        let barHeight = ScreenParameters.shared.menuBarHeight
        let notchWidth = ScreenParameters.shared.notchWidth
        // 宠物缩放：16px × scale ≤ barHeight，固定 1.2（16×1.2=19.2pt）
        let petScale: CGFloat = 1.2
        // 宠物区域宽度：预留动画溢出空间（shake±3pt + 旋转≈1pt + 余量）
        let indicatorWidth: CGFloat = 28
        // 非宠物元素的缩放比（基于原 44pt 布局）
        let uiScale = barHeight / 44.0

        HStack(spacing: 8 * uiScale) {
            // Left parenthesis with glow (blur + shadow)
            ZStack {
                Text("(")
                    .foregroundColor(aggregateState.color.opacity(0.4))
                    .font(.system(size: 24 * uiScale, weight: .bold, design: .monospaced))
                    .baselineOffset(2 * uiScale)
                    .blur(radius: 3 * uiScale)
                
                Text("(")
                    .foregroundColor(aggregateState.color)
                    .font(.system(size: 24 * uiScale, weight: .bold, design: .monospaced))
                    .baselineOffset(2 * uiScale)
                    .shadow(color: aggregateState.color.opacity(0.6), radius: 3 * uiScale)
            }
            .offset(x: bracketAnimation.isExpanded ? -4.0 * uiScale : 0)

            // Session indicator dot
            sessionIndicatorDot

            // 刘海占位 - 保证左右元素在刘海外侧显示
            Spacer().frame(width: notchWidth)

            // Pet view with session state integration
            Group {
                if viewModel.settings.petEnabled {
                    let selectedPet = PetType(rawValue: viewModel.settings.selectedPetID) ?? .cat
                    let skinLevel = PetProgressManager.shared.selectedLevel(for: selectedPet)
                    PetView(petId: viewModel.settings.selectedPetID, level: skinLevel, scale: petScale, initialState: Self.mapToPetState(aggregateState))
                        .modifier(SessionPetEffect(state: aggregateState))
                } else {
                    Color.clear
                }
            }
            .frame(width: indicatorWidth, height: barHeight)

            // Right parenthesis with glow (blur + shadow)
            ZStack {
                Text(")")
                    .foregroundColor(aggregateState.color.opacity(0.4))
                    .font(.system(size: 24 * uiScale, weight: .bold, design: .monospaced))
                    .baselineOffset(2 * uiScale)
                    .blur(radius: 3 * uiScale)
                
                Text(")")
                    .foregroundColor(aggregateState.color)
                    .font(.system(size: 24 * uiScale, weight: .bold, design: .monospaced))
                    .baselineOffset(2 * uiScale)
                    .shadow(color: aggregateState.color.opacity(0.6), radius: 3 * uiScale)
            }
            .offset(x: bracketAnimation.isExpanded ? 4.0 * uiScale : 0)
        }
        .padding(.horizontal, 16 * uiScale)
        .padding(.vertical, 10 * uiScale)
        .frame(height: barHeight) // 与菜单栏高度一致
        .background(backgroundView)
        .clipShape(Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: aggregateState)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: topSession?.sessionId)

        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.settings.petEnabled)
        .animation(.easeInOut(duration: 1.0), value: bracketAnimation.isExpanded)
        .onChange(of: aggregateState) { _, _ in
            if shouldAnimateBrackets {
                bracketAnimation.start()
            } else {
                bracketAnimation.stop()
            }
        }
    }
    
    // MARK: - SessionState → PetState 映射

    private static func mapToPetState(_ sessionState: SessionState) -> PetState {
        switch sessionState {
        case .idle: return .idle
        case .thinking: return .thinking
        case .coding: return .coding
        case .waiting: return .waiting
        case .waitingPermission: return .waiting
        case .completed: return .celebrating
        case .error: return .error
        case .compacting: return .compacting
        }
    }


    // MARK: - Session Summary

    @ViewBuilder
    private func sessionSummary(_ session: Session) -> some View {
        HStack(spacing: 6) {
            // 状态图标 + 名称
            HStack(spacing: 3) {
                Image(systemName: sessionStateIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(aggregateState.color)
                Text(aggregateState.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(aggregateState.color)
            }
            .frame(width: 72, alignment: .leading)

            // 会话名
            Text(session.sessionName ?? (session.cwd as NSString).lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 工具来源
            Text(session.toolDisplayName)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var sessionStateIcon: String {
        switch aggregateState {
        case .idle: return "checkmark.circle.fill"
        case .thinking: return "brain.fill"
        case .coding: return "hammer.fill"
        case .waiting: return "text.bubble.fill"
        case .waitingPermission: return "lock.shield.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .compacting: return "arrow.up.arrow.down.circle.fill"
        }
    }

    // MARK: - Pet View with Effects

    @ViewBuilder
    private var petView: some View {
        let barHeight = ScreenParameters.shared.menuBarHeight
        let petScale: CGFloat = 1.2
        PetView(scale: petScale, initialState: Self.mapToPetState(aggregateState))
            .frame(width: 28, height: barHeight)
            .modifier(SessionPetEffect(state: aggregateState))
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        Color.black
    }
    // MARK: - 上下文使用率指示器（替代圆点）

    @ViewBuilder
    private var sessionIndicatorDot: some View {
        let uiScale = ScreenParameters.shared.menuBarHeight / 44.0
        
if sessionContextPercent != nil {
            let color = contextPercentColor
            let contextNeedsBlink = shouldBlinkContext
            let contextBlinkInterval = contextBlinkInterval
            
            ZStack {
                // Glow layer
                Text(sessionContextPercent ?? "")
                    .font(.system(size: 12 * uiScale, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(color.opacity(0.3))
                    .blur(radius: 2 * uiScale)
                
                // Main text
                Text(sessionContextPercent ?? "")
                    .font(.system(size: 12 * uiScale, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.6), radius: 3 * uiScale, x: 0, y: 0)
            }
            .frame(width: 28, height: ScreenParameters.shared.menuBarHeight)
            .modifier(BlinkModifier(shouldBlink: contextNeedsBlink, blinkInterval: contextBlinkInterval))
        } else {
            ZStack {
                Circle()
                    .fill(aggregateState.color.opacity(0.3))
                    .frame(width: 12 * uiScale, height: 12 * uiScale)
                    .blur(radius: 4 * uiScale)
                
                Circle()
                    .fill(aggregateState.color)
                    .frame(width: 8 * uiScale, height: 8 * uiScale)
                    .shadow(color: aggregateState.color.opacity(0.5), radius: 3 * uiScale, x: 0, y: 0)
            }
            .frame(width: 28, height: ScreenParameters.shared.menuBarHeight)
            .modifier(BlinkModifier(shouldBlink: shouldBlink, blinkInterval: aggregateState == .completed ? 1.0 : 0))
        }
    }

    // MARK: - 波纹动画效果
    @ViewBuilder
    private func rippleEffect(color: Color) -> some View {
        RippleAnimationView(color: color)
    }
}


// MARK: - Ripple Animation View

struct RippleAnimationView: View {
    let color: Color
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.8
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: 24, height: 24)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                startAnimation()
            }
            .onChange(of: color) { _, _ in
                resetAnimation()
                startAnimation()
            }
    }
    
    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        withAnimation(.easeOut(duration: 0.8).repeatForever(autoreverses: false)) {
            scale = 1.5
            opacity = 0
        }
    }
    
    private func resetAnimation() {
        isAnimating = false
        scale = 0.5
        opacity = 0.8
    }
}

// MARK: - Blink Modifier

struct BlinkModifier: ViewModifier {
    let shouldBlink: Bool
    var blinkInterval: Double = 0
    @State private var opacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .opacity(shouldBlink ? opacity : 1.0)
            .onChange(of: shouldBlink) { _, isBlinking in
                if isBlinking {
                    startBlink()
                } else {
                    opacity = 1.0
                }
            }
            .onChange(of: blinkInterval) { _, newInterval in
                if shouldBlink && newInterval > 0 {
                    startBlink()
                }
            }
            .onAppear {
                if shouldBlink {
                    startBlink()
                }
            }
    }

    private func startBlink() {
        withAnimation(.easeInOut(duration: blinkInterval / 2).repeatForever(autoreverses: true)) {
            opacity = 0.5
        }
    }
}

// MARK: - Compact Progress Bar

struct CompactProgressBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(barColor)
                    .frame(width: geo.size.width * min(ratio, 1.0))
            }
        }
        .frame(height: 6)
    }

    private var barColor: Color {
        if ratio >= 0.95 { return .red }
        if ratio >= 0.8 { return .orange }
        if ratio >= 0.5 { return .yellow }
        return .green
    }
}

// MARK: - VisualEffectView (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Session Pet Effect Modifier

/// 根据会话状态为宠物添加特效
struct SessionPetEffect: ViewModifier {
    let state: SessionState

    func body(content: Content) -> some View {
        Group {
            switch state {
            case .waitingPermission:
                content.modifier(PetShakeEffect())
            case .error:
                content.modifier(PetGlowEffect(color: .red))
            case .compacting:
                content.modifier(PetGlowEffect(color: .orange))
            default:
                content
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state)
    }
}

// MARK: - Pet Effect Primitives

/// 抖动特效
struct PetShakeEffect: ViewModifier {
    @State private var angle: Double = 0
    @State private var started = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard !started else { return }
                started = true
                withAnimation(.easeInOut(duration: 0.08).repeatForever(autoreverses: true)) {
                    angle = 6
                }
            }
    }
}

/// 发光特效
struct PetGlowEffect: ViewModifier {
    let color: Color
    @State private var radius: CGFloat = 2
    @State private var opacity: Double = 0.3
    @State private var started = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
            .onAppear {
                guard !started else { return }
                started = true
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    radius = 6
                    opacity = 0.7
                }
            }
    }
}

/// 无操作（identity modifier）
struct IdentityModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
