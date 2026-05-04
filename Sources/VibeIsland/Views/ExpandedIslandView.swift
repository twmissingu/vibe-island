import SwiftUI

// MARK: - 展开的灵动岛视图

struct ExpandedIslandView: View {
    @Environment(StateManager.self) private var viewModel
    @State private var selectedTab: ExpandedTab = .sessions
    @State private var showSettings = false
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

        var icon: String {
            switch self {
            case .sessions: return "terminal"
            case .context: return "brain.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标签页切换 + 关闭按钮
            HStack(spacing: 4) {
                ForEach(ExpandedTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
                
                Spacer()
                
                // 关闭按钮
                Button {
                    closeExpanded()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.iconColor)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.bottom, 8)

            Divider()
                .opacity(0.2)

            // 标签内容（固定高度，不因内容变化）
            tabContent
                .frame(height: 280)
        }
        .padding(12)
        // No fixed width - let DynamicIslandPanel control width
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sessionManager.sortedSessions.first?.sessionId)
        .popover(isPresented: $showSettings, arrowEdge: .top) {
            SettingsView()
                .environment(viewModel)
                .frame(width: 450)
        }
    }

    // MARK: - 关闭展开视图

    private func closeExpanded() {
        NotificationCenter.default.post(name: .toggleIslandState, object: nil)
    }

    // MARK: - 标签栏

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(ExpandedTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.bottom, 8)
    }

    private func tabButton(_ tab: ExpandedTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(tabForegroundStyle(for: tab))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(tabBackground(for: tab))
            .overlay(tabBorder(for: tab))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab.rawValue)
        .contentShape(Rectangle())
    }

    // MARK: - 主题感知的标签样式

    private func tabForegroundStyle(for tab: ExpandedTab) -> some ShapeStyle {
        let isSelected = selectedTab == tab
        return isSelected ? themeManager.primaryText : themeManager.mutedText
    }

    @ViewBuilder
    private func tabBackground(for tab: ExpandedTab) -> some View {
        let isSelected = selectedTab == tab
        RoundedRectangle(cornerRadius: themeManager.cornerRadius)
            .fill(isSelected ? themeManager.selectedBackground : themeManager.normalBackground)
    }

    @ViewBuilder
    private func tabBorder(for tab: ExpandedTab) -> some View {
        let isSelected = selectedTab == tab
        RoundedRectangle(cornerRadius: themeManager.cornerRadius)
            .strokeBorder(
                isSelected ? themeManager.selectedBorder : themeManager.normalBorder,
                lineWidth: isSelected ? 1.5 : 0.5
            )
    }

    // MARK: - 标签内容

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .sessions:
            sessionsTab
        case .context:
            contextTab
        }
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

    private var emptyContextView: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 24))
                .foregroundStyle(themeManager.disabledColor)
            Text("暂无会话数据")
                .font(.system(size: 12))
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
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconColor)

            Spacer()

            // 右下角刷新按钮
            Button {
                Task {
                    switch selectedTab {
                    case .sessions:
                        sessionManager.refresh()
                    case .context:
                        // 上下文数据随会话更新自动同步，刷新会话即可
                        sessionManager.refresh()
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconColor)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var backgroundView: some View {
        let borderColor = Color.gray

        switch viewModel.settings.theme {
        case .glass:
            ZStack {
                // 毛玻璃背景
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .opacity(0.7)

                // 固定灰色渐变边框
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                borderColor.opacity(0.5),
                                borderColor.opacity(0.3),
                                borderColor.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
            }
        case .pixel:
            ZStack {
                Color(white: 0.1)
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                borderColor.opacity(0.5),
                                borderColor.opacity(0.3),
                                borderColor.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
            }
        }
    }
}
