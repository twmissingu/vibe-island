import Foundation
import AppKit
import AVFoundation
import OSLog

// MARK: - 声音类型

/// 核心提示音类型
enum SoundType: String, CaseIterable {
    /// 审批请求提示音
    case permissionRequest
    /// 任务完成提示音
    case completed
    /// 错误提示音
    case error
    /// 上下文压缩提示音
    case compacting

    /// 对应的系统声音名称（NSSound 内置声音）
    var systemSoundName: String {
        switch self {
        case .permissionRequest: "Glass"
        case .completed: "Hero"
        case .error: "Basso"
        case .compacting: "Pop"
        }
    }

    /// 自定义声音文件路径（相对于 Resources/Sounds 目录）
    var customSoundFileName: String? {
        switch self {
        case .permissionRequest: "permission_request.aiff"
        case .completed: "completed.aiff"
        case .error: "error.aiff"
        case .compacting: "compacting.aiff"
        }
    }
}

// MARK: - 声音管理器

/// 管理应用内所有提示音的播放
///
/// 功能：
/// - 使用 NSSound 播放 4 种核心提示音
/// - 使用 AVAudioPlayer 播放宠物音效（预留）
/// - 支持声音开关和音量控制
/// - 应用退到后台时声音仍然生效
/// - 支持异步播放
@MainActor
final class SoundManager: Sendable {

    // MARK: - 单例

    static let shared = SoundManager()

    // MARK: - 常量

    /// 默认音量（0.0 - 1.0）
    static let defaultVolume: Float = 0.7

    /// 声音文件目录名称
    private static let soundsDirectoryName = "Sounds"

