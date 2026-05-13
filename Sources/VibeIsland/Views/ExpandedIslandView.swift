import SwiftUI

// MARK: - 标签页位置偏好

private struct TabFrameKey: PreferenceKey {
    static let defaultValue: [ExpandedIslandView.ExpandedTab: CGRect] = [:]
    static func reduce(value: inout [ExpandedIslandView.ExpandedTab: CGRect], nextValue: () -> [ExpandedIslandView.ExpandedTab: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - 展开的灵动岛视图

struct ExpandedIslandView: View {
    @Environment(StateManager.self) private var viewModel
    @State private var selectedTab: ExpandedTab = .sessions
    @State private var tabFrames: [ExpandedTab: CGRect] = [:]
    @State private var tabDirection = 0
    @State private var showSettings = false
    @State private var showSetup = false
    @State private var borderRotation: Double = 0
    @State private var isRefreshing = false
    private var sessionManager: SessionManager { .shared }

    /// 聚合状态用于渐变边框
    private var aggregateState: SessionState {
        sessionManager.aggregateState
    }

    /// 主题管理器
    private var themeManager: ThemeManager {
        viewModel.settings.theme.manager
    }

    /// 展开视图的标签页
    enum ExpandedTab: String, CaseIterable {
        case sessions = "会话"
        case context = "上下文"
        case stats = "统计"

        var icon: String {
            switch self {
            case .sessions: return "terminal"
            case .context: return "brain.fill"
            case .stats: return "chart.bar.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.setupState != .completed && showSetup {
                setupContainer
                    .frame(height: 280)
            } else {
                tabBarSection
                dividerSection
                // 内容区（固定高度），settings 与 tab 共享同一 frame
                contentArea
                    .frame(height: 280)
                    .clipped()
            }
        }
        .padding(12)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(IslandAnimation.expand), value: showSettings)
        .animation(.spring(IslandAnimation.colorChange), value: sessionManager.sortedSessions.first?.sessionId)
        .animation(.spring(IslandAnimation.colorChange), value: viewModel.settings.theme)
        .overlay(alignment: .top) {
            if let notification = viewModel.petNotification {
                petUnlockBanner(notification)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(IslandAnimation.settingsSlide), value: viewModel.petNotification != nil)
        .onAppear {
            viewModel.evaluateSetupState()
            showSetup = viewModel.setupState != .completed
            startBorderRotation()
        }
        .onChange(of: viewModel.settings.theme) { _, newTheme in
            if newTheme == .glass {
                borderRotation = 0
                startBorderRotation()
            }
        }
    }

    // MARK: - 关闭展开视图

    private func closeExpanded() {
        NotificationCenter.default.post(name: .toggleIslandState, object: nil)
    }

    // MARK: - 边框旋转动画

    private func startBorderRotation() {
        guard viewModel.settings.theme == .glass else { return }
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            borderRotation = 360
        }
    }

    // MARK: - 宠物解锁通知横幅

    @ViewBuilder
    private func petUnlockBanner(_ notification: PetUnlockNotification) -> some View {
        HStack(spacing: 8) {
            PetView(petId: notification.pet.rawValue, level: notification.newLevel ?? .basic, scale: 1.5)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.type == .unlock ? "🎉 解锁新宠物" : "⭐ 皮肤升级")
                    .font(.islandBody.weight(.semibold))
                    .foregroundStyle(themeManager.primaryText)
                Text(notification.type == .unlock
                    ? "\(notification.pet.displayName) 加入你的岛！"
                    : "\(notification.pet.displayName) 升至 \(notification.newLevel?.displayName ?? "")")
                    .font(.islandCompact)
                    .foregroundStyle(themeManager.secondaryText)
            }

            Spacer()

            Button {
                viewModel.petNotification = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.islandCaption)
                    .foregroundStyle(themeManager.iconColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(themeManager.selectedBorder, lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .onTapGesture {
            viewModel.petNotification = nil
        }
    }

    // MARK: - Tab Bar Section

    private var tabBarSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(ExpandedTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }

                Spacer()

                Button {
                    closeExpanded()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.islandBody)
                        .foregroundStyle(themeManager.iconColor)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .coordinateSpace(name: "tabBar")
            .onPreferenceChange(TabFrameKey.self) { tabFrames = $0 }

            if let frame = tabFrames[selectedTab] {
                Capsule()
                    .fill(themeManager.selectedBorder)
                    .frame(width: frame.width * 0.7, height: 2)
                    .offset(x: frame.minX + frame.width * 0.15)
                    .animation(.spring(IslandAnimation.tabIndicator), value: selectedTab)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Divider Section

    @ViewBuilder
    private var dividerSection: some View {
        if viewModel.settings.theme == .pixel {
            Text("- - - - - - - - - - - - - - - - -")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(themeManager.normalBorder)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
        } else {
            Divider()
                .opacity(0.2)
        }
    }

    // MARK: - Content Area（Settings 与 Tab 共享同一空间）

    @ViewBuilder
    private var contentArea: some View {
        if showSettings {
            MiniSettingsView(onDismiss: { showSettings = false })
                .environment(viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        } else {
            tabContent
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
    }

    // MARK: - Tab Selection

    private func selectTab(_ tab: ExpandedTab) {
        guard tab != selectedTab else { return }
        let tabs = ExpandedTab.allCases
        guard let fromIndex = tabs.firstIndex(of: selectedTab),
              let toIndex = tabs.firstIndex(of: tab) else { return }
        tabDirection = toIndex > fromIndex ? 1 : -1
        withAnimation(.spring(IslandAnimation.tabSwitch)) {
            selectedTab = tab
        }
    }

    // MARK: - 标签按钮

    private func tabButton(_ tab: ExpandedTab) -> some View {
        Button {
            selectTab(tab)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.islandHeading.weight(.medium))
                Text(tab.rawValue)
                    .font(.islandCompact)
            }
            .foregroundStyle(tabForegroundStyle(for: tab))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab.rawValue)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: TabFrameKey.self,
                        value: [tab: geo.frame(in: .named("tabBar"))])
            }
        )
    }

    // MARK: - 主题感知的标签样式

    private func tabForegroundStyle(for tab: ExpandedTab) -> some ShapeStyle {
        let isSelected = selectedTab == tab
        return isSelected ? themeManager.primaryText : themeManager.mutedText
    }

    // MARK: - 标签内容（带方向感知的滑入过渡）

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .sessions: sessionsTab
            case .context: contextTab
            case .stats: statsTab
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: tabDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: tabDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
        ))
        .id(selectedTab)
    }

    // MARK: - 会话标签

    @ViewBuilder
    private var sessionsTab: some View {
        VStack(spacing: 8) {
            // 会话列表（可滚动）
            ScrollView {
                SessionListView()
                    .environment(viewModel)
            }
            .frame(maxHeight: .infinity)

            // 固定在底部
            footer
        }
    }

    // MARK: - 上下文标签

    @ViewBuilder
    private var contextTab: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: themeManager.spacing) {
                    if let session = sessionManager.trackedSession {
                        if let usage = session.contextUsage, usage > 0 {
                            let snapshot = ContextUsageSnapshot(
                                sessionId: session.sessionId,
                                usageRatio: usage,
                                tokensUsed: session.contextTokensUsed,
                                tokensTotal: session.contextTokensTotal,
                                inputTokens: session.contextInputTokens,
                                outputTokens: session.contextOutputTokens,
                                reasoningTokens: session.contextReasoningTokens,
                                toolUsage: session.toolUsage,
                                skillUsage: session.skillUsage,
                                timestamp: Date()
                            )
                            ContextUsageCard(session: session, snapshot: snapshot, theme: viewModel.settings.theme)
                        } else if session.source == "opencode" {
                            OpenCodeNoContextCard(session: session, theme: viewModel.settings.theme)
                        } else {
                            SessionInfoCard(session: session, theme: viewModel.settings.theme)
                        }
                    } else {
                        emptyContextView
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            footer
        }
    }

    // MARK: - 统计标签

    @ViewBuilder
    private var statsTab: some View {
        VStack(spacing: 8) {
            ScrollView {
                StatsView()
                    .environment(viewModel)
            }
            .frame(maxHeight: .infinity)

            footer
        }
    }

    private var emptyContextView: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 24))
                .foregroundStyle(themeManager.disabledColor)
            Text("暂无会话数据")
                .font(.islandBody)
                .foregroundStyle(themeManager.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var footer: some View {
        HStack {
            // 左下角设置按钮
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.islandCaption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconColor)

            Spacer()

            // 右下角刷新按钮
            Button {
                isRefreshing = true
                sessionManager.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isRefreshing = false
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.islandCaption)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 0.5).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconColor)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            // Glass 主题 — 毛玻璃 + 旋转渐变边框
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .opacity(0.7)
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                aggregateState.color,
                                aggregateState.color.opacity(0.3),
                                aggregateState.color.opacity(0.7),
                                aggregateState.color
                            ]),
                            center: .center,
                            startAngle: .degrees(borderRotation),
                            endAngle: .degrees(borderRotation + 360)
                        ),
                        lineWidth: 2.5
                    )
            }
            .opacity(viewModel.settings.theme == .glass ? 1 : 0)

            // Pixel 主题 — 纯色背景 + 纯色边框
            ZStack {
                Color(white: 0.1)
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(aggregateState.color, lineWidth: 2)
            }
            .opacity(viewModel.settings.theme == .pixel ? 1 : 0)
        }
        .animation(.easeInOut(duration: IslandAnimation.themeChange), value: viewModel.settings.theme)
    }

    // MARK: - 引导设置卡片

    /// 引导设置容器 — 替代标签页内容区域
    @ViewBuilder
    private var setupContainer: some View {
        VStack(spacing: 16) {
            // 右上角关闭按钮
            HStack {
                Spacer()
                Button {
                    closeExpanded()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.islandBody)
                        .foregroundStyle(themeManager.iconColor)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }

            Spacer()

            // 打瞌睡的宠物 — 比 SF Symbol 更有温度
            PetView(petId: "cat", level: .basic, scale: 3.0, initialState: .sleeping)
                .frame(width: 48, height: 48)

            // 基于状态的标题
            Text(setupTitle)
                .font(.islandHeading)
                .foregroundStyle(themeManager.primaryText)

            Text(setupDescription)
                .font(.islandBody)
                .foregroundStyle(themeManager.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // 基于状态的操作按钮
            if viewModel.setupState == .claudeDetected || viewModel.setupState == .opencodeDetected {
                Button(action: {
                    Task { await performSetupAction() }
                }) {
                    Text(setupButtonTitle)
                        .font(.islandBody.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .controlSize(.large)
            }

            // 跳过按钮始终可见
            Button("稍后再说") {
                viewModel.setupState = .completed
                showSetup = false
            }
            .buttonStyle(.plain)
            .font(.islandCompact)
            .foregroundStyle(themeManager.mutedText)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 引导设置文本

    private var setupTitle: String {
        switch viewModel.setupState {
        case .notStarted: return "欢迎使用 Vibe Island"
        case .claudeDetected: return "检测到 Claude Code"
        case .opencodeDetected: return "检测到 OpenCode"
        case .completed: return ""
        }
    }

    private var setupDescription: String {
        switch viewModel.setupState {
        case .notStarted: return "你的 AI 编程伙伴住在刘海里。安装 Claude Code 或 OpenCode 后，我会自动开始工作。"
        case .claudeDetected: return "安装 Hook 来实时监控 Claude Code 会话状态。"
        case .opencodeDetected: return "安装插件来实时监控 OpenCode 会话状态。"
        case .completed: return ""
        }
    }

    private var setupButtonTitle: String {
        switch viewModel.setupState {
        case .claudeDetected: return "🔌 安装 Hook"
        case .opencodeDetected: return "🔌 安装插件"
        default: return ""
        }
    }

    // MARK: - 引导操作

    private func performSetupAction() async {
        switch viewModel.setupState {
        case .claudeDetected:
            let result = await viewModel.installHooks()
            if case .success = result {
                viewModel.evaluateSetupState()
            }
        case .opencodeDetected:
            let result = await viewModel.installOpenCodePlugin()
            if case .success = result {
                viewModel.evaluateSetupState()
            }
        default: break
        }
    }
}
