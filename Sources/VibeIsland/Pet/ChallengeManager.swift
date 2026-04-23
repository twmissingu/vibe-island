import Foundation
import OSLog

// MARK: - 挑战定义

enum ChallengeType: String, Codable, CaseIterable {
    case codingDuration  // 编码时长目标
    case toolUsage    // 工具使用目标
    case stateChange // 状态切换目标
    case petUnlock  // 宠物解锁目标

    var displayName: String {
        switch self {
        case .codingDuration: return "编码时长"
        case .toolUsage: return "工具使用"
        case .stateChange: return "状态切换"
        case .petUnlock: return "宠物解锁"
        }
    }

    var iconName: String {
        switch self {
        case .codingDuration: return "clock"
        case .toolUsage: return "laptopcomputer"
        case .stateChange: return "arrow.left.arrow.right"
        case .petUnlock: return "pawprint"
        }
    }
}

enum ChallengePeriod: String, Codable {
    case daily   // 每日挑战
    case weekly  // 每周挑战
}

// MARK: - 挑战实例

struct Challenge: Codable, Identifiable, Sendable {
    let id: String
    let type: ChallengeType
    let period: ChallengePeriod
    let title: String
    let description: String
    let targetValue: Int
    let xpMultiplier: Double  // 完成奖励的 XP 加成倍数
    let createdAt: Date

    var isDaily: Bool { period == .daily }
    var isWeekly: Bool { period == .weekly }
}

// MARK: - 挑战进度

struct ChallengeProgress: Codable, Sendable {
    let challengeId: String
    let targetValue: Int
    var currentValue: Int
    var isCompleted: Bool
    var claimedAt: Date?
    var unlockedAt: Date?

    var progress: Double {
        let denom = max(1, targetValue)
        return min(1.0, Double(currentValue) / Double(denom))
    }
}

// MARK: - 挑战管理器

@MainActor
@Observable
final class ChallengeManager {
    static let shared = ChallengeManager()

    private(set) var activeChallenges: [Challenge] = []
    private(set) var progressMap: [String: ChallengeProgress] = [:]

    // 今日挑战
    var dailyChallenges: [Challenge] {
        activeChallenges.filter { $0.isDaily }
    }

    // 本周挑战
    var weeklyChallenges: [Challenge] {
        activeChallenges.filter { $0.isWeekly }
    }

