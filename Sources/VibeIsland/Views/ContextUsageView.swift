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
                Text(formatTokens(remaining))
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

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fm", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - 紧凑版上下文指示器

/// 在 CompactIslandView 中使用的微型上下文指示器
struct ContextUsageIndicator: View {
    let usageRatio: Double

    @State private var flashOpacity: Double = 1.0
    @State private var isFlashing = false

    private var isWarning: Bool {
        usageRatio >= contextWarningThreshold
    }

    private var isCritical: Bool {
        usageRatio >= contextCriticalThreshold
    }

    private var indicatorColor: Color {
        if isCritical { return .red }
        if isWarning { return .orange }
        return .green
    }

    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 6, height: 6)
            .opacity(isWarning ? flashOpacity : 1.0)
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

    private func startFlashing() {
        guard !isFlashing else { return }
        isFlashing = true
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            flashOpacity = 0.2
        }
    }

    private func stopFlashing() {
        isFlashing = false
        flashOpacity = 1.0
    }
}

// MARK: - 上下文使用详情卡片

/// 在 ExpandedIslandView 中使用的完整上下文详情卡片
struct ContextUsageCard: View {
    let session: Session
    let snapshot: ContextUsageSnapshot

    var body: some View {
        VStack(spacing: 8) {
            // 标题行
            HStack {
                Image(systemName: snapshot.isCritical ? "exclamationmark.triangle.fill" : "brain.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)

                Text(session.sessionName ?? shortenedCwd(session.cwd))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text("\(snapshot.usagePercent)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.fill.quaternary)

                    Capsule()
                        .fill(statusColor.gradient)
                        .frame(width: geo.size.width * min(snapshot.usageRatio, 1.0))
                }
            }
            .frame(height: 8)

            // 详情行
            HStack {
                if let used = snapshot.tokensUsed, let total = snapshot.tokensTotal {
                    detailRow("已用", value: formatTokenCount(used))
                    Spacer()
                    detailRow("总量", value: formatTokenCount(total))
                    Spacer()
                    if let remaining = snapshot.tokensRemaining {
                        detailRow("剩余", value: formatTokenCount(remaining))
                    }
                } else {
                    detailRow("使用率", value: "\(snapshot.usagePercent)%")
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

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func shortenedCwd(_ cwd: String) -> String {
        let components = cwd.split(separator: "/")
        guard components.count > 3 else { return cwd }
        return ".../" + components.suffix(2).joined(separator: "/")
    }
}
