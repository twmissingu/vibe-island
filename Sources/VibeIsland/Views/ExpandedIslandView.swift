import SwiftUI
import LLMQuotaKit

// MARK: - 展开的灵动岛视图

struct ExpandedIslandView: View {
    @Environment(StateManager.self) private var viewModel
    @State private var selectedTab: ExpandedTab = .quota
    private var contextMonitor: ContextMonitor { .shared }

    /// 展开视图的标签页
    enum ExpandedTab: String, CaseIterable {
        case quota = "额度"
        case sessions = "会话"
        case context = "上下文"

        var icon: String {
            switch self {
            case .quota: return "key.fill"
            case .sessions: return "terminal"
            case .context: return "brain.head.filled"
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

            // 标签内容
            tabContent
        }
        .padding(12)
        .frame(width: 360)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: contextSnapshot)
    }

    // MARK: - 标签栏

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ExpandedTab.allCases, id: \.self) { tab in
                tabButton(tab)
                if tab != ExpandedTab.allCases.last {
                    Spacer()
                }
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
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                Text(tab.rawValue)
                    .font(.system(size: 10))
            }
            .foregroundStyle(selectedTab == tab ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.blue.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
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

            footer
        }
    }

    // MARK: - 会话标签

    @ViewBuilder
    private var sessionsTab: some View {
        SessionListView()
            .environment(viewModel)
    }

    // MARK: - 上下文标签

    @ViewBuilder
    private var contextTab: some View {
        if let snapshot = contextSnapshot, snapshot.usageRatio > 0 {
            VStack(spacing: 8) {
                ContextUsageCard(snapshot: snapshot)
                Spacer()
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("暂无上下文数据")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 100)
        }
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
        .frame(height: 100)
    }

    private var footer: some View {
        HStack {
            if let last = viewModel.lastRefresh {
                Text("更新于 \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch viewModel.settings.theme {
        case .glass:
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        case .pixel:
            Color(white: 0.1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(white: 0.3), lineWidth: 2)
                )
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
