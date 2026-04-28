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
            // 标签页切换
            tabBar

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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(viewModel)
        }
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
            .foregroundStyle(selectedTab == tab ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.blue : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedTab == tab ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab.rawValue)
        .contentShape(Rectangle())
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
                VStack(spacing: 8) {
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
                            ContextUsageCard(session: session, snapshot: snapshot)
                        } else {
                            SessionInfoCard(session: session)
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
                .foregroundStyle(.secondary)
            Text("暂无会话数据")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
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
            .foregroundStyle(.secondary)

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
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var backgroundView: some View {
        let stateColor = aggregateState.color
        // 固定灰色边框，不随状态变化
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
