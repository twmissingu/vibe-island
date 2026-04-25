import SwiftUI
import LLMQuotaKit

// MARK: - 展开的灵动岛视图

struct ExpandedIslandView: View {
    @Environment(StateManager.self) private var viewModel
    @State private var selectedTab: ExpandedTab = .sessions
    @State private var showSettings = false
    private var contextMonitor: ContextMonitor { .shared }
    private var sessionManager: SessionManager { .shared }

    /// 聚合状态用于渐变边框
    private var aggregateState: SessionState {
        sessionManager.aggregateState
    }

    /// 展开视图的标签页
    enum ExpandedTab: String, CaseIterable {
        case quota = "额度"
        case sessions = "会话"
        case context = "上下文"

        var icon: String {
            switch self {
            case .quota: return "key.fill"
            case .sessions: return "terminal"
            case .context: return "brain.fill"
            }
        }
    }

    private var contextSnapshot: ContextUsageSnapshot? {
        contextMonitor.topSnapshot
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: contextSnapshot)
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
        case .quota:
            quotaTab
        case .sessions:
            sessionsTab
        case .context:
            contextTab
        }
    }

    // MARK: - 额度标签

    @ViewBuilder
    private var quotaTab: some View {
        VStack(spacing: 8) {
            // 内容区域（可滚动，当额度多时）
            ScrollView {
                VStack(spacing: 8) {
                    // Context usage card (if available)
                    if let snapshot = contextSnapshot, snapshot.usageRatio > 0 {
                        ContextUsageCard(snapshot: snapshot)
                    }

                    ForEach(viewModel.quotas) { quota in
                        QuotaCardView(quota: quota, theme: viewModel.settings.theme)
                    }

                    if viewModel.quotas.isEmpty {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            // 固定在底部
            footer
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
            // 上下文内容（可滚动，按lastActivity排序）
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(sessionManager.sortedSessions), id: \.sessionId) { session in
                        if let snapshot = contextMonitor.snapshot(for: session.sessionId),
                           snapshot.usageRatio > 0 {
                            sessionContextRow(session: session, snapshot: snapshot)
                        }
                    }
                    
                    // 无上下文数据
                    let sessionsWithContext = sessionManager.sortedSessions.compactMap { session in
                        contextMonitor.snapshot(for: session.sessionId)
                    }
                    if sessionsWithContext.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "brain")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                            Text("暂无上下文数据")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            // 固定在底部
            footer
        }
    }
    
    // MARK: - 会话上下文行
    
    private func sessionContextRow(session: Session, snapshot: ContextUsageSnapshot) -> some View {
        let contextText: String
        if let used = snapshot.tokensUsed, let total = snapshot.tokensTotal {
            contextText = "\(snapshot.usagePercent)% (\(formatTokens(used))/\(formatTokens(total)))"
        } else {
            contextText = "\(snapshot.usagePercent)%"
        }
        
        return HStack {
            Text(session.sessionName ?? shortenedCwd(session.cwd))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(contextText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(sessionManager.aggregateState.color)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func shortenedCwd(_ cwd: String) -> String {
        let components = cwd.split(separator: "/")
        guard components.count > 3 else { return cwd }
        return ".../" + components.suffix(2).joined(separator: "/")
    }
    
    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1000 {
            return String(format: "%.0fK", Double(tokens) / 1000.0)
        }
return "\(tokens)"
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("请在设置中添加 API Key")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                    case .quota:
                        await viewModel.refresh()
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

// MARK: - QuotaCardView

struct QuotaCardView: View {
    let quota: QuotaInfo
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 8) {
            header
            CircularGaugeView(
                remainingPercent: quota.remainingPercent,
                theme: theme
            )
            .frame(width: 80, height: 80)
            detailRows
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(theme == .glass ? 0.05 : 0.03))
        )
    }

    private var header: some View {
        HStack {
            Text(quota.provider.displayName)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let error = quota.error {
                Text(error.displayMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            } else {
                Text("✅")
                    .font(.system(size: 11))
            }
        }
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            detailRow("剩余", value: "\(quota.formattedRemaining) / \(quota.formattedTotal)")
            detailRow("已用", value: "\(quota.formattedUsed) (\(quota.usedPercent)%)")
            if let reset = quota.nextResetAt {
                detailRow("重置", value: reset.formatted(date: .abbreviated, time: .shortened))
            }
            detailRow("Key", value: quota.keyIdentifier)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
