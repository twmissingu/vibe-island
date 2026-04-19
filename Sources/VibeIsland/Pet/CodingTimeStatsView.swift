import SwiftUI

// MARK: - 编码时长统计面板

/// 展示今日/本周/总计编码时长的统计面板
struct CodingTimeStatsView: View {
    @State private var tracker = CodingTimeTracker.shared
    @State private var manager = PetProgressManager.shared

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

            // 每日目标进度
            goalProgressSection(
                title: "每日目标",
                subtitle: "今天的目标完成度",
                currentMinutes: manager.todayCodingMinutes,
                targetMinutes: manager.dailyGoal,
                lastAchievedDate: manager.lastDailyGoalDate,
                color: .purple
            )

            // 每周目标进度
            goalProgressSection(
                title: "每周目标",
                subtitle: "本周的目标完成度",
                currentMinutes: manager.weekCodingMinutes,
                targetMinutes: manager.weeklyGoal,
                lastAchievedDate: manager.lastWeeklyGoalDate,
                color: .teal
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

    // MARK: - 目标进度卡片

    @ViewBuilder
    private func goalProgressSection(title: String, subtitle: String, currentMinutes: Int, targetMinutes: Int, lastAchievedDate: Date?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和达成状态
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if currentMinutes >= targetMinutes {
                    Text("🎯 已达成")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("\(targetMinutes - currentMinutes) 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 目标进度条
            let progress = min(1.0, Double(currentMinutes) / Double(targetMinutes))
            VStack(spacing: 6) {
                HStack {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .controlSize(.small)

                // 达成日期提示
                if let date = lastAchievedDate, currentMinutes >= targetMinutes {
                    Text("上一次达成：\(formatDate(date))")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - 解锁进度 & 等级

    @ViewBuilder
    private var unlockProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("宠物等级")
                .font(.subheadline)
                .fontWeight(.semibold)

            // 当前宠物 & 等级
            HStack {
                Text("当前宠物")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(manager.selectedPet.displayName) · \(manager.currentLevel.displayName)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            // 等级进度
            if let remaining = manager.minutesToNextLevel(for: manager.selectedPet) {
                let progress = manager.levelProgress(for: manager.selectedPet)
                VStack(spacing: 4) {
                    HStack {
                        Text("下一等级")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(remaining) 分钟")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .controlSize(.small)
                }
            } else {
                Text("已达到最高等级")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            // 所有宠物等级一览
            petLevelGrid
        }
    }

    /// 所有宠物等级网格
    @ViewBuilder
    private var petLevelGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PetType.allCases, id: \.self) { pet in
                let level = manager.level(for: pet)
                let isUnlocked = pet.isUnlocked(totalCodingMinutes: manager.totalCodingMinutes)
                VStack(spacing: 2) {
                    Text(petIcon(pet))
                        .font(.caption)
                    Text("Lv.\(level.rawValue)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isUnlocked ? levelColor(level) : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(pet == manager.selectedPet ? Color.orange.opacity(0.15) : Color.clear)
                )
            }
        }
    }

    private func petIcon(_ pet: PetType) -> String {
        switch pet {
        case .cat: return "🐱"
        case .dog: return "🐶"
        case .rabbit: return "🐰"
        case .fox: return "🦊"
        case .penguin: return "🐧"
        case .robot: return "🤖"
        case .ghost: return "👻"
        case .dragon: return "🐲"
        }
    }

    private func levelColor(_ level: PetLevel) -> Color {
        switch level {
        case .basic: return .secondary
        case .glow: return .cyan
        case .metal: return .gray
        case .neon: return .purple
        case .king: return .yellow
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - 预览
#Preview {
    CodingTimeStatsView()
        .previewLayout(.fixed(width: 400, height: 400))
}
