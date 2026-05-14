import SwiftUI

// MARK: - 编码统计面板

/// 显示累计编码活动统计的面板
/// - 编码时长 / 会话数 / Token 使用量（摘要卡片）
/// - 工具使用排名 Top 5（柱状图卡片）
struct StatsView: View {
    @Environment(StateManager.self) private var viewModel

    private var sessionManager: SessionManager { .shared }
    private var codingTimeTracker: CodingTimeTracker { .shared }

    private var themeManager: ThemeManager {
        viewModel.settings.theme.manager
    }

    var body: some View {
        ScrollView {
            VStack(spacing: themeManager.spacing) {
                summaryCard
                topToolsCard
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - 聚合计算

    /// 工具使用排名（按使用次数降序，取 Top 5）
    /// 数据来源：最近活跃的 8 个会话，与会话列表保持一致
    private var toolRankings: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for session in sessionManager.sortedSessions.prefix(8) {
            for tool in session.toolUsage ?? [] {
                counts[tool.name, default: 0] += tool.count
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    /// 总工具使用次数（这 8 个会话的全部工具）
    private var totalToolCount: Int {
        var total = 0
        for session in sessionManager.sortedSessions.prefix(8) {
            for tool in session.toolUsage ?? [] {
                total += tool.count
            }
        }
        return total
    }

    /// 所有会话的 totalTokensConsumed 总和
    private var totalTokens: Int {
        sessionManager.allSessions.reduce(0) { $0 + ($1.totalTokensConsumed ?? 0) }
    }

    /// 编码时长 → "X.Xh"
    private var formattedCodingTime: String {
        let hours = Double(codingTimeTracker.totalCodingSeconds) / 3600.0
        return String(format: "%.1fh", hours)
    }

    /// Token 总量格式化（百万单位）
    private var formattedTokens: String {
        String(format: "%.1fM", Double(totalTokens) / 1_000_000)
    }

    /// 是否有活跃数据（用于空态判断）
    private var hasData: Bool {
        codingTimeTracker.totalCodingSeconds > 0 || !sessionManager.allSessions.isEmpty
    }

    // MARK: - 摘要卡片

    private var summaryCard: some View {
        VStack(spacing: themeManager.spacing + 2) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.islandCaption)
                    .foregroundStyle(themeManager.secondaryText)
                Text("Coding Data")
                    .font(.islandHeading)
                    .foregroundStyle(themeManager.primaryText)
                Spacer()
            }

            if hasData {
                // 三列统计 — 无 Divider，大号数字
                HStack(spacing: 0) {
                    statItem(value: formattedCodingTime, label: "编码时长")
                    Spacer()
                    statItem(value: "\(sessionManager.activeCount)", label: "活跃会话")
                    Spacer()
                    statItem(value: formattedTokens, label: "Token 用量")
                }
                .padding(.horizontal, 4)
            } else {
                emptyState
            }
        }
        .padding(themeManager.padding)
        .background(cardBackground)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.islandTitle.monospacedDigit())
                .foregroundStyle(themeManager.primaryText)
            Text(label)
                .font(.islandCompact)
                .foregroundStyle(themeManager.mutedText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Tools 卡片

    @ViewBuilder
    private var topToolsCard: some View {
        VStack(spacing: themeManager.spacing) {
            // 标题
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.islandCaption)
                    .foregroundStyle(themeManager.secondaryText)
                Text("Top Tools")
                    .font(.islandHeading)
                    .foregroundStyle(themeManager.primaryText)
                Spacer()
            }

            if !toolRankings.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(toolRankings.enumerated()), id: \.element.name) { _, tool in
                        toolRow(tool: tool)
                    }
                }
            } else {
                toolsEmptyState
            }
        }
        .padding(themeManager.padding)
        .background(cardBackground)
    }

    private func toolRow(tool: (name: String, count: Int)) -> some View {
        let maxCount = toolRankings.first?.count ?? 1
        let ratio = maxCount > 0 ? Double(tool.count) / Double(maxCount) : 0
        let pct = totalToolCount > 0 ? Int(Double(tool.count) / Double(totalToolCount) * 100) : 0

        return HStack(spacing: 8) {
            // 工具名称
            Text(tool.name.uppercased())
                .font(.islandCompact)
                .foregroundStyle(themeManager.secondaryText)
                .lineLimit(1)
                .frame(width: 64, alignment: .leading)

            // 条形图（GeometryReader + Capsule，与 CompactProgressBar 一致）
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeManager.progressBackground)
                    Capsule()
                        .fill(toolBarColor(pct: pct))
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 8)

            // 次数
            Text("\(tool.count)")
                .font(.islandBody.monospaced())
                .foregroundStyle(themeManager.primaryText)
                .frame(minWidth: 36, alignment: .trailing)

            // 百分比
            Text("(\(pct)%)")
                .font(.islandCompact)
                .foregroundStyle(themeManager.mutedText)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }

    private func toolBarColor(pct: Int) -> Color {
        if pct >= 40 { return .red }
        if pct >= 15 { return .orange }
        return .green
    }

    // MARK: - 空状态

    private var toolsEmptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer")
                .font(.islandBody)
                .foregroundStyle(themeManager.mutedText)
            Text("暂无工具数据")
                .font(.islandBody)
                .foregroundStyle(themeManager.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.questionmark")
                .font(.islandBody)
                .foregroundStyle(themeManager.mutedText)
            Text("暂无数据")
                .font(.islandBody)
                .foregroundStyle(themeManager.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - 卡片背景

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: themeManager.cornerRadius)
            .fill(themeManager.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.cornerRadius)
                    .strokeBorder(themeManager.normalBorder, lineWidth: 1)
            )
    }
}
