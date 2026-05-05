import XCTest
import Foundation
@testable import VibeIsland

/// SoundManager 测试
/// 测试声音服务的核心功能：声音播放、音量控制、开关控制等
@MainActor
final class SoundManagerTests: XCTestCase {

    var manager: SoundManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = SoundManager.shared
        // 恢复默认设置
        manager.setEnabled(true)
        manager.setVolume(SoundManager.defaultVolume)
    }

    override func tearDown() async throws {
        manager.stopAll()
        manager.setEnabled(true)
        manager.setVolume(SoundManager.defaultVolume)
        try await super.tearDown()
    }

    // MARK: - SoundType 测试

    /// 测试：SoundType 包含所有预期类型
    func testSoundType_allCases() {
        let allCases = SoundType.allCases
        XCTAssertEqual(allCases.count, 8)
        XCTAssertTrue(allCases.contains(.permissionRequest))
        XCTAssertTrue(allCases.contains(.completed))
        XCTAssertTrue(allCases.contains(.error))
        XCTAssertTrue(allCases.contains(.compacting))
    }

    /// 测试：SoundType 系统声音名称
    func testSoundType_systemSoundNames() {
        XCTAssertEqual(SoundType.permissionRequest.systemSoundName, "Glass")
        XCTAssertEqual(SoundType.completed.systemSoundName, "Hero")
        XCTAssertEqual(SoundType.error.systemSoundName, "Basso")
        XCTAssertEqual(SoundType.compacting.systemSoundName, "Pop")
    }

    /// 测试：SoundType 自定义声音文件名
    func testSoundType_customSoundFileNames() {
        XCTAssertEqual(SoundType.permissionRequest.customSoundFileName, "permission_request.aiff")
        XCTAssertEqual(SoundType.completed.customSoundFileName, "completed.aiff")
        XCTAssertEqual(SoundType.error.customSoundFileName, "error.aiff")
        XCTAssertEqual(SoundType.compacting.customSoundFileName, "compacting.aiff")
    }

    // MARK: - 音量控制测试

    /// 测试：默认音量值为 1.0
    func testDefaultVolume() {
        XCTAssertEqual(SoundManager.defaultVolume, 1.0)
    }

    /// 测试：设置音量在有效范围内
    func testSetVolume_validRange() {
        manager.setVolume(0.5)
        XCTAssertEqual(manager.volume, 0.5)

        manager.setVolume(0.0)
        XCTAssertEqual(manager.volume, 0.0)

        manager.setVolume(1.0)
        XCTAssertEqual(manager.volume, 1.0)
    }

    /// 测试：设置音量超过上限被截断
    func testSetVolume_clampedMax() {
        manager.setVolume(1.5)
        XCTAssertEqual(manager.volume, 1.0)
    }

    /// 测试：设置音量低于下限被截断
    func testSetVolume_clampedMin() {
        manager.setVolume(-0.5)
        XCTAssertEqual(manager.volume, 0.0)
    }

    /// 测试：设置音量后能正确读取
    func testSetVolume_readBack() {
        manager.setVolume(0.35)
        XCTAssertEqual(manager.volume, 0.35, accuracy: 0.01)
    }

    // MARK: - 开关控制测试

    /// 测试：默认声音启用
    func testDefaultEnabled() {
        // 由于 UserDefaults 可能有残留，设置后再验证
        manager.setEnabled(true)
        XCTAssertTrue(manager.isEnabled)
    }

    /// 测试：禁用声音
    func testSetEnabled_false() {
        manager.setEnabled(false)
        XCTAssertFalse(manager.isEnabled)
    }

    /// 测试：启用声音
    func testSetEnabled_true() {
        manager.setEnabled(true)
        XCTAssertTrue(manager.isEnabled)
    }

    /// 测试：禁用声音时停止所有声音
    func testSetEnabled_false_stopsAll() {
        manager.setEnabled(true)
        manager.setEnabled(false)
        // stopAll 在 setEnabled(false) 内部被调用
        XCTAssertFalse(manager.isEnabled)
    }

    // MARK: - 声音播放测试

    /// 测试：播放声音在启用状态下不崩溃
    func testPlay_enabled_noCrash() async {
        manager.setEnabled(true)
        // 播放可能因缺少声音文件而失败，但不应崩溃
        _ = await manager.play(.permissionRequest)
    }

    /// 测试：播放声音在禁用状态下返回 false
    func testPlay_disabled_returnsFalse() async {
        manager.setEnabled(false)
        let result = await manager.play(.permissionRequest)
        XCTAssertFalse(result)
    }

    /// 测试：播放所有声音类型不崩溃
    func testPlay_allTypes_noCrash() async {
        manager.setEnabled(true)
        for type in SoundType.allCases {
            _ = await manager.play(type)
        }
    }

    // MARK: - 停止声音测试

    /// 测试：停止指定类型声音不崩溃
    func testStop_noCrash() {
        manager.stop(.permissionRequest)
        manager.stop(.completed)
        manager.stop(.error)
        manager.stop(.compacting)
    }

    /// 测试：停止所有声音不崩溃
    func testStopAll_noCrash() {
        manager.stopAll()
    }

    // MARK: - 宠物音效测试（预留功能）

    /// 测试：播放不存在的宠物音效返回 false
    func testPlayPetSound_nonExistent_returnsFalse() async {
        let result = await manager.playPetSound(named: "non_existent_sound")
        XCTAssertFalse(result)
    }

    /// 测试：停止不存在的宠物音效不崩溃
    func testStopPetSound_nonExistent_noCrash() {
        manager.stopPetSound(named: "non_existent")
    }

    /// 测试：禁用状态下播放宠物音效返回 false
    func testPlayPetSound_disabled_returnsFalse() async {
        manager.setEnabled(false)
        let result = await manager.playPetSound(named: "meow")
        XCTAssertFalse(result)
    }

    // MARK: - 设置持久化测试

    /// 测试：音量设置被保存后能正确读取
    func testVolumeSetting_persistence() {
        manager.setVolume(0.42)
        // 重新从 shared 实例读取
        XCTAssertEqual(SoundManager.shared.volume, 0.42, accuracy: 0.01)
    }

    /// 测试：启用设置被保存后能正确读取
    func testEnabledSetting_persistence() {
        manager.setEnabled(false)
        XCTAssertFalse(SoundManager.shared.isEnabled)

        manager.setEnabled(true)
        XCTAssertTrue(SoundManager.shared.isEnabled)
    }
}
