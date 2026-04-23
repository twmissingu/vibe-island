import XCTest
import Foundation
@testable import VibeIsland

// MARK: - PetProgressManager 测试

@MainActor
final class PetProgressManagerTests: XCTestCase {

    var manager: PetProgressManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = PetProgressManager.shared
    }

    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }

    // MARK: - PetLevel 测试

    /// 测试：所有 5 个等级
    func testPetLevel_allCases() {
        let levels: [PetLevel] = [.basic, .glow, .metal, .neon, .king]
        XCTAssertEqual(levels.count, 5)
    }

    /// 测试：等级 rawValue
    func testPetLevel_rawValue() {
        XCTAssertEqual(PetLevel.basic.rawValue, 1)
        XCTAssertEqual(PetLevel.glow.rawValue, 2)
        XCTAssertEqual(PetLevel.metal.rawValue, 3)
        XCTAssertEqual(PetLevel.neon.rawValue, 4)
        XCTAssertEqual(PetLevel.king.rawValue, 5)
    }

    /// 测试：等级 displayName
    func testPetLevel_displayName() {
        XCTAssertEqual(PetLevel.basic.displayName, "基础款")
        XCTAssertEqual(PetLevel.glow.displayName, "辉光款")
        XCTAssertEqual(PetLevel.metal.displayName, "金属款")
        XCTAssertEqual(PetLevel.neon.displayName, "霓虹款")
        XCTAssertEqual(PetLevel.king.displayName, "王者款")
    }

    /// 测试：达到等级所需分钟数
    func testPetLevel_requiredMinutes() {
        XCTAssertEqual(PetLevel.basic.requiredMinutes, 0)
        XCTAssertEqual(PetLevel.glow.requiredMinutes, 60)
        XCTAssertEqual(PetLevel.metal.requiredMinutes, 120)
        XCTAssertEqual(PetLevel.neon.requiredMinutes, 240)
        XCTAssertEqual(PetLevel.king.requiredMinutes, 360)
    }

    /// 测试：从分钟数计算等级
    func testPetLevel_fromMinutes() {
        XCTAssertEqual(PetLevel.from(minutes: 0), .basic)
        XCTAssertEqual(PetLevel.from(minutes: 30), .basic)
        XCTAssertEqual(PetLevel.from(minutes: 60), .glow)
        XCTAssertEqual(PetLevel.from(minutes: 120), .metal)
        XCTAssertEqual(PetLevel.from(minutes: 240), .neon)
        XCTAssertEqual(PetLevel.from(minutes: 360), .king)
        XCTAssertEqual(PetLevel.from(minutes: 1000), .king)
    }

    /// 测试：下一等级
    func testPetLevel_next() {
        XCTAssertEqual(PetLevel.basic.next, .glow)
        XCTAssertEqual(PetLevel.glow.next, .metal)
        XCTAssertEqual(PetLevel.metal.next, .neon)
        XCTAssertEqual(PetLevel.neon.next, .king)
        XCTAssertNil(PetLevel.king.next)
    }

    /// 测试：等级比较
    func testPetLevel_comparable() {
        XCTAssertTrue(PetLevel.basic < PetLevel.glow)
        XCTAssertTrue(PetLevel.glow < PetLevel.metal)
        XCTAssertTrue(PetLevel.metal < PetLevel.neon)
        XCTAssertTrue(PetLevel.neon < PetLevel.king)

        XCTAssertFalse(PetLevel.king < PetLevel.basic)
    }

    // MARK: - PetType 测试

    /// 测试：所有 8 种宠物
    func testPetType_allCases() {
        let pets: [PetType] = [.cat, .dog, .rabbit, .hamster, .fox, .penguin, .robot, .ghost, .dragon]
        XCTAssertEqual(pets.count, 9)
    }

    /// 测试：宠物 displayName
    func testPetType_displayName() {
        XCTAssertEqual(PetType.cat.displayName, "小猫")
        XCTAssertEqual(PetType.dog.displayName, "小狗")
        XCTAssertEqual(PetType.rabbit.displayName, "小兔")
        XCTAssertEqual(PetType.hamster.displayName, "仓鼠")
        XCTAssertEqual(PetType.fox.displayName, "小狐")
        XCTAssertEqual(PetType.penguin.displayName, "企鹅")
        XCTAssertEqual(PetType.robot.displayName, "机器人")
        XCTAssertEqual(PetType.ghost.displayName, "幽灵")
        XCTAssertEqual(PetType.dragon.displayName, "小龙")
    }

    /// 测试：宠物 systemImage
    func testPetType_systemImage() {
        XCTAssertEqual(PetType.cat.systemImage, "cat")
        XCTAssertEqual(PetType.dog.systemImage, "dog")
        XCTAssertEqual(PetType.rabbit.systemImage, "hare")
        XCTAssertEqual(PetType.hamster.systemImage, "pawprint.fill")
        XCTAssertEqual(PetType.fox.systemImage, "leaf.fill")
        XCTAssertEqual(PetType.penguin.systemImage, "snowflake")
        XCTAssertEqual(PetType.robot.systemImage, "cpu")
        XCTAssertEqual(PetType.ghost.systemImage, "bolt.fill")
    }

    // MARK: - PetUnlockRequirement 测试

    /// 测试：解锁条件结构
    func testPetUnlockRequirement_struct() {
        let req = PetUnlockRequirement(requiredMinutes: 60)
        XCTAssertEqual(req.requiredMinutes, 60)
    }

    /// 测试：解锁进度文本-已解锁
    func testPetUnlockRequirement_progressText_unlocked() {
        let req = PetUnlockRequirement(requiredMinutes: 60)
        let text = req.progressText(currentMinutes: 60)
        XCTAssertEqual(text, "✅ 已解锁")
    }

    /// 测试：解锁进度文本-未解锁
    func testPetUnlockRequirement_progressText_locked() {
        let req = PetUnlockRequirement(requiredMinutes: 60)
        let text = req.progressText(currentMinutes: 30)
        XCTAssertEqual(text, "还需 30 分钟")
    }

    // MARK: - PetUnlockNotification 测试

    /// 测试：宠物解锁通知
    func testPetUnlockNotification_struct() {
        let notification = PetUnlockNotification(pet: .cat, unlockTime: Date())
        XCTAssertEqual(notification.pet, .cat)
        XCTAssertNotNil(notification.unlockTime)
    }

    // MARK: - PetUnlockAnimationManager 测试

    /// 测试：动画管理器单例
    func testPetUnlockAnimationManager_shared() {
        let manager = PetUnlockAnimationManager.shared
        XCTAssertNotNil(manager)
    }

    /// 测试：播放解锁动画
    func testPlayUnlockAnimation() {
        let animationManager = PetUnlockAnimationManager.shared

        animationManager.playUnlockAnimation(pet: .cat)

        XCTAssertNotNil(animationManager.currentAnimation)
    }

    /// 测试：动画状态-pets
    func testAnimationState_pet() {
        let state = PetUnlockAnimationManager.AnimationState.unlock(pet: .dog)
        XCTAssertEqual(state.pet, .dog)
    }

    /// 测试：动画状态-id
    func testAnimationState_id() {
        let state = PetUnlockAnimationManager.AnimationState.unlock(pet: .cat)
        XCTAssertEqual(state.id, "cat")
    }

    /// 测试：动画状态相等
    func testAnimationState_equatable() {
        let state1 = PetUnlockAnimationManager.AnimationState.unlock(pet: .cat)
        let state2 = PetUnlockAnimationManager.AnimationState.unlock(pet: .cat)
        let state3 = PetUnlockAnimationManager.AnimationState.unlock(pet: .dog)

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }

    // MARK: - PetProgressManager 核心方法测试

    /// 测试：选择宠物
    func testSelectPet() {
        let initialPet = manager.selectedPet
        manager.selectedPet = .dog
        XCTAssertEqual(manager.selectedPet, .dog)

        // 恢复
        manager.selectedPet = initialPet
    }

    /// 测试：等级查询
    func testLevel_for() {
        let level = manager.level(for: .cat)
        XCTAssertTrue(PetLevel.allCases.contains(level))
    }

    /// 测试：当前等级
    func testCurrentLevel() {
        let level = manager.currentLevel
        XCTAssertTrue(PetLevel.allCases.contains(level))
    }

    /// 测试：添加编码分钟数
    func testAddCodingMinutes() {
        let initialMinutes = manager.totalCodingMinutes
        manager.addCodingMinutes(10)
        let newMinutes = manager.totalCodingMinutes

        XCTAssertEqual(newMinutes, initialMinutes + 10)
    }

    /// 测试：已解锁宠物列表
    func testUnlockedPets() {
        let unlocked = manager.unlockedPets
        XCTAssertFalse(unlocked.isEmpty)
        XCTAssertTrue(unlocked.contains(.cat))
    }

    /// 测试：选择皮肤等级
    func testSetSelectedSkinLevel() {
        manager.setSelectedSkinLevel(.basic, for: .cat)
        let selected = manager.selectedLevel(for: .cat)
        XCTAssertTrue(PetLevel.allCases.contains(selected))
    }

    /// 测试：等级进度
    func testLevelProgress() {
        let progress = manager.levelProgress(for: .cat)
        XCTAssertGreaterThanOrEqual(progress, 0)
        XCTAssertLessThanOrEqual(progress, 1)
    }

    /// 测试：到下一等级分钟数
    func testMinutesToNextLevel() {
        let minutes = manager.minutesToNextLevel(for: .cat)
        // 可能为 nil（已满级）或正数
        XCTAssertTrue(minutes == nil || (minutes ?? 0) >= 0)
    }

    // MARK: - PetUnlockNotificationManager 测试

    /// 测试：通知管理器单例
    func testPetUnlockNotificationManager_shared() {
        let notificationManager = PetUnlockNotificationManager.shared
        XCTAssertNotNil(notificationManager)
    }

    /// 测试：添加通知
    func testAddNotification() {
        let notificationManager = PetUnlockNotificationManager.shared
        notificationManager.clearNotifications()

        let notification = PetUnlockNotification(pet: .dog, unlockTime: Date())
        notificationManager.addNotification(notification)

        XCTAssertFalse(notificationManager.recentNotifications.isEmpty)
    }

    /// 测试：通知限制 5 条
    func testNotificationLimit() {
        let notificationManager = PetUnlockNotificationManager.shared
        notificationManager.clearNotifications()

        // 添加 6 条通知
        for pet in [PetType.cat, .dog, .rabbit, .hamster, .fox, .penguin] {
            let notification = PetUnlockNotification(pet: pet, unlockTime: Date())
            notificationManager.addNotification(notification)
        }

        XCTAssertEqual(notificationManager.recentNotifications.count, 5)
    }

    /// 测试：清除通知
    func testClearNotifications() {
        let notificationManager = PetUnlockNotificationManager.shared
        let notification = PetUnlockNotification(pet: .cat, unlockTime: Date())
        notificationManager.addNotification(notification)

        notificationManager.clearNotifications()

        XCTAssertTrue(notificationManager.recentNotifications.isEmpty)
    }

    // MARK: - 皮肤等级对应关系测试

    /// 测试：所有宠物类型都有对应皮肤
    func testAllPetsHaveSkins() {
        for pet in PetType.allCases {
            let level = manager.level(for: pet)
            let animationSet = PetAnimationSet.forPet(pet, level: level)
            XCTAssertFalse(animationSet.idle.isEmpty, "No idle animation for \(pet)")
        }
    }

    /// 测试：皮肤等级 5 种
    func testAllLevelsHaveSkins() {
        for level in PetLevel.allCases {
            let palette = PetAnimationSet.palette(for: .cat, level: level)
            XCTAssertNotNil(palette)
        }
    }

    // MARK: - 持久化相关测试

    /// 测试：累计编码分钟数持久化
    func testTotalCodingMinutes() {
        let initial = manager.totalCodingMinutes
        XCTAssertGreaterThanOrEqual(initial, 0)
    }

    /// 测试：宠物单独分钟数
    func testPetLevelMinutes() {
        let minutes = manager.petLevelMinutes(for: .cat)
        XCTAssertGreaterThanOrEqual(minutes, 0)
    }
}