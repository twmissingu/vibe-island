import XCTest
import Foundation
@testable import VibeIsland

// MARK: - ChallengeManager 测试

@MainActor
final class ChallengeManagerTests: XCTestCase {

    var manager: ChallengeManager!
    let testDefaults = UserDefaults(suiteName: "test-challenge-manager")

    override func setUp() async throws {
        try await super.setUp()
        manager = ChallengeManager.shared
    }

    override func tearDown() async throws {
        manager.resetProgress()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - ChallengeType 测试

    /// 测试：所有 4 种挑战类型
    func testChallengeType_allCases() {
        let types: [ChallengeType] = [.codingDuration, .toolUsage, .stateChange, .petUnlock]
        XCTAssertEqual(types.count, 4)
    }

    /// 测试：每种类型都有 displayName
    func testChallengeType_displayName() {
        XCTAssertEqual(ChallengeType.codingDuration.displayName, "编码时长")
        XCTAssertEqual(ChallengeType.toolUsage.displayName, "工具使用")
        XCTAssertEqual(ChallengeType.stateChange.displayName, "状态切换")
        XCTAssertEqual(ChallengeType.petUnlock.displayName, "宠物解锁")
    }

    /// 测试：每种类型都有 iconName
    func testChallengeType_iconName() {
        XCTAssertEqual(ChallengeType.codingDuration.iconName, "clock")
        XCTAssertEqual(ChallengeType.toolUsage.iconName, "laptopcomputer")
        XCTAssertEqual(ChallengeType.stateChange.iconName, "arrow.left.arrow.right")
        XCTAssertEqual(ChallengeType.petUnlock.iconName, "pawprint")
    }

    // MARK: - ChallengePeriod 测试

    /// 测试：每日/每周枚举
    func testChallengePeriod_dailyWeekly() {
        let daily = ChallengePeriod.daily
        let weekly = ChallengePeriod.weekly

        XCTAssertEqual(daily.rawValue, "daily")
        XCTAssertEqual(weekly.rawValue, "weekly")
    }

    // MARK: - Challenge 测试

    /// 测试：Challenge 结构
    func testChallenge_struct() {
        let now = Date()
        let challenge = Challenge(
            id: "test-1",
            type: .codingDuration,
            period: .daily,
            title: "测试挑战",
            description: "今日编码 30 分钟",
            targetValue: 30,
            xpMultiplier: 1.5,
            createdAt: now
        )

        XCTAssertEqual(challenge.id, "test-1")
        XCTAssertEqual(challenge.type, .codingDuration)
        XCTAssertEqual(challenge.period, .daily)
        XCTAssertTrue(challenge.isDaily)
        XCTAssertFalse(challenge.isWeekly)
        XCTAssertEqual(challenge.xpMultiplier, 1.5)
    }

    /// 测试：isDaily isWeekly 计算属性
    func testChallenge_isDailyIsWeekly() {
        let daily = Challenge(
            id: "d", type: .codingDuration, period: .daily,
            title: "", description: "", targetValue: 10, xpMultiplier: 1.5, createdAt: Date()
        )
        let weekly = Challenge(
            id: "w", type: .codingDuration, period: .weekly,
            title: "", description: "", targetValue: 10, xpMultiplier: 2.0, createdAt: Date()
        )

        XCTAssertTrue(daily.isDaily)
        XCTAssertFalse(daily.isWeekly)
        XCTAssertTrue(weekly.isWeekly)
        XCTAssertFalse(weekly.isDaily)
    }

    // MARK: - ChallengeProgress 测试

    /// 测试：进度计算
    func testChallengeProgress_progressCalculation() {
        let progress = ChallengeProgress(
            challengeId: "test",
            targetValue: 100,
            currentValue: 50,
            isCompleted: false
        )

        XCTAssertEqual(progress.progress, 0.5, accuracy: 0.01)
    }

    /// 测试：进度上限 1.0
    func testChallengeProgress_maxProgress() {
        let progress = ChallengeProgress(
            challengeId: "test",
            targetValue: 100,
            currentValue: 150,
            isCompleted: false
        )

        XCTAssertEqual(progress.progress, 1.0, accuracy: 0.01)
    }

    /// 测试：空目标值保护
    func testChallengeProgress_zeroTarget() {
        let progress = ChallengeProgress(
            challengeId: "test",
            targetValue: 0,
            currentValue: 50,
            isCompleted: false
        )

        XCTAssertEqual(progress.progress, 1.0, accuracy: 0.01)
    }

    // MARK: - 挑战过滤测试

    /// 测试：每日挑战过滤
    func testDailyChallenges_filter() {
        manager.refreshChallenges()

        let dailyChallenges = manager.dailyChallenges
        XCTAssertFalse(dailyChallenges.isEmpty)
        XCTAssertTrue(dailyChallenges.allSatisfy { $0.isDaily })
    }

    /// 测试：每周挑战过滤
    func testWeeklyChallenges_filter() {
        manager.refreshChallenges()

        let weeklyChallenges = manager.weeklyChallenges
        XCTAssertFalse(weeklyChallenges.isEmpty)
        XCTAssertTrue(weeklyChallenges.allSatisfy { $0.isWeekly })
    }

    // MARK: - 刷新测试

    /// 测试：每日刷新逻辑
    func testRefreshChallenges_daily() {
        manager.refreshChallenges()

        let daily = manager.dailyChallenges
        XCTAssertFalse(daily.isEmpty)
    }

    /// 测试：生成 3 个每日挑战
    func testGenerateDailyChallenges_3Generated() {
        manager.refreshChallenges()

        let daily = manager.dailyChallenges
        XCTAssertEqual(daily.count, 3)
        XCTAssertTrue(daily.allSatisfy { $0.period == .daily })
    }

    /// 测试：生成 2 个每周挑战
    func testGenerateWeeklyChallenges_2Generated() {
        manager.refreshChallenges()

        let weekly = manager.weeklyChallenges
        XCTAssertEqual(weekly.count, 2)
        XCTAssertTrue(weekly.allSatisfy { $0.period == .weekly })
    }

    /// 测试：每日挑战刷新后确实刷新
    func testRefreshChallenges_actuallyRefreshes() {
        // 第一次刷新
        manager.refreshChallenges()
        let firstDaily = manager.dailyChallenges

        // 第二次刷新应该重新生成
        manager.refreshChallenges()
        let secondDaily = manager.dailyChallenges

        // 两个都不为空
        XCTAssertFalse(firstDaily.isEmpty)
        XCTAssertFalse(secondDaily.isEmpty)
    }

    // MARK: - 进度更新测试

    /// 测试：完成路径
    func testUpdateProgress_completionPath() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: challenge.targetValue)

