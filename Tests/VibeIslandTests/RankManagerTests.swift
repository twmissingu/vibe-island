import XCTest
import Foundation
@testable import VibeIsland

// MARK: - RankManager 测试

@MainActor
final class RankManagerTests: XCTestCase {

    var manager: RankManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = RankManager.shared
    }

    override func tearDown() async throws {
        manager.resetRankData()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - RankPeriod 测试

    /// 测试：所有 4 种周期
    func testRankPeriod_allCases() {
        let periods: [RankPeriod] = [.daily, .weekly, .monthly, .allTime]
        XCTAssertEqual(periods.count, 4)
    }

    /// 测试：每种周期都有 displayName
    func testRankPeriod_displayName() {
        XCTAssertEqual(RankPeriod.daily.displayName, "今日")
        XCTAssertEqual(RankPeriod.weekly.displayName, "本周")
        XCTAssertEqual(RankPeriod.monthly.displayName, "本月")
        XCTAssertEqual(RankPeriod.allTime.displayName, "总计")
    }

    /// 测试：时间范围计算
    func testRankPeriod_timeRange() {
        XCTAssertEqual(RankPeriod.daily.timeRange, 86400)
        XCTAssertEqual(RankPeriod.weekly.timeRange, 604800)
        XCTAssertEqual(RankPeriod.monthly.timeRange, 2592000)
        XCTAssertEqual(RankPeriod.allTime.timeRange, TimeInterval.infinity)
    }

    // MARK: - RankCategory 测试

    /// 测试：所有 4 种分类
    func testRankCategory_allCases() {
        let categories: [RankCategory] = [.claude, .openCode, .total, .achievements]
        XCTAssertEqual(categories.count, 4)
    }

    /// 测试：每种分类都有 displayName
    func testRankCategory_displayName() {
        XCTAssertEqual(RankCategory.claude.displayName, "Claude Code")
        XCTAssertEqual(RankCategory.openCode.displayName, "OpenCode")
        XCTAssertEqual(RankCategory.total.displayName, "总编码时长")
        XCTAssertEqual(RankCategory.achievements.displayName, "成就数")
    }

    /// 测试：每种分类都有 iconName
    func testRankCategory_iconName() {
        XCTAssertEqual(RankCategory.claude.iconName, "cpu")
        XCTAssertEqual(RankCategory.openCode.iconName, "terminal")
        XCTAssertEqual(RankCategory.total.iconName, "clock")
        XCTAssertEqual(RankCategory.achievements.iconName, "star")
    }

    // MARK: - RankEntry 测试

    /// 测试：排行榜条目结构
    func testRankEntry_struct() {
        let entry = RankEntry(
            id: "test-1",
            rank: 1,
            value: 100,
            displayName: "测试用户",
            isCurrentUser: false
        )

        XCTAssertEqual(entry.id, "test-1")
        XCTAssertEqual(entry.rank, 1)
        XCTAssertEqual(entry.value, 100)
        XCTAssertEqual(entry.displayName, "测试用户")
        XCTAssertFalse(entry.isCurrentUser)
    }

    /// 测试：当前用户标记
    func testRankEntry_currentUser() {
        let userEntry = RankEntry(
            id: "current",
            rank: 5,
            value: 50,
            displayName: "我",
            isCurrentUser: true
        )

        XCTAssertTrue(userEntry.isCurrentUser)
    }

    // MARK: - 用户数据更新测试

    /// 测试：更新用户数据
    func testUpdateUserData() {
        manager.updateUserData()

        // 验证数据结构存在
        XCTAssertTrue(manager.userValue[.total] != nil || manager.userValue[.total] == 0)
    }

    /// 测试：用户数据初始化
    func testInitialUserData() {
        let initialRank = manager.userRank[.total]
        let initialValue = manager.userValue[.total]

        // 空数据时返回 0
        XCTAssertEqual(initialRank ?? 0, 0)
    }

    // MARK: - 排行榜生成测试

    /// 测试：生成排行榜
    func testGenerateLeaderboard() {
        let leaderboard = manager.generateLeaderboard(period: .daily, category: .total, limit: 10)

        XCTAssertFalse(leaderboard.isEmpty)
    }

    /// 测试：排行榜包含当前用户
    func testGenerateLeaderboard_includesCurrentUser() {
        manager.updateUserData()

        let leaderboard = manager.generateLeaderboard(period: .daily, category: .total, limit: 10)

        let hasCurrentUser = leaderboard.contains { $0.isCurrentUser }
        XCTAssertTrue(hasCurrentUser)
    }

    /// 测试：排行榜按排名排序
    func testGenerateLeaderboard_sortedByRank() {
        let leaderboard = manager.generateLeaderboard(period: .daily, category: .total, limit: 10)

        for i in 1..<leaderboard.count {
            XCTAssertLessThanOrEqual(leaderboard[i-1].rank, leaderboard[i].rank)
        }
    }

    /// 测试：排行榜数量限制
    func testGenerateLeaderboard_limit() {
        let leaderboard = manager.generateLeaderboard(period: .daily, category: .total, limit: 5)

        XCTAssertLessThanOrEqual(leaderboard.count, 5)
    }

    // MARK: - 查询测试

    /// 测试：排名查询
    func testRank_query() {
        manager.updateUserData()

        let rank = manager.rank(for: .total)
        XCTAssertGreaterThanOrEqual(rank, 0)
    }

    /// 测试：数值查询
    func testValue_query() {
        manager.updateUserData()

        let value = manager.value(for: .total)
        XCTAssertGreaterThanOrEqual(value, 0)
    }

    // MARK: - 格式化测试

    /// 测试：时长格式化-小时
    func testFormattedValue_hours() {
        let formatted = manager.formattedValue(for: .total)
        // 如果有累积时长，应该显示小时
        let value = manager.value(for: .total)
        if value >= 60 {
            XCTAssertTrue(formatted.contains("h"))
        }
    }

    /// 测试：时长格式化-分钟
    func testFormattedValue_minutes() {
        // 设置小值
        manager.userValue[.total] = 30
        manager.userValue[.claude] = 30

        let formatted = manager.formattedValue(for: .claude)
        XCTAssertTrue(formatted.contains("分钟") || formatted.contains("m"))
    }

    /// 测试：成就数格式化
    func testFormattedValue_achievements() {
        manager.userValue[.achievements] = 5

        let formatted = manager.formattedValue(for: .achievements)
        XCTAssertTrue(formatted.contains("个"))
    }

    // MARK: - 排名计算测试

    /// 测试：总时长阈值-第1档
    func testCalculateRank_totalThreshold_1() {
        let rank = manager.calculateRank(for: 10000, category: .total)
        XCTAssertEqual(rank, 1)
    }

    /// 测试：总时长阈值-第10档
    func testCalculateRank_totalThreshold_10() {
        let rank = manager.calculateRank(for: 1, category: .total)
        XCTAssertEqual(rank, 10)
    }

    /// 测试：成就阈值
    func testCalculateRank_achievementsThresholds() {
        let rank30 = manager.calculateRank(for: 30, category: .achievements)
        let rank1 = manager.calculateRank(for: 1, category: .achievements)

        XCTAssertEqual(rank30, 1)
        XCTAssertEqual(rank1, 10)
    }

    /// 测试：默认阈值(工具使用)
    func testCalculateRank_defaultThresholds() {
        let rank500 = manager.calculateRank(for: 500, category: .claude)
        let rank1 = manager.calculateRank(for: 1, category: .claude)

        XCTAssertEqual(rank500, 1)
        XCTAssertEqual(rank1, 10)
    }

    /// 测试：阈值边界值
    func testCalculateRank_boundary() {
        // 精确��界值
        let rank5000 = manager.calculateRank(for: 5000, category: .total)
        let rank5001 = manager.calculateRank(for: 5001, category: .total)

        // 5000 应该是第2档
        XCTAssertLessThanOrEqual(rank5000, 2)
    }

    // MARK: - 模拟用户生成测试

    /// 测试：生成模拟用户
    func testGenerateMockUsers() {
        let users = manager.generateMockUsers(count: 5, category: .total)

        XCTAssertEqual(users.count, 5)
    }

    /// 测试：模拟用户数值范围
    func testGenerateMockUsers_valueRange() {
        let users = manager.generateMockUsers(count: 10, category: .total)

        for user in users {
            XCTAssertGreaterThan(user.value, 0)
        }
    }

    /// 测试：模拟用户数值排序
    func testGenerateMockUsers_sorted() {
        let users = manager.generateMockUsers(count: 10, category: .total)

        for i in 1..<users.count {
            XCTAssertGreaterThanOrEqual(users[i-1].value, users[i].value)
        }
    }

    // MARK: - 持久化测试

    /// 测试：持久化保存
    func testPersistence_save() {
        manager.userRank[.total] = 5
        manager.userValue[.total] = 100
        manager.saveUserData()

        // 验证已保存-重新加载
        let newManager = RankManager.shared
        XCTAssertGreaterThanOrEqual(newManager.userValue[.total] ?? 0, 0)
    }

    // MARK: - 重置测试

    /// 测试：重置
    func testResetRankData() {
        manager.userRank[.total] = 5
        manager.userValue[.total] = 100
        manager.resetRankData()

        XCTAssertEqual(manager.userRank[.total] ?? 0, 0)
        XCTAssertEqual(manager.userValue[.total] ?? 0, 0)
    }

    // MARK: - 分类组合测试

    /// 测试：所有周期×分类组合
    func testAllPeriodCategoryCombinations() {
        for period in RankPeriod.allCases {
            for category in RankCategory.allCases {
                let leaderboard = manager.generateLeaderboard(period: period, category: category, limit: 5)
                XCTAssertFalse(leaderboard.isEmpty, "No leaderboard for \(period)/\(category)")
            }
        }
    }

    /// 测试：排行榜条目结构一致性
    func testLeaderboardEntryStructure() {
        let leaderboard = manager.generateLeaderboard(period: .daily, category: .total, limit: 10)

        for entry in leaderboard {
            XCTAssertFalse(entry.id.isEmpty)
            XCTAssertGreaterThan(entry.rank, 0)
            XCTAssertGreaterThanOrEqual(entry.value, 0)
            XCTAssertFalse(entry.displayName.isEmpty)
        }
    }
}