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
                    .foregroundStyle(.tertiary)
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

    var body: some View {
        VStack(spacing: 8) {
            // 标题行：会话名 + 持续时间
            HStack {
                Text(session.sessionName ?? session.cwd.shortenedCwd())
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text(sessionDuration)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // 进度条：包含百分比
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.fill.quaternary)

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
            .frame(height: 8)

            // Token 概览行
            if let used = snapshot.tokensUsed, let total = snapshot.tokensTotal {
                HStack {
                    tokenCell("USED", value: used)
                    Spacer()
                    tokenCell("TOTAL", value: total)
                    Spacer()
                    if let remaining = snapshot.tokensRemaining {
                        tokenCell("REMAIN", value: remaining)
                    }
                }
            }

            // Token 分类行
            if hasCategoryTokens {
                HStack {
                    if let input = snapshot.inputTokens, input > 0 {
                        tokenCell("INPUT", value: input)
                        Spacer()
                    }
                    if let output = snapshot.outputTokens, output > 0 {
                        tokenCell("OUTPUT", value: output)
                        Spacer()
                    }
                    if let reasoning = snapshot.reasoningTokens, reasoning > 0 {
                        tokenCell("REASONING", value: reasoning)
                    }
                }
            }

            // 工具使用行
            if let tools = snapshot.toolUsage, !tools.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOOL USAGE")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach(tools, id: \.name) { tool in
                        HStack {
                            Text(tool.name.uppercased())
                                .font(.system(size: 10))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("\(tool.count) (\(toolPercent(tool)))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(statusColor.opacity(snapshot.isWarning ? 0.3 : 0), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: snapshot.usageRatio)
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

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func tokenCell(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(formatTokenCount(value))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }


}

// MARK: - 会话信息卡片（无上下文数据时展示）

/// 当 trackedSession 存在但无 context_usage 数据时展示的基本会话信息
struct SessionInfoCard: View {
    let session: Session

    var body: some View {
        VStack(spacing: 10) {
            // 标题行：会话名 + 状态
            HStack {
                Text(session.sessionName ?? session.cwd.shortenedCwd())
                    .font(.system(size: 12, weight: .semibold))
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
                .foregroundStyle(.secondary)

                Spacer()

                Text(session.cwd.shortenedCwd())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Divider().opacity(0.2)

            // 等待数据提示
            HStack(spacing: 6) {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("上下文数据将在会话运行后自动更新")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.gray.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

