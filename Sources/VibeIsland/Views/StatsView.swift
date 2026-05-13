import SwiftUI

// MARK: - 今日编码统计面板

/// 显示今日编码活动的统计面板
/// - 编码时长 / 会话数 / Token 使用量（摘要卡片）
/// - 工具使用排名 Top 5（柱状图卡片）
/// - 每日目标进度（进度条卡片）
struct StatsView: View {
    @Environment(StateManager.self) private var viewModel

    private var sessionManager: SessionManager { .shared }
    private var codingTimeTracker: CodingTimeTracker { .shared }
    private var petProgressManager: PetProgressManager { .shared }

    private var themeManager: ThemeManager {
        viewModel.settings.theme.manager
    }

    var body: some View {
        ScrollView {
            VStack(spacing: themeManager.spacing) {
                summaryCard
                topToolsCard
                dailyGoalCard
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - 聚合计算

    /// 工具使用排名（按使用次数降序，取 Top 5）
    private var toolRankings: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for session in sessionManager.allSessions {
            for tool in session.toolUsage ?? [] {
                counts[tool.name, default: 0] += tool.count
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    /// 总工具使用次数
    private var totalToolCount: Int {
        toolRankings.reduce(0) { $0 + $1.count }
    }

    /// 所有会话的 contextTokensUsed 总和
    private var totalTokens: Int {
        sessionManager.allSessions.reduce(0) { $0 + ($1.contextTokensUsed ?? 0) }
    }

    /// 今日编码时长 → "Xh Ym" 或 "Ym"
    private var formattedCodingTime: String {
        let seconds = codingTimeTracker.todayCodingSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Token 总量格式化
    private var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM tok", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.0fK tok", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens) tok"
    }

    /// 每日目标进度 (0.0 ~ 1.0)
    private var dailyGoalProgress: Double {
        let goal = max(petProgressManager.dailyGoal, 1)
        return min(Double(petProgressManager.todayCodingMinutes) / Double(goal), 1.0)
    }

    /// 每日目标百分比 (0 ~ 100)
    private var dailyGoalPercent: Int {
        Int(dailyGoalProgress * 100)
    }

    /// 是否有活跃数据（用于空态判断）
    private var hasData: Bool {
        codingTimeTracker.todayCodingSeconds > 0 || !sessionManager.allSessions.isEmpty
    }

    // MARK: - 摘要卡片

    private var summaryCard: some View {
        VStack(spacing: themeManager.spacing + 2) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.islandCaption)
                    .foregroundStyle(themeManager.secondaryText)
                Text("Today's Coding")
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
        if !toolRankings.isEmpty {
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

                VStack(spacing: 6) {
                    ForEach(Array(toolRankings.enumerated()), id: \.element.name) { _, tool in
                        toolRow(tool: tool)
                    }
                }
            }
            .padding(themeManager.padding)
            .background(cardBackground)
        }
    }

    private func toolRow(tool: (name: String, count: Int)) -> some View {
        let maxCount = toolRankings.first?.count ?? 1
        let ratio = maxCount > 0 ? Double(tool.count) / Double(maxCount) : 0
        let pct = totalToolCount > 0 ? Int(Double(tool.count) / Double(totalToolCount) * 100) : 0

        return HStack(spacing: 8) {
            // 工具名称
            Text(tool.name)
                .font(.islandCompact)
                .foregroundStyle(themeManager.secondaryText)
                .frame(width: 50, alignment: .leading)

            // 条形图（GeometryReader + Capsule，与 CompactProgressBar 一致）
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeManager.progressBackground)
                    Capsule()
                        .fill(toolBarColor(ratio: ratio))
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 8)

            // 次数
            Text("\(tool.count)")
                .font(.islandBody.monospaced())
                .foregroundStyle(themeManager.primaryText)
                .frame(width: 28, alignment: .trailing)

            // 百分比
            Text("(\(pct)%)")
                .font(.islandCompact)
                .foregroundStyle(themeManager.mutedText)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func toolBarColor(ratio: Double) -> Color {
        if ratio >= 0.8 { return .red }
        if ratio >= 0.5 { return .orange }
        return .green
    }

    // MARK: - 每日目标卡片

    private var dailyGoalCard: some View {
        VStack(spacing: themeManager.spacing) {
            // 标题行
            HStack {
                Image(systemName: "target")
                    .font(.islandCaption)
                    .foregroundStyle(themeManager.secondaryText)
                Text("Daily Goal")
                    .font(.islandHeading)
                    .foregroundStyle(themeManager.primaryText)
                Spacer()
                Text("\(petProgressManager.dailyGoal)m")
                    .font(.islandCaptionMono)
                    .foregroundStyle(themeManager.mutedText)
            }

            // 进度条（与 CompactProgressBar 一致的 Capsule 风格）
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeManager.progressBackground)
                    Capsule()
                        .fill(goalProgressColor)
                        .frame(width: geo.size.width * dailyGoalProgress)
                }
            }
            .frame(height: themeManager.progressBarHeight)

            // 状态行
            HStack {
                if dailyGoalPercent >= 100 {
                    Text("🎉 目标已达成！")
                        .font(.islandCompact.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text("\(petProgressManager.todayCodingMinutes) / \(petProgressManager.dailyGoal) 分钟")
                        .font(.islandCompact)
                        .foregroundStyle(themeManager.secondaryText)
                }
                Spacer()
                Text(dailyGoalPercent >= 100 ? "🎯" : "\(dailyGoalPercent)%")
                    .font(.islandCaptionMono)
                    .foregroundStyle(dailyGoalPercent >= 100 ? .green : goalProgressColor)
            }
        }
        .padding(themeManager.padding)
        .background(cardBackground)
    }

    private var goalProgressColor: Color {
        let pct = dailyGoalPercent
        if pct >= 100 { return .green }
        if pct >= 80 { return .orange }
        if pct >= 50 { return .yellow }
        return themeManager.contextColor(percent: pct)
    }

    // MARK: - 空状态

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
