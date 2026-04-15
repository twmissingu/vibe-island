import SwiftUI
import LLMQuotaKit

struct IslandView: View {
    @Environment(StateManager.self) private var viewModel

    var body: some View {
        Group {
            switch viewModel.islandState {
            case .compact:
                CompactIslandView()
            case .expanded:
                ExpandedIslandView()
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

    var body: some View {
        HStack(spacing: 12) {
            // Session indicator dot
            sessionIndicatorDot

            // Session summary (if active and non-idle)
            if let session = topSession, aggregateState != .idle {
                sessionSummary(session)
            }

            // Context usage indicator (if available)
            if let snapshot = contextSnapshot, snapshot.usageRatio > 0 {
                contextUsageSection(snapshot)
            }

            Divider()
                .frame(height: 16)
                .opacity(0.3)

            // Quota display (existing functionality)
            quotaSection

            // Pet view with session state integration
            if viewModel.settings.petEnabled {
                petView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundView)
        .clipShape(Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: aggregateState)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: topSession?.sessionId)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: contextSnapshot)
    }

    // MARK: - Session Indicator Dot

    @ViewBuilder
    private var sessionIndicatorDot: some View {
        Circle()
            .fill(aggregateState.color)
            .frame(width: 8, height: 8)
            .modifier(BlinkModifier(shouldBlink: shouldBlink))
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
            Text("加载中…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
            Text("点击添加 API Key")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Session Summary

    @ViewBuilder
    private func sessionSummary(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: sessionStateIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(aggregateState.color)
                Text(aggregateState.displayName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(aggregateState.color)
            }
            if let name = session.sessionName {
                Text(name)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 80, alignment: .leading)
            }
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
        case .thinking: return "brain.head.filled"
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
        PetView()
            .frame(width: 20, height: 20)
            .modifier(SessionPetEffect(state: aggregateState))
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        switch viewModel.settings.theme {
        case .glass:
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        case .pixel:
            Color(white: 0.12)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color(white: 0.3), lineWidth: 2)
                )
        }
    }
}

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
