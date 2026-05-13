import SwiftUI

// MARK: - 上下文使用显示视图

/// 显示当前会话的上下文使用情况
/// - 进度条显示使用率
/// - 超过 80% 时橙色闪烁警告
/// - 显示剩余 token 估算
struct ContextUsageView: View {
    let snapshot: ContextUsageSnapshot

    @State private var flashOpacity: Double = 1.0
    @State private var isFlashing = false

    private var isWarning: Bool {
        snapshot.isWarning
    }

    private var isCritical: Bool {
        snapshot.isCritical
    }

    private var warningColor: Color {
        isCritical ? .red : .orange
    }

    var body: some View {
        HStack(spacing: 6) {
            // 上下文图标
            Image(systemName: contextIcon)
                .font(.islandBody)
                .foregroundStyle(warningColor)
                .opacity(isWarning ? flashOpacity : 1.0)

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))

                    Capsule()
                        .fill(warningColor.gradient)
                        .frame(width: geo.size.width * min(snapshot.usageRatio, 1.0))
                }
            }
            .frame(width: 60, height: 6)

            // 百分比文本
            Text("\(snapshot.usagePercent)%")
                .font(.islandCompact.monospaced())
                .foregroundStyle(isWarning ? warningColor : .secondary)

            // 剩余 token
            if let remaining = snapshot.tokensRemaining {
                Text(formatTokenCount(remaining))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .onChange(of: isWarning) { _, flashing in
            if flashing {
                startFlashing()
            } else {
                stopFlashing()
            }
        }
        .onAppear {
            if isWarning {
                startFlashing()
            }
        }
    }

    // MARK: 私有属性

    private var contextIcon: String {
        if isCritical {
            return "exclamationmark.triangle.fill"
        } else if isWarning {
            return "brain.fill"
        }
        return "brain"
    }

    private func startFlashing() {
        guard !isFlashing else { return }
        isFlashing = true
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            flashOpacity = 0.3
        }
    }

    private func stopFlashing() {
        isFlashing = false
        flashOpacity = 1.0
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - 上下文使用详情卡片

/// 在 ExpandedIslandView 中使用的完整上下文详情卡片
struct ContextUsageCard: View {
    let session: Session
    let snapshot: ContextUsageSnapshot
    let theme: AppTheme

    private var themeManager: ThemeManager {
        theme.manager
    }

    var body: some View {
        VStack(spacing: themeManager.spacing) {
            // 标题行：会话名 + 持续时间
            HStack {
                Text(session.sessionName ?? session.cwd.shortenedCwd())
                    .font(.islandBody.weight(.semibold))
                    .foregroundStyle(themeManager.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text(session.formattedDuration)
                    .font(.islandCaptionMono)
                    .foregroundStyle(themeManager.mutedText)
            }

            // 进度条：包含百分比
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeManager.progressBackground)

                    Capsule()
                        .fill(statusColor.gradient)
                        .frame(width: geo.size.width * min(snapshot.usageRatio, 1.0))
                }
                .overlay(alignment: .trailing) {
                    Text("\(snapshot.usagePercent)%")
                        .font(.islandCompact.monospaced())
                        .foregroundStyle(statusColor)
                }
            }
            .frame(height: themeManager.progressBarHeight)

            // Token 统计表格（两行三列对齐）
            Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: themeManager.spacing) {
                // 第一行：USED / TOTAL / REMAIN
                if let used = snapshot.tokensUsed, let total = snapshot.tokensTotal {
                    GridRow {
                        tokenCell("USED", value: used)
                        tokenCell("TOTAL", value: total)
                        if let remaining = snapshot.tokensRemaining {
                            tokenCell("REMAIN", value: remaining)
                        } else {
                            tokenCell("REMAIN", value: nil)
                        }
                    }
                }

                // 第二行：INPUT / OUTPUT / REASONING
                if hasCategoryTokens || snapshot.inputTokens != nil || snapshot.outputTokens != nil || snapshot.reasoningTokens != nil {
                    GridRow {
                        tokenCell("INPUT", value: snapshot.inputTokens ?? 0, showIfZero: false)
                        tokenCell("OUTPUT", value: snapshot.outputTokens ?? 0, showIfZero: false)
                        tokenCell("REASONING", value: snapshot.reasoningTokens ?? 0, showIfZero: false)
                    }
                }
            }

            // 工具使用行
            if let tools = snapshot.toolUsage, !tools.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOOL USAGE")
                        .font(.system(size: 9, weight: .medium))  // 9pt — 无对应 token
                        .foregroundStyle(themeManager.tertiaryText)

                    ForEach(tools, id: \.name) { tool in
                        HStack(spacing: 6) {
                            Image(systemName: toolIcon(for: tool.name))
                                .font(.islandBody)
                                .foregroundStyle(themeManager.secondaryText)
                                .frame(width: 14)

                            Text(tool.name.uppercased())
                                .font(.islandCompact)
                                .foregroundStyle(themeManager.secondaryText)

                            Spacer()

                            Text("\(tool.count)")
                                .font(.islandBody.monospaced())
                                .foregroundStyle(themeManager.secondaryText)

                            Text("(\(toolPercent(tool))%)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(themeManager.mutedText)
                        }
                    }

                }
            }

            // 技能使用行
            if let skills = snapshot.skillUsage, !skills.isEmpty {
                Divider()
                    .opacity(0.2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SKILL USAGE")
                        .font(.system(size: 9, weight: .medium))  // 9pt — 无对应 token
                        .foregroundStyle(themeManager.tertiaryText)

                    ForEach(skills, id: \.name) { skill in
                        HStack {
                            Text(skill.name.uppercased())
                                .font(.islandBody)
                                .foregroundStyle(themeManager.secondaryText)

                            Spacer()

                            Text("\(skill.count)")
                                .font(.islandBody.monospaced())
                                .foregroundStyle(themeManager.secondaryText)

                            Text("(\(skillPercent(skill))%)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(themeManager.mutedText)
                        }
                    }
                }
            }
        }
        .padding(themeManager.padding)
        .background(cardBackground)
        .animation(.easeInOut(duration: 0.3), value: snapshot.usageRatio)
    }

    // MARK: - 主题感知的颜色

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: themeManager.cornerRadius)
            .fill(themeManager.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.cornerRadius)
                    .strokeBorder(statusColor.opacity(snapshot.isWarning ? 0.4 : 0.2), lineWidth: 1)
            )
    }

    private var statusColor: Color {
        let percent = snapshot.usagePercent
        if percent < 40 {
            return .green
        } else if percent < 70 {
            return .orange
        } else {
            return .red
        }
    }

    private var hasCategoryTokens: Bool {
        let input = snapshot.inputTokens ?? 0
        let output = snapshot.outputTokens ?? 0
        let reasoning = snapshot.reasoningTokens ?? 0
        return input > 0 || output > 0 || reasoning > 0
    }

    private var totalToolCount: Int {
        snapshot.toolUsage?.reduce(0) { $0 + $1.count } ?? 0
    }

    private func toolPercent(_ tool: ToolUsage) -> Int {
        let total = totalToolCount
        guard total > 0 else { return 0 }
        return Int(Double(tool.count) / Double(total) * 100)
    }

    private func toolIcon(for name: String) -> String {
        switch name.lowercased() {
        // 文件操作
        case "read": return "doc.text"
        case "write": return "pencil"
        case "edit": return "pencil"
        case "glob": return "doc.text.magnifyingglass"
        case "grep": return "text.magnifyingglass"
        case "notebookedit": return "book"
        // 终端
        case "bash", "shell", "cmd": return "terminal"
        // 网络
        case "webfetch", "fetch": return "globe"
        case "websearch": return "magnifyingglass"
        // Agent 子代理
        case "agent": return "person.2"
        // 任务管理
        case "taskcreate", "taskupdate", "tasklist", "taskget", "todowrite", "taskoutput": return "checklist"
        case "taskstop": return "stop.circle"
        // 计划模式
        case "enterplanmode", "plan": return "list.bullet"
        case "exitplanmode": return "checkmark.circle"
        // 定时任务
        case "croncreate", "cronlist": return "clock"
        case "crondelete": return "clock.badge.xmark"
        // 技能
        case "skill": return "wand.and.stars"
        // MCP
        case "mcp": return "puzzlepiece.extension"
        // 交互
        case "askuserquestion": return "questionmark.circle"
        default: return "questionmark.circle"
        }
    }

    private var totalSkillCount: Int {
        snapshot.skillUsage?.reduce(0) { $0 + $1.count } ?? 0
    }

    private func skillPercent(_ skill: ToolUsage) -> Int {
        let total = totalSkillCount
        guard total > 0 else { return 0 }
        return Int(Double(skill.count) / Double(total) * 100)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func tokenCell(_ label: String, value: Int?, showIfZero: Bool = true) -> some View {
        VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))  // 9pt — 无对应 token
                    .foregroundStyle(tokenLabelColor(value: value, showIfZero: showIfZero))
            if let val = value, (val > 0 || showIfZero) {
                Text(formatTokenCount(val))
                    .font(.islandCaption.weight(.medium).monospaced())
                    .foregroundStyle(tokenValueColor)
            } else {
                Text("--")
                    .font(.islandCaption.weight(.medium).monospaced())
                    .foregroundStyle(theme == .pixel ? .gray.opacity(0.5) : .gray.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tokenLabelColor(value: Int?, showIfZero: Bool) -> Color {
        let isDimmed = value == nil || (value! == 0 && !showIfZero)
        if theme == .pixel {
            return isDimmed ? .gray.opacity(0.5) : .gray.opacity(0.7)
        } else {
            return isDimmed ? .gray.opacity(0.5) : .gray.opacity(0.6)
        }
    }

    private var tokenValueColor: Color {
        theme == .pixel ? .white : .primary
    }


}

// MARK: - 会话信息卡片（无上下文数据时展示）

/// 当 trackedSession 存在但无 context_usage 数据时展示的基本会话信息
struct SessionInfoCard: View {
    let session: Session
    let theme: AppTheme

    private var themeManager: ThemeManager {
        theme.manager
    }

    var body: some View {
        VStack(spacing: themeManager.spacing + 2) {
            // 标题行：会话名 + 状态
            HStack {
                Text(session.sessionName ?? session.cwd.shortenedCwd())
                    .font(.islandBody.weight(.semibold))
                    .foregroundStyle(themeManager.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: session.status.icon)
                        .font(.system(size: 9))  // 9pt — 无对应 token
                        .foregroundStyle(session.status.color)
                    Text(session.status.statusName)
                        .font(.islandBody.monospaced())
                        .foregroundStyle(session.status.color)
                }
            }

            // 来源 + 工作目录
            HStack {
                Label(
                    session.toolDisplayName,
                    systemImage: session.toolSourceIcon
                )
                .font(.islandBody)
                .foregroundStyle(themeManager.secondaryText)

                Spacer()

                Text(session.cwd.shortenedCwd())
                    .font(.islandBody.monospaced())
                    .foregroundStyle(themeManager.mutedText)
                    .lineLimit(1)
            }

            Divider().opacity(0.2)

            // 等待数据提示
            HStack(spacing: 6) {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.islandBody)
                    .foregroundStyle(themeManager.tertiaryText)
                Text("上下文数据将在会话运行后自动更新")
                    .font(.islandBody)
                    .foregroundStyle(themeManager.tertiaryText)
            }
        }
        .padding(themeManager.padding)
        .background(cardBackground)
    }

    // MARK: - 主题感知的颜色

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: themeManager.cornerRadius)
            .fill(themeManager.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.cornerRadius)
                    .strokeBorder(themeManager.normalBorder, lineWidth: 1)
            )
    }
}

