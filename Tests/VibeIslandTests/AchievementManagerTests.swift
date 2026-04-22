import XCTest
import Foundation
@testable import VibeIsland

// MARK: - AchievementManager 测试

@MainActor
final class AchievementManagerTests: XCTestCase {

    var manager: AchievementManager!
    let testDefaults = UserDefaults(suiteName: "test-achievement-manager")

    override func setUp() async throws {
        try await super.setUp()
        // 使用测试专用的 UserDefaults
        manager = AchievementManager.makeForTesting(testDefaults: testDefaults!)
    }

    override func tearDown() async throws {
        manager.resetProgress()
        manager = nil
        testDefaults?.removePersistentDomain(forName: "test-achievement-manager")
        try await super.tearDown()
    }

    // MARK: - AchievementCategory 测试

    /// 测试：所有 5 大类枚举
    func testAchievementCategory_allCases() {
        let categories: [AchievementCategory] = [.codingTime, .toolUsage, .petCollection, .streak, .special]
        XCTAssertEqual(categories.count, 5)
    }

    /// 测试：每类都有 displayName
    func testAchievementCategory_displayName() {
        XCTAssertEqual(AchievementCategory.codingTime.displayName, "编码时长")
        XCTAssertEqual(AchievementCategory.toolUsage.displayName, "工具使用")
        XCTAssertEqual(AchievementCategory.petCollection.displayName, "宠物收集")
        XCTAssertEqual(AchievementCategory.streak.displayName, "连续记录")
        XCTAssertEqual(AchievementCategory.special.displayName, "特殊事件")
    }

    /// 测试：每类都有 iconName
    func testAchievementCategory_iconName() {
        XCTAssertEqual(AchievementCategory.codingTime.iconName, "clock")
        XCTAssertEqual(AchievementCategory.toolUsage.iconName, "wrench.and.screwdriver")
        XCTAssertEqual(AchievementCategory.petCollection.iconName, "pawprint")
        XCTAssertEqual(AchievementCategory.streak.iconName, "flame")
        XCTAssertEqual(AchievementCategory.special.iconName, "star")
    }

    // MARK: - AchievementRarity 测试

    /// 测试：所有 5 种稀有度
    func testAchievementRarity_allCases() {
        let rarities: [AchievementRarity] = [.common, .uncommon, .rare, .epic, .legendary]
        XCTAssertEqual(rarities.count, 5)
    }

    /// 测试：每种稀有度都有颜色
    func testAchievementRarity_color() {
        XCTAssertEqual(AchievementRarity.common.color, "#A0A0A0")
        XCTAssertEqual(AchievementRarity.uncommon.color, "#4CAF50")
        XCTAssertEqual(AchievementRarity.rare.color, "#2196F3")
        XCTAssertEqual(AchievementRarity.epic.color, "#9C27B0")
        XCTAssertEqual(AchievementRarity.legendary.color, "#FFD700")
    }

    // MARK: - Achievement 测试

    /// 测试：验证 30 个成就加载
    func testAllAchievements_30Loaded() {
        XCTAssertEqual(AchievementManager.allAchievements.count, 30)
    }

    /// 测试：成就按类别分布
    func testAchievements_byCategory() {
        let codingTime = AchievementManager.allAchievements.filter { $0.category == .codingTime }
        let toolUsage = AchievementManager.allAchievements.filter { $0.category == .toolUsage }
        let petCollection = AchievementManager.allAchievements.filter { $0.category == .petCollection }
        let streak = AchievementManager.allAchievements.filter { $0.category == .streak }
        let special = AchievementManager.allAchievements.filter { $0.category == .special }

        XCTAssertEqual(codingTime.count, 10)
        XCTAssertEqual(toolUsage.count, 6)
        XCTAssertEqual(petCollection.count, 5)
        XCTAssertEqual(streak.count, 4)
        XCTAssertEqual(special.count, 5)
    }

    /// 测试：成就 rarity 计算
    func testAchievement_rarity() {
        let common = Achievement(id: "test", name: "Test", description: "Test", category: .codingTime, targetValue: 30, xpReward: 10)
        let uncommon = Achievement(id: "test", name: "Test", description: "Test", category: .codingTime, targetValue: 100, xpReward: 10)
        let rare = Achievement(id: "test", name: "Test", description: "Test", category: .codingTime, targetValue: 500, xpReward: 10)
        let epic = Achievement(id: "test", name: "Test", description: "Test", category: .codingTime, targetValue: 3000, xpReward: 10)
        let legendary = Achievement(id: "test", name: "Test", description: "Test", category: .codingTime, targetValue: 10000, xpReward: 10)

        XCTAssertEqual(common.rarity, .common)
        XCTAssertEqual(uncommon.rarity, .uncommon)
        XCTAssertEqual(rare.rarity, .rare)
        XCTAssertEqual(epic.rarity, .epic)
        XCTAssertEqual(legendary.rarity, .legendary)
    }