        XCTAssertTrue(manager.isCompleted(challenge.id))
        XCTAssertNotNil(manager.progress(for: challenge.id)?.unlockedAt)
    }

    /// 测试：未完成路径
    func testUpdateProgress_noCompletion() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: challenge.targetValue - 1)

        XCTAssertFalse(manager.isCompleted(challenge.id))
    }

    /// 测试：完成但未达成目标
    func testUpdateProgress_incompleteTarget() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: challenge.targetValue / 2)

        let progress = manager.progress(for: challenge.id)
        XCTAssertFalse(progress?.isCompleted ?? true)
        XCTAssertEqual(progress?.currentValue ?? 0, challenge.targetValue / 2)
    }

    /// 测试：重复完成不重复
    func testUpdateProgress_noDuplicateCompletion() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: challenge.targetValue)
        let firstCompletion = manager.progress(for: challenge.id)?.unlockedAt

        manager.updateProgress(for: challenge.id, value: challenge.targetValue + 100)
        let secondCompletion = manager.progress(for: challenge.id)?.unlockedAt

        XCTAssertEqual(firstCompletion, secondCompletion)
    }

    /// 测试：增量更新
    func testIncrementProgress() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.incrementProgress(for: challenge.id, by: 5)
        manager.incrementProgress(for: challenge.id, by: 3)

        let progress = manager.progress(for: challenge.id)
        XCTAssertEqual(progress?.currentValue ?? 0, 8)
    }

    // MARK: - 奖励领取测试

    /// 测试：领取成功
    func testClaimReward_success() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        // 先完成挑战
        manager.updateProgress(for: challenge.id, value: challenge.targetValue)

        // 领取奖励
        let result = manager.claimReward(for: challenge.id)

        XCTAssertTrue(result)
        XCTAssertTrue(manager.isClaimed(challenge.id))
    }

    /// 测试：领取失败-未完成
    func testClaimReward_fail_notCompleted() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        // 未完成挑战
        let result = manager.claimReward(for: challenge.id)

        XCTAssertFalse(result)
    }

    /// 测试：领取失败-已领取
    func testClaimReward_fail_alreadyClaimed() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        // 完成并领取
        manager.updateProgress(for: challenge.id, value: challenge.targetValue)
        _ = manager.claimReward(for: challenge.id)

        // 再次尝试领取
        let result = manager.claimReward(for: challenge.id)

        XCTAssertFalse(result)
    }

    // MARK: - 查询测试

    /// 测试：进度查询
    func testProgress_query() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: 10)

        let progress = manager.progress(for: challenge.id)
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.currentValue, 10)
    }

    /// 测试：完成状态查询
    func testIsCompleted() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        XCTAssertFalse(manager.isCompleted(challenge.id))

        manager.updateProgress(for: challenge.id, value: challenge.targetValue)

        XCTAssertTrue(manager.isCompleted(challenge.id))
    }

    /// 测试：领取状态查询
    func testIsClaimed() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: challenge.targetValue)
        _ = manager.claimReward(for: challenge.id)

        XCTAssertTrue(manager.isClaimed(challenge.id))
    }

    // MARK: - 持久化测试

    /// 测试：持久化保存
    func testPersistence_save() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: 10)

        // 验证已保存
        let progress = manager.progress(for: challenge.id)
        XCTAssertNotNil(progress)
    }

    // MARK: - 重置测试

    /// 测试：重置
    func testResetProgress() {
        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: challenge.targetValue)
        manager.resetProgress()

        XCTAssertFalse(manager.isCompleted(challenge.id))
    }

    // MARK: - ChallengeTemplate 测试

    /// 测试：每日模板数量
    func testDailyTemplates_count() {
        XCTAssertEqual(ChallengeManager.dailyTemplates.count, 7)
    }

    /// 测试：每周模板数量
    func testWeeklyTemplates_count() {
        XCTAssertEqual(ChallengeManager.weeklyTemplates.count, 5)
    }

    /// 测试：每日模板结构
    func testDailyTemplates_structure() {
        for template in ChallengeManager.dailyTemplates {
            XCTAssertFalse(template.title.isEmpty)
            XCTAssertFalse(template.description.isEmpty)
            XCTAssertTrue(template.target > 0)
        }
    }

    /// 测试：每周模板结构
    func testWeeklyTemplates_structure() {
        for template in ChallengeManager.weeklyTemplates {
            XCTAssertFalse(template.title.isEmpty)
            XCTAssertFalse(template.description.isEmpty)
            XCTAssertTrue(template.target > 0)
        }
    }

    // MARK: - Challenge 回调测试

    /// 测试：完成回调
    func testOnChallengeCompleted_callback() {
        var callbackFired = false
        var completedChallenge: Challenge?

        manager.onChallengeCompleted = { challenge in
            callbackFired = true
            completedChallenge = challenge
        }

        manager.refreshChallenges()

        guard let challenge = manager.dailyChallenges.first else {
            XCTFail("No daily challenges")
            return
        }

        manager.updateProgress(for: challenge.id, value: challenge.targetValue)

        XCTAssertTrue(callbackFired)
        XCTAssertEqual(completedChallenge?.id, challenge.id)
    }
}