// MARK: - OpenCode 上下文卡片（无数据时的等待态）

/// 与 ContextUsageCard 结构一致的 OpenCode 卡片
/// 当 OpenCode 会话尚无上下文数据时展示等待提示
struct OpenCodeNoContextCard: View {
    let session: Session
    let theme: AppTheme

    private var themeManager: ThemeManager {
        theme.manager
    }

    var body: some View {
        VStack(spacing: themeManager.spacing) {
            // 标题行：会话名 + 来源标签 + 持续时间
            HStack {
                Text(session.sessionName ?? session.cwd.shortenedCwd())
                    .font(.islandBody.weight(.semibold))
                    .foregroundStyle(themeManager.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("OpenCode")
                    .font(.system(size: 8, weight: .medium))  // 8pt — 无对应 token
                    .foregroundStyle(.orange.opacity(0.9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.orange.opacity(0.2)))

                Spacer()

                Text(session.formattedDuration)
                    .font(.islandCaptionMono)
                    .foregroundStyle(themeManager.mutedText)
            }

            // 进度条占位
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeManager.progressBackground)

                    Capsule()
                        .fill(Color.orange.opacity(0.3).gradient)
                        .frame(width: 0)
                }
            }
            .frame(height: themeManager.progressBarHeight)

            // Token 统计占位（与 ContextUsageCard 同布局）
            Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: themeManager.spacing) {
                GridRow {
                    tokenCell("USED", value: nil)
                    tokenCell("TOTAL", value: nil)
                    tokenCell("REMAIN", value: nil)
                }
            }

            // 等待数据提示
            HStack(spacing: 6) {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.islandBody)
                    .foregroundStyle(themeManager.tertiaryText)
                Text("上下文数据将在会话运行后自动更新")
                    .font(.islandBody)
                    .foregroundStyle(themeManager.tertiaryText)
            }
        }
        .padding(themeManager.padding)
        .background(cardBackground)
    }

    // MARK: - 主题感知的颜色

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: themeManager.cornerRadius)
            .fill(themeManager.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.cornerRadius)
                    .strokeBorder(.orange.opacity(0.25), lineWidth: 1)
            )
    }

    private func tokenCell(_ label: String, value: Int?) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))  // 9pt — 无对应 token
                .foregroundStyle(themeManager.mutedText)
            Text("--")
                .font(.islandCaption.weight(.medium).monospaced())
                .foregroundStyle(themeManager.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}

