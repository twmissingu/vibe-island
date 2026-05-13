import Foundation
import OSLog

// MARK: - 成就类型

enum AchievementCategory: String, Codable, CaseIterable {
    case codingTime    // 编码时长类
    case toolUsage    // 工具使用类
    case petCollection // 宠物收集类
    case streak       // 连续记录类
    case special      // 特殊事件类

    var displayName: String {
        switch self {
        case .codingTime: return "编码时长"
        case .toolUsage: return "工具使用"
        case .petCollection: return "宠物收集"
        case .streak: return "连续记录"
        case .special: return "特殊事件"
        }
    }

    var iconName: String {
        switch self {
        case .codingTime: return "clock"
        case .toolUsage: return "wrench.and.screwdriver"
        case .petCollection: return "pawprint"
        case .streak: return "flame"
        case .special: return "star"
        }
    }
}

// MARK: - 成就定义

struct Achievement: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let category: AchievementCategory
    let targetValue: Int
    let xpReward: Int

    var iconName: String {
        switch category {
        case .codingTime: return "clock.fill"
        case .toolUsage: return "laptopcomputer"
        case .petCollection: return "pawprint.fill"
        case .streak: return "flame.fill"
        case .special: return "star.fill"
        }
    }

    var rarity: AchievementRarity {
        switch targetValue {
        case 0..<60: return .common
        case 60..<300: return .uncommon
        case 300..<1000: return .rare
        case 1000..<5000: return .epic
        default: return .legendary
        }
    }
}

enum AchievementRarity: String, Codable {
    case common     // 普通
    case uncommon  // 优秀
    case rare      // 稀有
    case epic     // 史诗
    case legendary // 传说

    var color: String {
        switch self {
        case .common: return "#A0A0A0"
        case .uncommon: return "#4CAF50"
        case .rare: return "#2196F3"
        case .epic: return "#9C27B0"
        case .legendary: return "#FFD700"
        }
    }
}

// MARK: - 成就进度

struct AchievementProgress: Codable, Sendable {
    let achievementId: String
    let targetValue: Int
    var currentValue: Int
    var isUnlocked: Bool
    var unlockedAt: Date?

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, Double(currentValue) / Double(targetValue))
    }
}

// MARK: - 成就管理器

@MainActor
@Observable
final class AchievementManager {
    static let shared = AchievementManager()

    private(set) var achievements: [Achievement] = []
    private(set) var progress: [String: AchievementProgress] = [:]
    private(set) var totalXP: Int = 0
    private(set) var unlockedCount: Int = 0

