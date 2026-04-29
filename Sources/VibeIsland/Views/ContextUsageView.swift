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
                .font(.system(size: 10))
                .foregroundStyle(warningColor)
                .opacity(isWarning ? flashOpacity : 1.0)

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))

                    Capsule()
                        .fill(warningColor.gradient)
                        .frame(width: geo.size.width * min(snapshot.usageRatio, 1.0))
                }
            }
            .frame(width: 60, height: 6)

            // 百分比文本
            Text("\(snapshot.usagePercent)%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
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

    var body: some View {
        VStack(spacing: theme == .pixel ? 6 : 8) {
            // 标题行：会话名 + 持续时间
            HStack {
                Text(session.sessionName ?? session.cwd.shortenedCwd())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text(sessionDuration)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(durationColor)
            }

            // 进度条：包含百分比
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(progressBackgroundColor)

                    Capsule()
                        .fill(statusColor.gradient)
                        .frame(width: geo.size.width * min(snapshot.usageRatio, 1.0))
                }
                .overlay(alignment: .trailing) {
                    Text("\(snapshot.usagePercent)%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(statusColor)
                }
            }
            .frame(height: theme == .pixel ? 6 : 8)

            // Token 统计表格（两行三列对齐）
            Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: theme == .pixel ? 6 : 8) {
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
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(sectionLabelColor)

                    ForEach(tools, id: \.name) { tool in
                        HStack(spacing: 6) {
                            Image(systemName: toolIcon(for: tool.name))
                                .font(.system(size: 10))
                                .foregroundStyle(itemNameColor)
                                .frame(width: 14)

                            Text(tool.name.uppercased())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(itemNameColor)

                            Spacer()

                            Text("\(tool.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(itemValueColor)

                            Text("(\(toolPercent(tool))%)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.gray.opacity(0.6))
                        }
                    }

                    // 工具使用进度条
                    if let maxCount = tools.map({ $0.count }).max(), maxCount > 0 {
                        let sortedTools = tools.sorted { $0.count > $1.count }
                        GeometryReader { geo in
                            ForEach(Array(sortedTools.enumerated()), id: \.element.name) { index, tool in
                                let width = geo.size.width * CGFloat(tool.count) / CGFloat(maxCount)
                                Rectangle()
                                    .fill(toolColor(for: tool.name).opacity(0.6))
                                    .frame(width: max(2, width), height: 4)
                                    .cornerRadius(2)
                                    .offset(y: CGFloat(index) * 6)
                            }
                        }
                        .frame(height: CGFloat(min(tools.count, 5)) * 6)
                    }
                }
            }

            // 技能使用行
            if let skills = snapshot.skillUsage, !skills.isEmpty {
                Divider()
                    .opacity(theme == .pixel ? 0.15 : 0.2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SKILL USAGE")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(sectionLabelColor)

                    ForEach(skills, id: \.name) { skill in
                        HStack {
                            Text(skill.name.uppercased())
                                .font(.system(size: 10))
                                .foregroundStyle(itemNameColor)

                            Spacer()

                            Text("\(skill.count) (\(skillPercent(skill))%)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(itemValueColor)
                        }
                    }
                }
            }
        }
        .padding(theme == .pixel ? 8 : 10)
        .background(cardBackground)
        .animation(.easeInOut(duration: 0.3), value: snapshot.usageRatio)
    }

    // MARK: - 主题感知的颜色

    private var titleColor: Color {
        theme == .pixel ? .white : .primary
    }

    private var durationColor: Color {
        theme == .pixel ? .gray.opacity(0.6) : .gray.opacity(0.7)
    }

    private var progressBackgroundColor: Color {
        theme == .pixel ? Color(white: 0.2) : Color.gray.opacity(0.2)
    }

    private var sectionLabelColor: Color {
        theme == .pixel ? .gray.opacity(0.5) : .gray.opacity(0.6)
    }

    private var itemNameColor: Color {
        theme == .pixel ? .white : .primary
    }

    private var itemValueColor: Color {
        theme == .pixel ? .gray.opacity(0.5) : .gray.opacity(0.6)
    }

    private var cardBackground: some View {
        switch theme {
        case .pixel:
            return RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(statusColor.opacity(snapshot.isWarning ? 0.4 : 0.15), lineWidth: 1)
                )
        case .glass:
            return RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(statusColor.opacity(snapshot.isWarning ? 0.3 : 0), lineWidth: 1)
                )
        }
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

    private var sessionDuration: String {
        guard let startTime = session.pidStartTime else { return "--:--" }
        let elapsed = Date().timeIntervalSince1970 - startTime
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60

        return String(format: "%02d:%02d", hours, minutes)
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
        case "read", "glob", "grep": return "doc.text"
        case "edit", "write": return "pencil"
        case "bash", "shell", "cmd": return "terminal"
        case "webfetch", "fetch": return "globe"
        case "task": return "sparkles"
        case "tool": return "wrench.and.screwdriver"
        case "mcp": return "puzzlepiece.extension"
        default: return "questionmark.circle"
        }
    }

    private func toolColor(for name: String) -> Color {
        switch name.lowercased() {
        case "read", "glob", "grep": return .blue
        case "edit", "write": return .orange
        case "bash", "shell", "cmd": return .green
        case "webfetch", "fetch": return .purple
        case "task": return .yellow
        case "tool": return .cyan
        default: return .gray
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
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(tokenLabelColor(value: value, showIfZero: showIfZero))
            if let val = value, (val > 0 || showIfZero) {
                Text(formatTokenCount(val))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(tokenValueColor)
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme == .pixel ? .gray.opacity(0.4) : .gray.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tokenLabelColor(value: Int?, showIfZero: Bool) -> Color {
        let isDimmed = value == nil || (value! == 0 && !showIfZero)
        if theme == .pixel {
            return isDimmed ? .gray.opacity(0.4) : .gray.opacity(0.5)
        } else {
            return isDimmed ? .gray.opacity(0.5) : .gray.opacity(0.6)
        }
    }

    private var tokenValueColor: Color {
        theme == .pixel ? .white.opacity(0.9) : .white
    }


}

// MARK: - 会话信息卡片（无上下文数据时展示）

/// 当 trackedSession 存在但无 context_usage 数据时展示的基本会话信息
struct SessionInfoCard: View {
    let session: Session
    let theme: AppTheme

    var body: some View {
        VStack(spacing: theme == .pixel ? 8 : 10) {
            // 标题行：会话名 + 状态
            HStack {
                Text(session.sessionName ?? session.cwd.shortenedCwd())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: session.status.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(session.status.color)
                    Text(session.status.statusName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(session.status.color)
                }
            }

            // 来源 + 工作目录
            HStack {
                Label(
                    session.toolDisplayName,
                    systemImage: session.toolSourceIcon
                )
                .font(.system(size: 10))
                .foregroundStyle(metaColor)

                Spacer()

                Text(session.cwd.shortenedCwd())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(cwdColor)
                    .lineLimit(1)
            }

            Divider().opacity(theme == .pixel ? 0.15 : 0.2)

            // 等待数据提示
            HStack(spacing: 6) {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(hintColor)
                Text("上下文数据将在会话运行后自动更新")
                    .font(.system(size: 10))
                    .foregroundStyle(hintColor)
            }
        }
        .padding(theme == .pixel ? 8 : 10)
        .background(cardBackground)
    }

    // MARK: - 主题感知的颜色

    private var titleColor: Color {
        theme == .pixel ? .white : .primary
    }

    private var metaColor: Color {
        theme == .pixel ? .gray.opacity(0.6) : .gray.opacity(0.7)
    }

    private var cwdColor: Color {
        theme == .pixel ? .gray.opacity(0.5) : .gray.opacity(0.6)
    }

    private var hintColor: Color {
        theme == .pixel ? .gray.opacity(0.5) : .gray.opacity(0.6)
    }

    private var cardBackground: some View {
        switch theme {
        case .pixel:
            return RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                )
        case .glass:
            return RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.gray.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

