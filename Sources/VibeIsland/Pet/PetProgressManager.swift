import Foundation
import OSLog
import SwiftUI

// MARK: - 宠物解锁通知

/// 宠物解锁通知
struct PetUnlockNotification: Equatable, Sendable {
    /// 解锁的宠物
    let pet: PetType
    /// 解锁时间
    let unlockTime: Date
    /// 通知ID（用于去重）
    let id: UUID = UUID()
}

/// 宠物解锁通知管理器
@MainActor
final class PetUnlockNotificationManager {
    static let shared = PetUnlockNotificationManager()

    /// 最近的通知（保留最近5条）
    private(set) var recentNotifications: [PetUnlockNotification] = []

    /// 新通知回调
    var onNewNotification: ((PetUnlockNotification) -> Void)?

    private init() {}

    /// 添加新通知
    func addNotification(_ notification: PetUnlockNotification) {
        recentNotifications.insert(notification, at: 0)
        // 保留最近5条
        if recentNotifications.count > 5 {
            recentNotifications.removeLast()
        }
        onNewNotification?(notification)
    }

    /// 清除所有通知
    func clearNotifications() {
        recentNotifications.removeAll()
    }
}

// MARK: - 宠物等级系统

/// 宠物等级（1-5）
enum PetLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case basic = 1    // 基础款 - 默认
    case glow = 2     // 辉光款 - 60 分钟
    case metal = 3    // 金属款 - 120 分钟
    case neon = 4     // 霓虹款 - 240 分钟
    case king = 5     // 王者款 - 360 分钟

    static func < (lhs: PetLevel, rhs: PetLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .basic: return "基础款"
        case .glow: return "辉光款"
        case .metal: return "金属款"
        case .neon: return "霓虹款"
        case .king: return "王者款"
        }
    }

    /// 达到该等级所需的累计编码时长（分钟，从该宠物被选中开始）
    var requiredMinutes: Int {
        switch self {
        case .basic: return 0
        case .glow: return 60
        case .metal: return 120
        case .neon: return 240
        case .king: return 360
        }
    }

    /// 从累计时长计算等级
    static func from(minutes: Int) -> PetLevel {
        if minutes >= PetLevel.king.requiredMinutes { return .king }
        if minutes >= PetLevel.neon.requiredMinutes { return .neon }
        if minutes >= PetLevel.metal.requiredMinutes { return .metal }
        if minutes >= PetLevel.glow.requiredMinutes { return .glow }
        return .basic
    }

    /// 下一个等级（最高级返回 nil）
    var next: PetLevel? {
        switch self {
        case .basic: return .glow
        case .glow: return .metal
        case .metal: return .neon
        case .neon: return .king
        case .king: return nil
        }
    }
}

// MARK: - 宠物解锁动画效果

/// 宠物解锁时的动画效果管理器
@MainActor
final class PetUnlockAnimationManager {
    static let shared = PetUnlockAnimationManager()

    /// 当前播放的动画
    @MainActor @Observable
    class var currentAnimation: AnimationState? {
        didSet {
            guard let animation = currentAnimation else { return }
            // 自动在3秒后清除动画
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if PetUnlockAnimationManager.shared.currentAnimation?.id == animation.id {
                    PetUnlockAnimationManager.shared.currentAnimation = nil
                }
            }
        }
    }

    /// 动画状态
    enum AnimationState: Equatable {
        case unlock(pet: PetType)

        var pet: PetType? {
            switch self {
            case .unlock(let pet): return pet
            }
        }
    }

    /// 播放解锁动画
    func playUnlockAnimation(pet: PetType) {
        currentAnimation = .unlock(pet: pet)
    }
}

// MARK: - 宠物获取前提（XP 解锁系统）

/// 宠物解锁条件
/// 每款宠物需要通过累计 vibe coding 时长来解锁
struct PetUnlockRequirement: Codable, Equatable, Sendable {
    /// 需要的 vibe coding 时长（分钟）
    let requiredMinutes: Int
    /// 是否已解锁
    var isUnlocked: Bool {
        false  // 由外部计算决定
    }
    
    /// 显示用的解锁进度文本
    func progressText(currentMinutes: Int) -> String {
        guard currentMinutes < requiredMinutes else { return "✅ 已解锁" }
        let remaining = requiredMinutes - currentMinutes
        return "还需 \(remaining) 分钟"
    }
}

// MARK: - 宠物类型

