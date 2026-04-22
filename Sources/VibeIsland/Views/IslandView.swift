import SwiftUI
import LLMQuotaKit

struct IslandView: View {
    @Environment(StateManager.self) private var viewModel

    var body: some View {
        Group {
            switch viewModel.islandState {
            case .compact:
                CompactIslandView()
                    .accessibilityIdentifier("compactIslandView")
            case .expanded:
                ExpandedIslandView()
                    .accessibilityIdentifier("expandedIslandView")
            }
        }
        .onTapGesture {
            viewModel.toggleIslandState()
        }
    }
}

// MARK: - Compact

struct CompactIslandView: View {
    @Environment(StateManager.self) private var viewModel
    private var sessionManager: SessionManager { .shared }
    private var contextMonitor: ContextMonitor { .shared }

    private var primaryQuota: QuotaInfo? {
        viewModel.quotas
            .filter { $0.isHealthy }
            .sorted { $0.usageRatio > $1.usageRatio }
            .first
    }

    private var topSession: Session? {
        sessionManager.sortedSessions.first
    }

    private var aggregateState: SessionState {
        sessionManager.aggregateState
    }

    private var contextSnapshot: ContextUsageSnapshot? {
        contextMonitor.topSnapshot
    }

    /// Whether the session state should blink
    private var shouldBlink: Bool {
        aggregateState.isBlinking
    }
    
    /// Whether to animate brackets on state change
    @State private var animateBrackets = false

    var body: some View {
        HStack(spacing: 0) {
            // Left parenthesis
            Text("(")
                .foregroundColor(aggregateState.color)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .baselineOffset(2)
                .offset(x: animateBrackets ? -4.0 : 0)

            Spacer().frame(width: 8)

            // Session indicator dot (left aligned)
            sessionIndicatorDot

            Spacer() // Middle notch area

            // Pet view with session state integration (fixed width regardless of enable status)
            Group {
                if viewModel.settings.petEnabled {
                    let selectedPet = PetType(rawValue: viewModel.settings.selectedPetID) ?? .cat
                    let skinLevel = PetProgressManager.shared.selectedLevel(for: selectedPet)
                    PetView(petId: viewModel.settings.selectedPetID, level: skinLevel, scale: 1.0)
                        .modifier(SessionPetEffect(state: aggregateState))
                } else {
                    Color.clear
                }
            }
            .frame(width: 20, height: 20) // Match pet view size to keep layout consistent

            Spacer().frame(width: 8)

            // Right parenthesis
            Text(")")
                .foregroundColor(aggregateState.color)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .baselineOffset(2)
                .offset(x: animateBrackets ? 4.0 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(height: 44) // Fixed height only, width determined by parent panel
        .background(backgroundView)
        .clipShape(Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: aggregateState)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: topSession?.sessionId)

        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.settings.petEnabled)
        .onChange(of: aggregateState) { _, _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                animateBrackets = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    animateBrackets = false
                }
            }
        }
    }


    // MARK: - Quota Section

    @ViewBuilder
    private var quotaSection: some View {
        if let quota = primaryQuota {
            CompactProgressBar(ratio: quota.usageRatio)
                .frame(width: 80)

            Text("\(quota.provider.displayName) \(quota.remainingPercent)%")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            Text(quota.formattedRemaining)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        } else if viewModel.isLoading {
            ProgressView()
                .controlSize(.small)
            Text("Loading…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
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
            Text(toolSourceName(for: session))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    /// 根据会话来源返回工具名称
    private func toolSourceName(for session: Session) -> String {
        switch session.source {
        case "opencode": return "OpenCode"
        default: return "Claude"
        }
    }

    // MARK: - Context Usage Section

    @ViewBuilder
    private func contextUsageSection(_ snapshot: ContextUsageSnapshot) -> some View {
        ContextUsageView(snapshot: snapshot)
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
        PetView(scale: 1.0)
            .frame(width: 20, height: 20)
            .modifier(SessionPetEffect(state: aggregateState))
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        Color.black
    }
    // MARK: - 发光效果状态指示器

    @ViewBuilder
    private var sessionIndicatorDot: some View {
        ZStack {
            // 外层发光
            Circle()
                .fill(aggregateState.color.opacity(0.3))
                .frame(width: 20, height: 20)
                .blur(radius: 4)
            
            // 主圆点
            Circle()
                .fill(aggregateState.color)
                .frame(width: 12, height: 12)
                .shadow(color: aggregateState.color.opacity(0.5), radius: 4, x: 0, y: 0)
        }
        .modifier(BlinkModifier(shouldBlink: shouldBlink))
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

// MARK: - Blink Modifier

struct BlinkModifier: ViewModifier {
    let shouldBlink: Bool
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
            .onAppear {
                if shouldBlink {
                    startBlink()
                }
            }
    }

    private func startBlink() {
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            opacity = 0.2
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