    // MARK: - 日志

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twissingu.VibeIsland",
        category: "SoundManager"
    )

    // MARK: - 属性

    /// 声音是否启用
    @MainActor private(set) var isEnabled: Bool = true

    /// 音量（0.0 - 1.0）
    @MainActor private(set) var volume: Float = defaultVolume

    /// 已缓存的 NSSound 实例
    private var cachedSounds: [SoundType: NSSound] = [:]

    /// AVAudioPlayer 实例（宠物音效）
    private var audioPlayers: [String: AVAudioPlayer] = [:]

    /// 声音文件目录 URL
    private var soundsDirectoryURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent(Self.soundsDirectoryName)
    }

    // MARK: - 初始化

    private init() {
        loadSettings()
        preloadSystemSounds()
    }

    // MARK: - 公开方法

    /// 播放指定类型的提示音
    /// - Parameter type: 声音类型
    /// - Returns: 是否成功开始播放
    @MainActor
    func play(_ type: SoundType) async -> Bool {
        guard isEnabled else {
            Self.logger.debug("声音已禁用，跳过播放: \(type.rawValue)")
            return false
        }

        // 优先尝试播放自定义声音
        if playCustomSound(type) {
            return true
        }

        // 回退到系统声音
        return await playSystemSound(type)
    }

    /// 启用/禁用声音
    /// - Parameter enabled: 是否启用
    @MainActor
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        saveSettings()
        Self.logger.info("声音\(enabled ? "已启用" : "已禁用")")

        if !enabled {
            stopAll()
        }
    }

    /// 设置音量
    /// - Parameter newVolume: 音量值（0.0 - 1.0）
    @MainActor
    func setVolume(_ newVolume: Float) {
        let clamped = max(0.0, min(1.0, newVolume))
        volume = clamped
        saveSettings()

        // 更新已缓存声音的音量
        for sound in cachedSounds.values {
            sound.volume = clamped
        }

        // 更新正在播放的 AVAudioPlayer 音量
        for player in audioPlayers.values {
            player.volume = clamped
        }

        Self.logger.debug("音量已设置为: \(clamped, format: .fixed(precision: 2))")
    }

    /// 停止指定类型的声音
    /// - Parameter type: 声音类型
    @MainActor
    func stop(_ type: SoundType) {
        if let sound = cachedSounds[type] {
            sound.stop()
        }
    }

    /// 停止所有声音
    @MainActor
    func stopAll() {
        // 停止 NSSound
        for sound in cachedSounds.values {
            sound.stop()
        }

        // 停止 AVAudioPlayer
        for player in audioPlayers.values {
            player.stop()
        }

        Self.logger.debug("已停止所有声音")
    }

    // MARK: - 宠物音效（预留）

    /// 播放宠物音效
    /// - Parameters:
    ///   - name: 音效文件名（不含扩展名）
    ///   - completion: 播放完成回调
    /// - Returns: 是否成功开始播放
    @MainActor
    func playPetSound(named name: String) async -> Bool {
        guard isEnabled else { return false }

        guard let url = soundsDirectoryURL?.appendingPathComponent("\(name).aiff")
                ?? Bundle.main.url(forResource: name, withExtension: "aiff")
        else {
            Self.logger.warning("找不到宠物音效文件: \(name).aiff")
            return false
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            audioPlayers[name] = player
            let success = player.play()

            if !success {
                Self.logger.error("宠物音效播放失败: \(name)")
                return false
            }

            Self.logger.debug("正在播放宠物音效: \(name)")
            return true
        } catch {
            Self.logger.error("加载宠物音效失败: \(name), 错误: \(error.localizedDescription)")
            return false
        }
    }

    /// 停止指定宠物音效
    /// - Parameter name: 音效名
    @MainActor
    func stopPetSound(named name: String) {
        audioPlayers[name]?.stop()
        audioPlayers.removeValue(forKey: name)
    }

    // MARK: - 设置管理

    /// 从 UserDefaults 加载声音设置
    @MainActor
    private func loadSettings() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: "SoundManager.isEnabled") as? Bool ?? true
        volume = defaults.object(forKey: "SoundManager.volume") as? Float ?? Self.defaultVolume
    }

    /// 保存声音设置到 UserDefaults
    @MainActor
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "SoundManager.isEnabled")
        defaults.set(volume, forKey: "SoundManager.volume")
    }

    // MARK: - 系统声音

    /// 预加载系统声音
    @MainActor
    private func preloadSystemSounds() {
        for type in SoundType.allCases {
            _ = loadSystemSound(type)
        }
        Self.logger.debug("已预加载 \(self.cachedSounds.count) 个系统声音")
    }

    /// 加载系统声音
    @MainActor
    private func loadSystemSound(_ type: SoundType) -> NSSound? {
        if let cached = cachedSounds[type] {
            return cached
        }

        guard let sound = NSSound(named: type.systemSoundName) else {
            Self.logger.warning("无法加载系统声音: \(type.systemSoundName)")
            return nil
        }

        sound.volume = volume
        cachedSounds[type] = sound
        return sound
    }

    /// 播放系统声音
    @MainActor
    private func playSystemSound(_ type: SoundType) async -> Bool {
        guard let sound = loadSystemSound(type) else {
            Self.logger.error("声音不可用: \(type.rawValue)")
            return false
        }

        sound.stop()
        let success = sound.play()

        if !success {
            Self.logger.error("系统声音播放失败: \(type.systemSoundName)")
        } else {
            Self.logger.debug("正在播放系统声音: \(type.systemSoundName)")
        }

        return success
    }

    // MARK: - 自定义声音

    /// 播放自定义声音文件
    /// - Parameter type: 声音类型
    /// - Returns: 是否成功播放
    @MainActor
    private func playCustomSound(_ type: SoundType) -> Bool {
        guard let fileName = type.customSoundFileName else {
            return false
        }

        guard let url = soundsDirectoryURL?.appendingPathComponent(fileName) else {
            return false
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            let success = player.play()

            if success {
                Self.logger.debug("正在播放自定义声音: \(fileName)")
            } else {
                Self.logger.error("自定义声音播放失败: \(fileName)")
            }

            return success
        } catch {
            Self.logger.warning("加载自定义声音失败: \(fileName), 错误: \(error.localizedDescription)")
            return false
        }
    }
}
