import Foundation
import OSLog
import SwiftUI

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

// MARK: - 宠物进度管理

/// 管理宠物解锁进度和已解锁状态
@MainActor
@Observable
final class PetProgressManager {
    static let shared = PetProgressManager()
    
    /// 累计 vibe coding 时长（分钟）
    private(set) var totalCodingMinutes: Int = 0
    
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
    
    /// 宠物是否启用
    var isEnabled: Bool = true {
        didSet { saveEnabled() }
    }
    
    // MARK: 私有方法
    
    private init() {
        loadProgress()
    }
    
    /// 添加编码时长（分钟）
    func addCodingMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        let oldTotal = totalCodingMinutes
        totalCodingMinutes += minutes
        saveProgress()
        
        // 检查是否有新宠物解锁
        checkNewUnlocks(oldTotal: oldTotal)
    }
    
    /// 检查是否有新宠物解锁
    private func checkNewUnlocks(oldTotal: Int) {
        for pet in PetType.allCases {
            if !pet.isUnlocked(totalCodingMinutes: oldTotal) &&
               pet.isUnlocked(totalCodingMinutes: totalCodingMinutes) {
                Self.logger.info("🎉 新宠物解锁: \(pet.displayName)")
                // 可以触发通知/动画
            }
        }
    }
    
    // MARK: 持久化
    
    private let defaults = UserDefaults.standard
    private let minutesKey = "vibe-island.coding-minutes"
    private let selectedKey = "vibe-island.selected-pet"
    private let enabledKey = "vibe-island.pet-enabled"
    
    private func loadProgress() {
        totalCodingMinutes = defaults.integer(forKey: minutesKey)
        if let raw = defaults.string(forKey: selectedKey),
           let pet = PetType(rawValue: raw),
           pet.isUnlocked(totalCodingMinutes: totalCodingMinutes) {
            selectedPet = pet
        }
        isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
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
    
    /// 重置进度（测试用）
    func resetProgress() {
        totalCodingMinutes = 0
        selectedPet = .cat
        defaults.removeObject(forKey: minutesKey)
        defaults.removeObject(forKey: selectedKey)
    }
}

// MARK: - Logger

extension PetProgressManager {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "PetProgress"
    )
}