enum PetType: String, Codable, CaseIterable, Sendable {
    case cat       // 猫咪（初始可用）
    case dog       // 小狗
    case rabbit    // 兔子
    case fox       // 狐狸
    case penguin   // 企鹅
    case robot     // 机器人
    case ghost     // 幽灵
    case dragon    // 小龙
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .cat: return "猫咪"
        case .dog: return "小狗"
        case .rabbit: return "兔子"
        case .fox: return "狐狸"
        case .penguin: return "企鹅"
        case .robot: return "机器人"
        case .ghost: return "幽灵"
        case .dragon: return "小龙"
        }
    }
    
    /// 解锁所需的 vibe coding 时长（分钟）
    var unlockRequirement: PetUnlockRequirement {
        switch self {
        case .cat: return PetUnlockRequirement(requiredMinutes: 0)       // 初始可用
        case .dog: return PetUnlockRequirement(requiredMinutes: 30)     // 30 分钟
        case .rabbit: return PetUnlockRequirement(requiredMinutes: 60)  // 1 小时
        case .fox: return PetUnlockRequirement(requiredMinutes: 120)    // 2 小时
        case .penguin: return PetUnlockRequirement(requiredMinutes: 240) // 4 小时
        case .robot: return PetUnlockRequirement(requiredMinutes: 480)   // 8 小时
        case .ghost: return PetUnlockRequirement(requiredMinutes: 960)   // 16 小时
        case .dragon: return PetUnlockRequirement(requiredMinutes: 1920) // 32 小时
        }
    }
    
    /// 是否已解锁（基于累计时长）
    func isUnlocked(totalCodingMinutes: Int) -> Bool {
        totalCodingMinutes >= unlockRequirement.requiredMinutes
    }
}

// MARK: - 编码目标

/// 编码目标类型
enum CodingGoalType: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
}

/// 编码目标
struct CodingGoal: Codable, Equatable {
    /// 目标类型
    let type: CodingGoalType
    /// 目标时长（分钟）
    let targetMinutes: Int
    /// 当前进度（分钟）
    let currentMinutes: Int
    /// 是否达成
    let isAchieved: Bool
    /// 上次达成时间
    let lastAchievedDate: Date?
}

// MARK: - 宠物进度管理

/// 管理宠物解锁进度和已解锁状态
@MainActor
@Observable
final class PetProgressManager {
    static let shared = PetProgressManager()

    /// 累计 vibe coding 时长（分钟）
    private(set) var totalCodingMinutes: Int = 0

    /// 每只宠物被选中时的累计编码时长（分钟）
    private(set) var petLevelMinutes: [String: Int] = [:]

    /// 已解锁的宠物列表
    var unlockedPets: Set<PetType> {
        Set(PetType.allCases.filter { pet in pet.isUnlocked(totalCodingMinutes: totalCodingMinutes) })
    }

    /// 当前选中的宠物
    var selectedPet: PetType = .cat {
        didSet {
            // 确保选中的宠物已解锁
            guard selectedPet.isUnlocked(totalCodingMinutes: totalCodingMinutes) else {
                selectedPet = PetType.cat
                return
            }
            saveSelectedPet()
        }
    }

    /// 获取指定宠物的当前等级
    func level(for pet: PetType) -> PetLevel {
        let minutes = petLevelMinutes[pet.rawValue] ?? 0
        return PetLevel.from(minutes: minutes)
    }

    /// 获取当前选中宠物的等级
    var currentLevel: PetLevel {
        level(for: selectedPet)
    }

    /// 获取指定宠物在当前等级的进度（0.0-1.0）
    func levelProgress(for pet: PetType) -> Double {
        let minutes = petLevelMinutes[pet.rawValue] ?? 0
        let currentLevel = PetLevel.from(minutes: minutes)
        guard let nextLevel = currentLevel.next else { return 1.0 }
        let levelStart = currentLevel.requiredMinutes
        let levelEnd = nextLevel.requiredMinutes
        let progress = Double(minutes - levelStart) / Double(levelEnd - levelStart)
        return min(1.0, max(0.0, progress))
    }

    /// 获取指定宠物升级所需的剩余分钟数
    func minutesToNextLevel(for pet: PetType) -> Int? {
        let minutes = petLevelMinutes[pet.rawValue] ?? 0
        let currentLevel = PetLevel.from(minutes: minutes)
        guard let nextLevel = currentLevel.next else { return nil }
        return nextLevel.requiredMinutes - minutes
    }

    /// 宠物是否启用
    var isEnabled: Bool = true {
        didSet { saveEnabled() }
    }

    // MARK: - 编码目标属性