    private let defaults = UserDefaults.standard
    private let challengesKey = "vibe-island.challenges"
    private let progressKey = "vibe-island.challenge-progress"
    private let lastRefreshKey = "vibe-island.challenges-last-refresh"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "ChallengeManager"
    )

    private init() {
        loadChallenges()
        loadProgress()
    }

    // MARK: - 挑战生成模板

    static let dailyTemplates: [(type: ChallengeType, title: String, description: String, target: Int)] = [
        (.codingDuration, "编码 30 分钟", "今日编码 30 分钟", 30),
        (.codingDuration, "编码 1 小时", "今日编码 60 分钟", 60),
        (.codingDuration, "编码 2 小时", "今日编码 120 分钟", 120),
        (.toolUsage, "Claude 用户", "使用 Claude Code 30 分钟", 30),
        (.toolUsage, "OpenCode 用户", "使用 OpenCode 30 分钟", 30),
        (.stateChange, "完成 3 次任务", "完成 3 次编码任务", 3),
        (.petUnlock, "解锁新宠物", "今日解锁新宠物", 1),
    ]

    static let weeklyTemplates: [(type: ChallengeType, title: String, description: String, target: Int)] = [
        (.codingDuration, "周末编码达人", "本周编码 5 小时", 300),
        (.codingDuration, "周编码目标", "本周编码 10 小时", 600),
        (.codingDuration, "周编码大师", "本周编码 20 小时", 1200),
        (.toolUsage, "多工具用户", "使用 2 种以上工具", 2),
        (.stateChange, "周任务完成", "本周完成 20 次任务", 20),
    ]

    // MARK: - 刷新挑战

    func refreshChallenges() {
        let now = Date()
        let calendar = Calendar.current

        // 刷新每日挑战
        let lastDailyRefresh = defaults.object(forKey: "\(lastRefreshKey)-daily") as? Date
        let shouldRefreshDaily = lastDailyRefresh == nil ||
            !calendar.isDate(lastDailyRefresh!, inSameDayAs: now)

        if shouldRefreshDaily {
            generateDailyChallenges()
            defaults.set(now.timeIntervalSince1970, forKey: "\(lastRefreshKey)-daily")
            Self.logger.info("每日挑战已刷新")
        }

        // 刷新每周挑战
        let lastWeeklyRefresh = defaults.object(forKey: "\(lastRefreshKey)-weekly") as? Date
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let lastWeekComponents: (year: Int, week: Int)? = lastWeeklyRefresh.map {
            let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0)
            return (c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
        }
        let shouldRefreshWeekly = lastWeeklyRefresh == nil ||
            (lastWeekComponents.map { $0.year != weekComponents.yearForWeekOfYear || $0.week != weekComponents.weekOfYear } ?? true)

        if shouldRefreshWeekly {
            generateWeeklyChallenges()
            defaults.set(now.timeIntervalSince1970, forKey: "\(lastRefreshKey)-weekly")
            Self.logger.info("每周挑战已刷新")
        }

        saveChallenges()
    }

    private func generateDailyChallenges() {
        // 随机选择 3 个每日挑战
        let shuffled = Self.dailyTemplates.shuffled().prefix(3)
        let now = Date()

        activeChallenges.removeAll { $0.isDaily }

        for (index, template) in shuffled.enumerated() {
            let challenge = Challenge(
                id: "daily-\(now.timeIntervalSince1970)-\(index)",
                type: template.type,
                period: .daily,
                title: template.title,
                description: template.description,
                targetValue: template.target,
                xpMultiplier: 1.5,
                createdAt: now
            )
            activeChallenges.append(challenge)
        }
    }

    private func generateWeeklyChallenges() {
        // 随机选择 2 个每周挑战
        let shuffled = Self.weeklyTemplates.shuffled().prefix(2)
        let now = Date()

        activeChallenges.removeAll { $0.isWeekly }

        for (index, template) in shuffled.enumerated() {
            let challenge = Challenge(
                id: "weekly-\(now.timeIntervalSince1970)-\(index)",
                type: template.type,
                period: .weekly,
                title: template.title,
                description: template.description,
                targetValue: template.target,
                xpMultiplier: 2.0,
                createdAt: now
            )
            activeChallenges.append(challenge)
        }
    }

    // MARK: - 进度更新

    func updateProgress(for challengeId: String, value: Int) {
        guard let challenge = activeChallenges.first(where: { $0.id == challengeId }) else { return }

        var progress = progressMap[challengeId] ?? ChallengeProgress(
            challengeId: challengeId,
            targetValue: challenge.targetValue,
            currentValue: 0,
            isCompleted: false
        )

        progress.currentValue = value

        if value >= challenge.targetValue && !progress.isCompleted {
            progress.isCompleted = true
            progress.unlockedAt = Date()

            Self.logger.info("✅ 挑战完成: \(challenge.title)")

            progressMap[challengeId] = progress
            saveProgress()

            onChallengeCompleted?(challenge)
        } else {
            progressMap[challengeId] = progress
        }
    }

    func incrementProgress(for challengeId: String, by amount: Int = 1) {
        let current = progressMap[challengeId]?.currentValue ?? 0
        updateProgress(for: challengeId, value: current + amount)
    }

    // MARK: - 奖励领取

    func claimReward(for challengeId: String) -> Bool {
        guard let challenge = activeChallenges.first(where: { $0.id == challengeId }),
              let progress = progressMap[challengeId],
              progress.isCompleted,
              progress.claimedAt == nil else {
            return false
        }

        var updatedProgress = progress
        updatedProgress.claimedAt = Date()
        progressMap[challengeId] = updatedProgress

        // 计算 XP 奖励
        let baseXP = 50
        let bonusXP = Int(Double(baseXP) * challenge.xpMultiplier)

        PetProgressManager.shared.addCodingMinutes(bonusXP)

        saveProgress()

        Self.logger.info("💰 挑战奖励已领取: \(bonusXP) XP")

        return true
    }

    // MARK: - 查询

    func progress(for challengeId: String) -> ChallengeProgress? {
        progressMap[challengeId]
    }

    func isCompleted(_ challengeId: String) -> Bool {
        progressMap[challengeId]?.isCompleted ?? false
    }

    func isClaimed(_ challengeId: String) -> Bool {
        progressMap[challengeId]?.claimedAt != nil
    }

    // MARK: - 持久化

    private func loadChallenges() {
        if let data = defaults.data(forKey: challengesKey),
           let decoded = try? JSONDecoder().decode([Challenge].self, from: data) {
            activeChallenges = decoded
        }

        // 确保有挑战
        if activeChallenges.isEmpty {
            refreshChallenges()
        }
    }

    private func saveChallenges() {
        if let data = try? JSONEncoder().encode(activeChallenges) {
            defaults.set(data, forKey: challengesKey)
        }
    }

    private func loadProgress() {
        if let data = defaults.data(forKey: progressKey),
           let decoded = try? JSONDecoder().decode([String: ChallengeProgress].self, from: data) {
            progressMap = decoded
        }
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(progressMap) {
            defaults.set(data, forKey: progressKey)
        }
    }

    // MARK: - 回调

    var onChallengeCompleted: ((Challenge) -> Void)?

    // MARK: - 重置

    func resetProgress() {
        progressMap.removeAll()
        defaults.removeObject(forKey: progressKey)
        Self.logger.info("挑战进度已重置")
    }
}