    private let defaults = UserDefaults.standard
    private let achievementsKey = "vibe-island.achievements"
    private let progressKey = "vibe-island.achievement-progress"
    private let xpKey = "vibe-island.total-xp"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "AchievementManager"
    )

    private init() {
        loadAchievements()
        loadProgress()
    }

    // MARK: - 成就定义

    private func loadAchievements() {
        achievements = Self.allAchievements
    }

    static let allAchievements: [Achievement] = [
        // MARK: 编码时长成就 (10个)
        Achievement(id: "coding-10m", name: "编码新手", description: "累计编码 10 分钟", category: .codingTime, targetValue: 10, xpReward: 10),
        Achievement(id: "coding-1h", name: "初窥门径", description: "累计编码 1 小时", category: .codingTime, targetValue: 60, xpReward: 25),
        Achievement(id: "coding-10h", name: "渐入佳境", description: "累计编码 10 小时", category: .codingTime, targetValue: 600, xpReward: 100),
        Achievement(id: "coding-50h", name: "Coding达人", description: "累计编码 50 小时", category: .codingTime, targetValue: 3000, xpReward: 250),
        Achievement(id: "coding-100h", name: "百时大师", description: "累计编码 100 小时", category: .codingTime, targetValue: 6000, xpReward: 500),
        Achievement(id: "coding-500h", name: "五百精英", description: "累计编码 500 小时", category: .codingTime, targetValue: 30000, xpReward: 1000),
        Achievement(id: "coding-1000h", name: "千时传奇", description: "累计编码 1000 小时", category: .codingTime, targetValue: 60000, xpReward: 2500),
        Achievement(id: "coding-daily-1", name: "首日编码", description: "单日编码 1 小时", category: .codingTime, targetValue: 60, xpReward: 50),
        Achievement(id: "coding-daily-3", name: "日常编码", description: "单日编码 3 小时", category: .codingTime, targetValue: 180, xpReward: 100),
        Achievement(id: "coding-daily-8", name: "全职编码", description: "单日编码 8 小时", category: .codingTime, targetValue: 480, xpReward: 300),

        // MARK: 工具使用成就 (6个)
        Achievement(id: "tool-claude", name: "Claude忠实用户", description: "使用 Claude Code 10 小时", category: .toolUsage, targetValue: 600, xpReward: 100),
        Achievement(id: "tool-opencode", name: "OpenCode拥趸", description: "使用 OpenCode 10 小时", category: .toolUsage, targetValue: 600, xpReward: 100),
        Achievement(id: "tool-multi", name: "多面手", description: "同时使用 2 种工具", category: .toolUsage, targetValue: 2, xpReward: 150),
        Achievement(id: "tool-all", name: "全能开发者", description: "使用全部 3 种工具", category: .toolUsage, targetValue: 3, xpReward: 300),
        Achievement(id: "tool-concurrent", name: "并行处理", description: "同时开启 3 个会话", category: .toolUsage, targetValue: 3, xpReward: 200),
        Achievement(id: "tool-night", name: "夜猫子", description: "在凌晨 2 点进行编码", category: .toolUsage, targetValue: 1, xpReward: 100),

        // MARK: 宠物收集成就 (5个)
        Achievement(id: "pet-first", name: "初识伙伴", description: "解锁第 1 只宠物", category: .petCollection, targetValue: 1, xpReward: 25),
        Achievement(id: "pet-3", name: "小小动物园", description: "解锁 3 只宠物", category: .petCollection, targetValue: 3, xpReward: 75),
        Achievement(id: "pet-5", name: "动物园园长", description: "解锁 5 只宠物", category: .petCollection, targetValue: 5, xpReward: 150),
        Achievement(id: "pet-all", name: "宠物大师", description: "解锁全部 8 只宠物", category: .petCollection, targetValue: 8, xpReward: 500),
        Achievement(id: "pet-level-max", name: "皮肤王者", description: "将宠物升到满级", category: .petCollection, targetValue: 5, xpReward: 300),

        // MARK: 连续记录成就 (4个)
        Achievement(id: "streak-3", name: "三天坚持", description: "连续 3 天编码", category: .streak, targetValue: 3, xpReward: 50),
        Achievement(id: "streak-7", name: "一周习惯", description: "连续 7 天编码", category: .streak, targetValue: 7, xpReward: 100),
        Achievement(id: "streak-30", name: "月度坚持", description: "连续 30 天编码", category: .streak, targetValue: 30, xpReward: 300),
        Achievement(id: "streak-100", name: "百日成神", description: "连续 100 天编码", category: .streak, targetValue: 100, xpReward: 1000),

        // MARK: 特殊事件成就 (5个)
        Achievement(id: "special-weekend", name: "周末加班", description: "在周末进行编码", category: .special, targetValue: 1, xpReward: 50),
        Achievement(id: "special-holiday", name: "节假日-coding", description: "在节假日进行编码", category: .special, targetValue: 1, xpReward: 75),
        Achievement(id: "special-late", name: "深夜coder", description: "在凌晨进行编码", category: .special, targetValue: 1, xpReward: 50),
        Achievement(id: "special-first-unlock", name: "首次解锁", description: "首次解锁宠物", category: .special, targetValue: 1, xpReward: 50),
        Achievement(id: "special-first-error", name: "错误达人", description: "遇到第 1 次错误", category: .special, targetValue: 1, xpReward: 25),
    ]

    // MARK: - 进度更新

    func updateProgress(for achievementId: String, value: Int) {
        guard let achievement = achievements.first(where: { $0.id == achievementId }) else { return }

        var currentProgress = progress[achievementId] ?? AchievementProgress(
            achievementId: achievementId,
            targetValue: achievement.targetValue,
            currentValue: 0,
            isUnlocked: false
        )

        currentProgress.currentValue = value

        if value >= achievement.targetValue && !currentProgress.isUnlocked {
            currentProgress.isUnlocked = true
            currentProgress.unlockedAt = Date()
            totalXP += achievement.xpReward
            unlockedCount += 1

            Self.logger.info("🎉 成就解锁: \(achievement.name), 奖励 \(achievement.xpReward) XP")

            // 保存进度
            progress[achievementId] = currentProgress
            saveProgress()
            saveTotalXP()

            // 通知 UI
            onAchievementUnlocked?(achievement)
        } else {
            progress[achievementId] = currentProgress
        }
    }

    func incrementProgress(for achievementId: String, by amount: Int = 1) {
        let current = progress[achievementId]?.currentValue ?? 0
        updateProgress(for: achievementId, value: current + amount)
    }

    // MARK: - 查询

    func progress(for achievementId: String) -> AchievementProgress? {
        progress[achievementId]
    }

    func isUnlocked(_ achievementId: String) -> Bool {
        progress[achievementId]?.isUnlocked ?? false
    }

    func achievements(for category: AchievementCategory) -> [Achievement] {
        achievements.filter { $0.category == category }
    }

    func unlockedAchievements(for category: AchievementCategory) -> [Achievement] {
        achievements(for: category).filter { isUnlocked($0.id) }
    }

    // MARK: - 持久化

    private func loadProgress() {
        if let data = defaults.data(forKey: progressKey),
           let decoded = try? JSONDecoder().decode([String: AchievementProgress].self, from: data) {
            progress = decoded
            unlockedCount = decoded.values.filter { $0.isUnlocked }.count
        }

        totalXP = defaults.integer(forKey: xpKey)
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: progressKey)
        }
    }

    private func saveTotalXP() {
        defaults.set(totalXP, forKey: xpKey)
    }

    // MARK: - 回调

    var onAchievementUnlocked: ((Achievement) -> Void)?

    // MARK: - 重置

    func resetProgress() {
        progress.removeAll()
        totalXP = 0
        unlockedCount = 0
        defaults.removeObject(forKey: progressKey)
        defaults.removeObject(forKey: xpKey)
        Self.logger.info("成就进度已重置")
    }
}