    /// 每日编码目标（分钟）
    var dailyGoal: Int = 30 {
        didSet { saveDailyGoal() }
    }

    /// 今日已编码时长（分钟，用于目标进度）
    var todayCodingMinutes: Int = 0 {
        didSet { checkDailyGoalAchievement() }
    }

    /// 每周编码目标（分钟）
    var weeklyGoal: Int = 180 {  // 3小时/周
        didSet { saveWeeklyGoal() }
    }

    /// 本周已编码时长（分钟，用于目标进度）
    var weekCodingMinutes: Int = 0 {
        didSet { checkWeeklyGoalAchievement() }
    }

    /// 上次达成每日目标的日期
    var lastDailyGoalDate: Date? {
        didSet { saveLastDailyGoalDate() }
    }

    /// 上次达成每周目标的日期
    var lastWeeklyGoalDate: Date? {
        didSet { saveLastWeeklyGoalDate() }
    }

    // MARK: 私有方法

    private init() {
        loadProgress()
        loadGoalSettings()
    }

    /// 添加编码时长（分钟）
    func addCodingMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        let oldTotal = totalCodingMinutes
        totalCodingMinutes += minutes
        saveProgress()

        // 更新今日和本周时长
        todayCodingMinutes += minutes
        weekCodingMinutes += minutes

        // 更新当前选中宠物的累计时长
        let petKey = selectedPet.rawValue
        let oldPetMinutes = petLevelMinutes[petKey] ?? 0
        let oldLevel = PetLevel.from(minutes: oldPetMinutes)
        petLevelMinutes[petKey] = oldPetMinutes + minutes
        let newLevel = PetLevel.from(minutes: petLevelMinutes[petKey] ?? 0)
        savePetLevelMinutes()

        // 检查是否有新宠物解锁
        checkNewUnlocks(oldTotal: oldTotal)

