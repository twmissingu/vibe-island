import Foundation
import OSLog

// MARK: - 排行榜类型

enum RankPeriod: String, Codable, CaseIterable {
    case daily    // 今日排名
    case weekly   // 本周排名
    case monthly // 本月排名
    case allTime // 总排名

    var displayName: String {
        switch self {
        case .daily: return "今日"
        case .weekly: return "本周"
        case .monthly: return "本月"
        case .allTime: return "总计"
        }
    }

    var timeRange: TimeInterval {
        switch self {
        case .daily: return 86400           // 1天
        case .weekly: return 604800          // 7天
        case .monthly: return 2592000        // 30天
        case .allTime: return TimeInterval.infinity
        }
    }
}

enum RankCategory: String, Codable, CaseIterable {
    case claude      // Claude Code
    case openCode   // OpenCode
    case total    // 总时长
    case achievements // 成就数

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .openCode: return "OpenCode"
        case .total: return "总编码时长"
        case .achievements: return "成就数"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "cpu"
        case .openCode: return "terminal"
        case .total: return "clock"
        case .achievements: return "star"
        }
    }
}

// MARK: - 排行榜条目

struct RankEntry: Codable, Identifiable, Sendable {
    let id: String
    let rank: Int
    let value: Int
    let displayName: String
    let isCurrentUser: Bool
}

// MARK: - 排行榜管理器

/// 本地排行榜管理器
/// 由于是单机应用，创建模拟的排行榜数据用于展示和激励
@MainActor
@Observable
final class RankManager {
    static let shared = RankManager()

    // 用户当前排名数据
    private(set) var userRank: [RankCategory: Int] = [:]
    private(set) var userValue: [RankCategory: Int] = [:]

    private let defaults = UserDefaults.standard

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "RankManager"
    )

    private init() {
        loadUserData()
    }

    // MARK: - 更新用户数据

    func updateUserData() {
        let progress = PetProgressManager.shared
        let tracker = CodingTimeTracker.shared

        // 更新总编码时长排名
        let totalMinutes = progress.totalCodingMinutes
        userValue[.total] = totalMinutes
        userRank[.total] = calculateRank(for: totalMinutes, category: .total)

        // 更新今日排名
        let todayMinutes = tracker.todayCodingMinutes
        userValue[.daily] = todayMinutes
        userRank[.daily] = calculateRank(for: todayMinutes, category: .claude)

        // 更新成就数
        let achievementCount = AchievementManager.shared.unlockedCount
        userValue[.achievements] = achievementCount
        userRank[.achievements] = calculateRank(for: achievementCount, category: .achievements)

        saveUserData()

        Self.logger.debug("用户排名数据已更新: 今日 \(todayMinutes) 分钟, 总计 \(totalMinutes) 分钟")
    }

    // MARK: - 排行榜生成

    func generateLeaderboard(period: RankPeriod, category: RankCategory, limit: Int = 10) -> [RankEntry] {
        var entries: [RankEntry] = []

        // 生成模拟数据 + 用户实际数据
        let mockUsers = generateMockUsers(count: limit - 1, category: category)

        for (index, user) in mockUsers.enumerated() {
            entries.append(RankEntry(
                id: "mock-\(index)",
                rank: index + 1,
                value: user.value,
                displayName: user.name,
                isCurrentUser: false
            ))
        }

        // 添加用户数据
        if let userValue = userValue[category] {
            let userRank = calculateRank(for: userValue, category: category)
            entries.append(RankEntry(
                id: "current-user",
                rank: userRank,
                value: userValue,
                displayName: "我",
                isCurrentUser: true
            ))
        }

        // 按排名排序
        entries.sort { $0.rank < $1.rank }

        return Array(entries.prefix(limit))
    }

    // MARK: - 查询

    func rank(for category: RankCategory) -> Int {
        userRank[category] ?? 0
    }

    func value(for category: RankCategory) -> Int {
        userValue[category] ?? 0
    }

    func formattedValue(for category: RankCategory) -> String {
        let v = value(for: category)
        switch category {
        case .achievements:
            return "\(v) 个"
        default:
            if v >= 60 {
                let hours = v / 60
                let mins = v % 60
                return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            }
            return "\(v) 分钟"
        }
    }

    // MARK: - 私有方法

    private func calculateRank(for value: Int, category: RankCategory) -> Int {
        // 模拟排名计算：基于值的相对位置
        // 实际应用中，这个应该基于服务器返回的真实排名
        let thresholds: [Int]

        switch category {
        case .total:
            thresholds = [10000, 5000, 2000, 1000, 500, 200, 100, 50, 20, 1]
        case .achievements:
            thresholds = [30, 25, 20, 15, 12, 10, 8, 6, 4, 1]
        default:
            thresholds = [500, 200, 100, 50, 20, 10, 5, 3, 2, 1]
        }

        for (index, threshold) in thresholds.enumerated() {
            if value >= threshold {
                return index + 1
            }
        }
        return thresholds.count + 1
    }

    private func generateMockUsers(count: Int, category: RankCategory) -> [(name: String, value: Int)] {
        let names = [
            " coding wizard", "swift ninja", "ai craftsman", "dev master",
            "byte rider", "silicon sage", "code poet", "logic lord",
            "bug hunter", "stack star"
        ]

        return (0..<count).map { index in
            let baseValue: Int
            switch category {
            case .total:
                baseValue = Int.random(in: 50...8000)
            case .achievements:
                baseValue = Int.random(in: 1...28)
            default:
                baseValue = Int.random(in: 10...600)
            }
            return (names[index % names.count], baseValue)
        }.sorted { $0.value > $1.value }
    }

    // MARK: - 持久化

    private let userRankKey = "vibe-island.user-rank"
    private let userValueKey = "vibe-island.user-value"

    private func loadUserData() {
        if let rankData = defaults.dictionary(forKey: userRankKey) as? [String: Int] {
            for (key, value) in rankData {
                if let category = RankCategory(rawValue: key) {
                    userRank[category] = value
                }
            }
        }

        if let valueData = defaults.dictionary(forKey: userValueKey) as? [String: Int] {
            for (key, value) in valueData {
                if let category = RankCategory(rawValue: key) {
                    userValue[category] = value
                }
            }
        }
    }

    private func saveUserData() {
        var rankData: [String: Int] = [:]
        var valueData: [String: Int] = [:]

        for (category, rank) in userRank {
            rankData[category.rawValue] = rank
        }
        for (category, value) in userValue {
            valueData[category.rawValue] = value
        }

        defaults.set(rankData, forKey: userRankKey)
        defaults.set(valueData, forKey: userValueKey)
    }

    // MARK: - 重置

    func resetRankData() {
        userRank.removeAll()
        userValue.removeAll()
        defaults.removeObject(forKey: userRankKey)
        defaults.removeObject(forKey: userValueKey)
        Self.logger.info("排行榜数据已重置")
    }
}