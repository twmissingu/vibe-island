import SwiftUI

// MARK: - 编码时长统计面板

/// 展示今日/本周/总计编码时长的统计面板
struct CodingTimeStatsView: View {
    @State private var tracker = CodingTimeTracker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text("编码时长统计")
                .font(.headline)
                .fontWeight(.bold)

            // 今日时长卡片
            statsCard(
                title: "今日",
                subtitle: "今天累计编码时长",
                seconds: tracker.todayCodingSeconds,
                icon: "sun.max.fill",
                color: .orange
            )

            // 本周时长卡片
            statsCard(
                title: "本周",
                subtitle: "本周一至今累计编码时长",
                seconds: tracker.weekCodingSeconds,
                icon: "calendar.badge.clock",
                color: .blue
            )

            // 总计时长卡片
            statsCard(
                title: "总计",
                subtitle: "历史累计编码时长",
                seconds: tracker.totalCodingSeconds,
                icon: "chart.bar.fill",
                color: .green
            )

            // 解锁进度
            unlockProgressSection
        }
        .padding(16)
    }

    // MARK: - 统计卡片

    @ViewBuilder
    private func statsCard(title: String, subtitle: String, seconds: Int, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            // 文本
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(formatDuration(seconds))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - 解锁进度

    @ViewBuilder
    private var unlockProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("宠物解锁进度")
                .font(.subheadline)
                .fontWeight(.semibold)

            // 当前宠物
            if let pet = PetType(rawValue: "cat") {
                HStack {
                    Text("当前宠物")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(pet.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }

            // 解锁进度条
            let progress = min(1.0, Double(tracker.totalCodingMinutes) / 30.0)
            VStack(spacing: 4) {
                HStack {
                    Text("下一个宠物")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tracker.totalCodingMinutes >= 30 ? "🐶 小狗" : "🐶 小狗 (\(30 - tracker.totalCodingMinutes) 分钟)")
                        .font(.caption)
                        .foregroundStyle(tracker.totalCodingMinutes >= 30 ? .green : .secondary)
                }

                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .controlSize(.small)
            }
        }
    }

    // MARK: - 格式化时长

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return String(format: "%d 小时 %d 分钟", hours, remainingMinutes)
        } else if minutes > 0 {
            return String(format: "%d 分钟", minutes)
        } else {
            return "0 分钟"
        }
    }
}

// MARK: - 预览
#Preview {
    CodingTimeStatsView()
        .previewLayout(.fixed(width: 400, height: 400))
}