        // 检查当前宠物是否升级
        if newLevel > oldLevel {
            checkPetLevelUp(pet: selectedPet, oldLevel: oldLevel, newLevel: newLevel)
        }
    }

    /// 检查每日目标是否达成
    private func checkDailyGoalAchievement() {
        guard todayCodingMinutes >= dailyGoal,
              !isGoalAchievedToday(type: .daily) else { return }

        lastDailyGoalDate = Date()
        Self.logger.info("🎉 每日目标达成: \(dailyGoal) 分钟")

        // 触发庆祝动画
        Self.triggerCelebrationForGoal(type: .daily)
    }

    /// 检查每周目标是否达成
    private func checkWeeklyGoalAchievement() {
        guard weekCodingMinutes >= weeklyGoal,
              !isGoalAchievedThisWeek(type: .weekly) else { return }

        lastWeeklyGoalDate = Date()
        Self.logger.info("🎉 每周目标达成: \(weeklyGoal) 分钟")

        // 触发庆祝动画
        Self.triggerCelebrationForGoal(type: .weekly)
    }

    /// 检查今天是否已达成某类型目标
    private func isGoalAchievedToday(type: CodingGoalType) -> Bool {
        guard let date = lastDailyGoalDate else { return false }
        let calendar = Calendar.current
        return calendar.isDate(date, inSameDayAs: Date())
    }

    /// 检查本周是否已达成某类型目标
    private func isGoalAchievedThisWeek(type: CodingGoalType) -> Bool {
        guard let date = lastWeeklyGoalDate else { return false }
        let calendar = Calendar.current
        let thisWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let goalWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return thisWeek.yearForWeekOfYear == goalWeek.yearForWeekOfYear && thisWeek.weekOfYear == goalWeek.weekOfYear
    }

    /// 触发目标达成庆祝
    private static func triggerCelebrationForGoal(type: CodingGoalType) {
        // 触发宠物庆祝动画
        PetUnlockAnimationManager.shared.playUnlockAnimation(pet: .cat)
    }
    
    /// 检查是否有新宠物解锁
    private func checkNewUnlocks(oldTotal: Int) {
        for pet in PetType.allCases {
            if !pet.isUnlocked(totalCodingMinutes: oldTotal) &&
               pet.isUnlocked(totalCodingMinutes: totalCodingMinutes) {
                Self.logger.info("🎉 新宠物解锁: \(pet.displayName)")

                // 发送解锁通知
                let notification = PetUnlockNotification(pet: pet, unlockTime: Date())
                PetUnlockNotificationManager.shared.addNotification(notification)

                // 触发视觉反馈（粒子效果）
                Self.triggerUnlockEffect(pet: pet)
            }
        }
    }

    /// 触发解锁视觉效果
    private static func triggerUnlockEffect(pet: PetType) {
        // 触发动画效果
        PetUnlockAnimationManager.shared.playUnlockAnimation(pet: pet)
        Self.logger.info("✨ 解锁特效已触发: \(pet.displayName)")
    }

    /// 检查宠物升级
    private func checkPetLevelUp(pet: PetType, oldLevel: PetLevel, newLevel: PetLevel) {
        Self.logger.info("🎉 宠物升级: \(pet.displayName) \(oldLevel.displayName) → \(newLevel.displayName)")

        // 发送解锁通知（复用通知系统）
        let notification = PetUnlockNotification(pet: pet, unlockTime: Date())
        PetUnlockNotificationManager.shared.addNotification(notification)

        // 触发庆祝动画
        PetUnlockAnimationManager.shared.playUnlockAnimation(pet: pet)
    }
    
    // MARK: 持久化
    
    private let defaults = UserDefaults.standard
    private let minutesKey = "vibe-island.coding-minutes"
    private let selectedKey = "vibe-island.selected-pet"
    private let enabledKey = "vibe-island.pet-enabled"
    private let petLevelMinutesKey = "vibe-island.pet-level-minutes"
    
    private func loadProgress() {
        totalCodingMinutes = defaults.integer(forKey: minutesKey)
        if let raw = defaults.string(forKey: selectedKey),
           let pet = PetType(rawValue: raw),
           pet.isUnlocked(totalCodingMinutes: totalCodingMinutes) {
            selectedPet = pet
        }
        isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        // 加载宠物等级分钟数
        if let saved = defaults.dictionary(forKey: petLevelMinutesKey) as? [String: Int] {
            petLevelMinutes = saved
        }
    }
    
    private func saveProgress() {
        defaults.set(totalCodingMinutes, forKey: minutesKey)
    }
    
    private func saveSelectedPet() {
        defaults.set(selectedPet.rawValue, forKey: selectedKey)
    }
    
    private func saveEnabled() {
        defaults.set(isEnabled, forKey: enabledKey)
    }

    private func savePetLevelMinutes() {
        defaults.set(petLevelMinutes, forKey: petLevelMinutesKey)
    }

    // MARK: - 目标设置持久化

    private let dailyGoalKey = "vibe-island.daily-goal"
    private let weeklyGoalKey = "vibe-island.weekly-goal"
    private let lastDailyGoalDateKey = "vibe-island.last-daily-goal-date"
    private let lastWeeklyGoalDateKey = "vibe-island.last-weekly-goal-date"

    private func loadGoalSettings() {
        dailyGoal = defaults.integer(forKey: dailyGoalKey) ?? 30
        weeklyGoal = defaults.integer(forKey: weeklyGoalKey) ?? 180
        if let date = defaults.object(forKey: lastDailyGoalDateKey) as? Date {
            lastDailyGoalDate = date
        }
        if let date = defaults.object(forKey: lastWeeklyGoalDateKey) as? Date {
            lastWeeklyGoalDate = date
        }
    }

    private func saveDailyGoal() {
        defaults.set(dailyGoal, forKey: dailyGoalKey)
    }

    private func saveWeeklyGoal() {
        defaults.set(weeklyGoal, forKey: weeklyGoalKey)
    }

    private func saveLastDailyGoalDate() {
        defaults.set(lastDailyGoalDate, forKey: lastDailyGoalDateKey)
    }

    private func saveLastWeeklyGoalDate() {
        defaults.set(lastWeeklyGoalDate, forKey: lastWeeklyGoalDateKey)
    }

    /// 重置进度（测试用）
    func resetProgress() {
        totalCodingMinutes = 0
        todayCodingMinutes = 0
        weekCodingMinutes = 0
        petLevelMinutes.removeAll()
        selectedPet = .cat
        defaults.removeObject(forKey: minutesKey)
        defaults.removeObject(forKey: selectedKey)
        defaults.removeObject(forKey: dailyGoalKey)
        defaults.removeObject(forKey: weeklyGoalKey)
        defaults.removeObject(forKey: lastDailyGoalDateKey)
        defaults.removeObject(forKey: lastWeeklyGoalDateKey)
        defaults.removeObject(forKey: petLevelMinutesKey)
    }

    /// 重置目标进度（保留设置）
    func resetGoalProgress() {
        todayCodingMinutes = 0
        weekCodingMinutes = 0
        // 不重置 lastGoalDate，避免重复触发
    }
}

// MARK: - Logger

extension PetProgressManager {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "PetProgress"
    )
}