    // MARK: - 进度更新测试

    /// 测试：达成条件解锁路径
    func testUpdateProgress_unlockPath() {
        let initialTotalXP = manager.totalXP
        let initialUnlockedCount = manager.unlockedCount

        manager.updateProgress(for: "coding-10m", value: 10)

        XCTAssertTrue(manager.isUnlocked("coding-10m"))
        XCTAssertEqual(manager.totalXP, initialTotalXP + 10)
        XCTAssertEqual(manager.unlockedCount, initialUnlockedCount + 1)
    }

    /// 测试：未达成条件不解锁
    func testUpdateProgress_noUnlock() {
        manager.updateProgress(for: "coding-10m", value: 5)

        XCTAssertFalse(manager.isUnlocked("coding-10m"))
        XCTAssertEqual(manager.unlockedCount, 0)
    }

    /// 测试：增量更新
    func testIncrementProgress() {
        manager.incrementProgress(for: "coding-10m", by: 5)
        XCTAssertEqual(manager.progress(for: "coding-10m")?.currentValue, 5)

        manager.incrementProgress(for: "coding-10m", by: 3)
        XCTAssertEqual(manager.progress(for: "coding-10m")?.currentValue, 8)
    }

    /// 测试：重复解锁不重复奖励
    func testUpdateProgress_noDuplicateReward() {
        manager.updateProgress(for: "coding-10m", value: 10)
        let totalXPAfterFirst = manager.totalXP

        manager.updateProgress(for: "coding-10m", value: 15)
        let totalXPAfterSecond = manager.totalXP

        XCTAssertEqual(totalXPAfterFirst, totalXPAfterSecond)
    }

    // MARK: - 查询测试

    /// 测试：进度查询
    func testProgress_query() {
        manager.updateProgress(for: "coding-10m", value: 5)

        let progress = manager.progress(for: "coding-10m")
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.currentValue, 5)
        XCTAssertFalse(progress?.isUnlocked ?? true)
    }

    /// 测试：解锁状态查询
    func testIsUnlocked() {
        XCTAssertFalse(manager.isUnlocked("coding-10m"))

        manager.updateProgress(for: "coding-10m", value: 10)
        XCTAssertTrue(manager.isUnlocked("coding-10m"))
    }

    /// 测试：分类查询
    func testAchievements_forCategory() {
        let achievements = manager.achievements(for: .codingTime)
        XCTAssertEqual(achievements.count, 10)
        XCTAssertTrue(achievements.allSatisfy { $0.category == .codingTime })
    }

    /// 测试：已解锁成就分类查询
    func testUnlockedAchievements_forCategory() {
        manager.updateProgress(for: "coding-10m", value: 10)
        manager.updateProgress(for: "coding-1h", value: 60)

        let unlocked = manager.unlockedAchievements(for: .codingTime)
        XCTAssertEqual(unlocked.count, 2)
    }

    // MARK: - 回调测试

    /// ��试：解锁回调
    func testOnAchievementUnlocked_callback() {
        var callbackFired = false
        var unlockedAchievement: Achievement?

        manager.onAchievementUnlocked = { achievement in
            callbackFired = true
            unlockedAchievement = achievement
        }

        manager.updateProgress(for: "coding-10m", value: 10)

        XCTAssertTrue(callbackFired)
        XCTAssertEqual(unlockedAchievement?.id, "coding-10m")
    }

    // MARK: - 持久化测试

    /// 测试：持久化保存和加载
    func testPersistence_loadSave() {
        manager.updateProgress(for: "coding-10m", value: 10)

        // 创建新实例验证持久化
        let newManager = AchievementManager.makeForTesting(testDefaults: testDefaults!)
        XCTAssertTrue(newManager.isUnlocked("coding-10m"))
    }

    // MARK: - 重置测试

    /// 测试：重置功能
    func testResetProgress() {
        manager.updateProgress(for: "coding-10m", value: 10)
        manager.resetProgress()

        XCTAssertFalse(manager.isUnlocked("coding-10m"))
        XCTAssertEqual(manager.totalXP, 0)
        XCTAssertEqual(manager.unlockedCount, 0)
    }
}

// MARK: - AchievementManager 工厂方法

extension AchievementManager {
    /// 创建测试实例
    static func makeForTesting(testDefaults: UserDefaults) -> AchievementManager {
        let manager = AchievementManager.shared
        manager.resetProgress()
        return manager
    }
}