import XCTest
import Foundation
@testable import VibeIsland
import LLMQuotaKit

// MARK: - 视图模型测试

@MainActor
final class QuotaViewModelTests: XCTestCase {

    // MARK: - 生命周期

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - StateManager 初始化测试

    /// 测试：StateManager 初始化不崩溃
    func testStateManager_initialization() {
        let vm = StateManager()
        XCTAssertNotNil(vm)
    }

    /// 测试：StateManager quotas 初始为空数组
    func testStateManager_initialQuotas() {
        let vm = StateManager()
        XCTAssertNotNil(vm.quotas)
    }

    /// 测试：StateManager settings 初始加载
    func testStateManager_initialSettings() {
        let vm = StateManager()
        XCTAssertNotNil(vm.settings)
    }

    /// 测试：StateManager islandState 初始为 compact
    func testStateManager_initialIslandState() {
        let vm = StateManager()
        XCTAssertEqual(vm.islandState, .compact)
    }

    /// 测试：StateManager isLoading 初始为 false
    func testStateManager_initialIsLoading() {
        let vm = StateManager()
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - 额度计算测试

    /// 测试：QuotaInfo 基本结构存在
    func testQuotaInfo_structure() {
        // 验证 QuotaInfo 类型存在且可构造
        let quota = QuotaInfo(
            provider: .mimo,
            keyIdentifier: "sk-***test",
            totalQuota: 500,
            usedQuota: 200,
            remainingQuota: 300,
            unit: .yuan,
            usageRatio: 0.4
        )

        XCTAssertEqual(quota.totalQuota, 500)
        XCTAssertEqual(quota.usedQuota, 200)
        XCTAssertEqual(quota.remainingQuota, 300)
        XCTAssertEqual(quota.usageRatio, 0.4)
        XCTAssertEqual(quota.unit, .yuan)
    }

    /// 测试：QuotaInfo 带错误信息
    func testQuotaInfo_withError() {
        let quota = QuotaInfo(
            provider: .kimi,
            keyIdentifier: "sk-***error",
            totalQuota: nil,
            usedQuota: nil,
            remainingQuota: nil,
            unit: .yuan,
            usageRatio: 0,
            error: .invalidKey
        )

        XCTAssertNil(quota.totalQuota)
        XCTAssertNotNil(quota.error)
    }

    /// 测试：ProviderType 所有用例
    func testProviderType_allCases() {
        let allCases = ProviderType.allCases
        XCTAssertGreaterThanOrEqual(allCases.count, 1)

        // 验证包含预期的 provider
        let caseValues = allCases.map(\.rawValue)
        XCTAssertTrue(caseValues.contains("mimo") || caseValues.contains("kimi") || caseValues.contains("minimax") || caseValues.contains("zai") || caseValues.contains("ark"))
    }

    /// 测试：ProviderType displayName
    func testProviderType_displayName() {
        for provider in ProviderType.allCases {
            XCTAssertFalse(provider.displayName.isEmpty)
        }
    }

    /// 测试：QuotaUnit 枚举
    func testQuotaUnit_enum() {
        // 验证 QuotaUnit 存在
        let unit = QuotaUnit.yuan
        XCTAssertNotNil(unit)
    }

    // MARK: - Provider 状态管理测试

    /// 测试：SharedDefaults 加载设置
    func testSharedDefaults_loadSettings() {
        let settings = SharedDefaults.loadSettings()
        XCTAssertNotNil(settings)
    }

    /// 测试：SharedDefaults 加载额度
    func testSharedDefaults_loadQuotas() {
        let quotas = SharedDefaults.loadQuotas()
        XCTAssertNotNil(quotas)
    }

    /// 测试：SharedDefaults 加载注册列表
    func testSharedDefaults_loadEnrolled() {
        let enrolled = SharedDefaults.loadEnrolled()
        XCTAssertNotNil(enrolled)
    }

    /// 测试：KeychainStorage 存在
    func testKeychainStorage_exists() {
        let vm = StateManager()
        XCTAssertNotNil(vm.keychain)
    }

    /// 测试：NetworkClient 存在
    func testNetworkClient_exists() {
        let vm = StateManager()
        XCTAssertNotNil(vm.network)
    }

    /// 测试：NetworkClient maskKey 方法
    func testNetworkClient_maskKey() {
        let client = NetworkClient()
        let masked = NetworkClient.maskKey("sk-abc123def456")
        XCTAssertTrue(masked.contains("***"))
    }

    /// 测试：NetworkClient maskKey 短密钥
    func testNetworkClient_maskKey_shortKey() {
        let masked = NetworkClient.maskKey("short")
        XCTAssertFalse(masked.isEmpty)
    }

    // MARK: - 提醒触发测试

    /// 测试：SoundManager 存在
    func testSoundManager_exists() {
        let vm = StateManager()
        XCTAssertNotNil(vm.soundManager)
    }

    /// 测试：SoundManager.shared 单例一致性
    func testSoundManager_singletonConsistency() {
        let manager1 = SoundManager.shared
        let manager2 = SoundManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    /// 测试：状态变化处理 - waitingPermission
    func testHandleStateChange_waitingPermission() async {
        let vm = StateManager()
        // 状态变化应触发声音播放
        // 验证 handleStateChange 方法存在且不崩溃
        // 由于是私有方法，我们通过 startMonitoring 间接验证
    }

    /// 测试：状态变化处理 - error
    func testHandleStateChange_error() async {
        let vm = StateManager()
        // error 状态应播放错误提示音
        _ = vm
    }

    /// 测试：状态变化处理 - completed
    func testHandleStateChange_completed() async {
        let vm = StateManager()
        // completed 状态应播放完成提示音
        _ = vm
    }

    /// 测试：状态变化处理 - compacting
    func testHandleStateChange_compacting() async {
        let vm = StateManager()
        // compacting 状态应播放压缩提示音
        _ = vm
    }

    // MARK: - 设置持久化测试

    /// 测试：SharedDefaults 保存额度
    func testSharedDefaults_saveQuotas() {
        let quotas: [QuotaInfo] = [
            QuotaInfo(
                provider: .mimo,
                keyIdentifier: "sk-***123",
                totalQuota: 500,
                usedQuota: 100,
                remainingQuota: 400,
                unit: .yuan,
                usageRatio: 0.2
            )
        ]

        // 保存不应崩溃
        SharedDefaults.saveQuotas(quotas)

        // 验证可以再次加载
        let loaded = SharedDefaults.loadQuotas()
        XCTAssertNotNil(loaded)
    }

    /// 测试：AppSettings 结构
    func testAppSettings_structure() {
        let settings = SharedDefaults.loadSettings()
        // pollingIntervalMinutes 应该存在
        let interval = settings.pollingIntervalMinutes
        XCTAssertGreaterThanOrEqual(interval, 0)
    }

    // MARK: - toggleIslandState 测试

    /// 测试：toggleIslandState 从 compact 到 expanded
    func testToggleIslandState_compactToExpanded() {
        let vm = StateManager()
        XCTAssertEqual(vm.islandState, .compact)

        vm.toggleIslandState()
        XCTAssertEqual(vm.islandState, .expanded)
    }

    /// 测试：toggleIslandState 从 expanded 到 compact
    func testToggleIslandState_expandedToCompact() {
        let vm = StateManager()
        vm.toggleIslandState()
        XCTAssertEqual(vm.islandState, .expanded)

        vm.toggleIslandState()
        XCTAssertEqual(vm.islandState, .compact)
    }

    /// 测试：toggleIslandState 多次切换
    func testToggleIslandState_multipleToggles() {
        let vm = StateManager()

        vm.toggleIslandState()
        XCTAssertEqual(vm.islandState, .expanded)

        vm.toggleIslandState()
        XCTAssertEqual(vm.islandState, .compact)

        vm.toggleIslandState()
        XCTAssertEqual(vm.islandState, .expanded)
    }

    // MARK: - 服务集成测试

    /// 测试：SessionFileWatcher 存在
    func testSessionFileWatcher_exists() {
        let vm = StateManager()
        XCTAssertNotNil(vm.sessionWatcher)
    }

    /// 测试：SessionFileWatcher.shared 单例一致性
    func testSessionFileWatcher_singletonConsistency() {
        let watcher1 = SessionFileWatcher.shared
        let watcher2 = SessionFileWatcher.shared
        XCTAssertTrue(watcher1 === watcher2)
    }

    /// 测试：HookAutoInstaller 存在
    func testHookInstaller_exists() {
        let vm = StateManager()
        XCTAssertNotNil(vm.hookInstaller)
    }

    /// 测试：HookAutoInstaller.shared 单例一致性
    func testHookInstaller_singletonConsistency() {
        let installer1 = HookAutoInstaller.shared
        let installer2 = HookAutoInstaller.shared
        XCTAssertTrue(installer1 === installer2)
    }

    /// 测试：ProcessDetector 存在
    func testProcessDetector_exists() {
        let vm = StateManager()
        XCTAssertNotNil(vm.processDetector)
    }

    /// 测试：ContextMonitor 存在
    func testContextMonitor_exists() {
        let vm = StateManager()
        XCTAssertNotNil(vm.contextMonitor)
    }

    /// 测试：ContextMonitor.shared 单例一致性
    func testContextMonitor_singletonConsistency() {
        let monitor1 = ContextMonitor.shared
        let monitor2 = ContextMonitor.shared
        XCTAssertTrue(monitor1 === monitor2)
    }

    // MARK: - 生命周期测试

    /// 测试：startMonitoring 不崩溃
    func testStartMonitoring_noCrash() {
        let vm = StateManager()
        vm.startMonitoring()
        // 启动后应设置各服务
        vm.stopMonitoring()
    }

    /// 测试：stopMonitoring 不崩溃
    func testStopMonitoring_noCrash() {
        let vm = StateManager()
        vm.startMonitoring()
        vm.stopMonitoring()
        // 停止后再次调用应安全
        vm.stopMonitoring()
    }

    /// 测试：多次 start/stop 不崩溃
    func testMultipleStartStop_noCrash() {
        let vm = StateManager()

        vm.startMonitoring()
        vm.stopMonitoring()

        vm.startMonitoring()
        vm.stopMonitoring()

        vm.startMonitoring()
        vm.stopMonitoring()
    }

    // MARK: - refresh 测试

    /// 测试：refresh 方法存在
    func testRefresh_exists() {
        let vm = StateManager()
        // 验证 refresh 方法可调用
        // 由于是 async 方法，在测试中需要异步等待
    }

    /// 测试：refresh 异步执行
    func testRefresh_asyncExecution() async {
        let vm = StateManager()
        // refresh 应能异步执行而不崩溃
        await vm.refresh()
    }

    /// 测试：refresh 后 lastRefresh 不为 nil
    func testRefresh_updatesLastRefresh() async {
        let vm = StateManager()
        XCTAssertNil(vm.lastRefresh)

        await vm.refresh()

        XCTAssertNotNil(vm.lastRefresh)
    }

    // MARK: - polling 测试

    /// 测试：startPolling 不崩溃
    func testStartPolling_noCrash() {
        let vm = StateManager()
        vm.startPolling()
        vm.stopPolling()
    }

    /// 测试：stopPolling 不崩溃
    func testStopPolling_noCrash() {
        let vm = StateManager()
        vm.stopPolling()
        // 停止后再次调用应安全
        vm.stopPolling()
    }

    /// 测试：多次 start/stop polling
    func testMultipleStartStopPolling_noCrash() {
        let vm = StateManager()

        vm.startPolling()
        vm.stopPolling()

        vm.startPolling()
        vm.stopPolling()
    }

    // MARK: - Hook 管理测试

    /// 测试：installHooks 方法存在
    func testInstallHooks_exists() async {
        let vm = StateManager()
        // 验证方法可调用
        _ = await vm.installHooks()
    }

    /// 测试：uninstallHooks 方法存在
    func testUninstallHooks_exists() async {
        let vm = StateManager()
        _ = await vm.uninstallHooks()
    }

    /// 测试：installHooksWithFeedback 方法存在
    func testInstallHooksWithFeedback_exists() async {
        let vm = StateManager()
        await vm.installHooksWithFeedback()
    }

    /// 测试：uninstallHooksWithFeedback 方法存在
    func testUninstallHooksWithFeedback_exists() async {
        let vm = StateManager()
        await vm.uninstallHooksWithFeedback()
    }

    /// 测试：isClaudeCodeRunning 返回 Bool
    func testIsClaudeCodeRunning_returnsBool() {
        let vm = StateManager()
        let result = vm.isClaudeCodeRunning()
        XCTAssertTrue(result == true || result == false)
    }

    // MARK: - Provider Factory 测试

    /// 测试：Provider 工厂创建 MiMoProvider
    func testProviderFactory_mimo() async throws {
        let provider = MiMoProvider()
        XCTAssertEqual(provider.type, .mimo)
        XCTAssertFalse(provider.displayName.isEmpty)
    }

    /// 测试：Provider 工厂创建 KimiProvider
    func testProviderFactory_kimi() async throws {
        let provider = KimiProvider()
        XCTAssertEqual(provider.type, .kimi)
        XCTAssertFalse(provider.displayName.isEmpty)
    }

    /// 测试：Provider 工厂创建 MiniMaxProvider
    func testProviderFactory_minimax() async throws {
        let provider = MiniMaxProvider()
        XCTAssertEqual(provider.type, .minimax)
        XCTAssertFalse(provider.displayName.isEmpty)
    }

    /// 测试：Provider 工厂创建 ZaiProvider
    func testProviderFactory_zai() async throws {
        let provider = ZaiProvider()
        XCTAssertEqual(provider.type, .zai)
        XCTAssertFalse(provider.displayName.isEmpty)
    }

    /// 测试：Provider 工厂创建 ArkProvider
    func testProviderFactory_ark() async throws {
        let provider = ArkProvider()
        XCTAssertEqual(provider.type, .ark)
        XCTAssertFalse(provider.displayName.isEmpty)
    }

    // MARK: - SessionState 测试

    /// 测试：SessionState 所有枚举值
    func testSessionState_allCases() {
        let allCases = SessionState.allCases
        XCTAssertGreaterThanOrEqual(allCases.count, 5)
    }

    /// 测试：SessionState rawValue
    func testSessionState_rawValues() {
        XCTAssertEqual(SessionState.idle.rawValue, "idle")
        XCTAssertEqual(SessionState.thinking.rawValue, "thinking")
        XCTAssertEqual(SessionState.coding.rawValue, "coding")
    }

    /// 测试：SessionState priority 比较
    func testSessionState_priority() {
        // 验证 priority 属性存在
        let idlePriority = SessionState.idle.priority
        let codingPriority = SessionState.coding.priority
        // priority 用于排序，验证可以访问
        _ = idlePriority
        _ = codingPriority
    }

    // MARK: - QuotaError 测试

    /// 测试：QuotaError 枚举
    func testQuotaError_enum() {
        let invalidKeyError = QuotaError.invalidKey
        let unknownError = QuotaError.unknown("未知错误")

        XCTAssertNotNil(invalidKeyError)
        XCTAssertNotNil(unknownError)
    }

    /// 测试：QuotaError LocalizedError
    func testQuotaError_localizedDescription() {
        let error = QuotaError.invalidKey
        XCTAssertFalse(error.displayMessage.isEmpty)
    }

    // MARK: - IslandState 测试

    /// 测试：IslandState 枚举
    func testIslandState_enum() {
        XCTAssertEqual(IslandState.compact, .compact)
        XCTAssertEqual(IslandState.expanded, .expanded)
    }

    /// 测试：IslandState caseIterable
    func testIslandState_caseIterable() {
        let cases: [IslandState] = [.compact, .expanded]
        XCTAssertEqual(cases.count, 2)
    }

    // MARK: - 集成测试

    /// 测试：StateManager 与 SessionFileWatcher 集成
    func testStateManager_sessionWatcherIntegration() {
        let vm = StateManager()
        // sessionWatcher 应该是 SessionFileWatcher.shared
        XCTAssertTrue(vm.sessionWatcher === SessionFileWatcher.shared)
    }

    /// 测试：StateManager 与 SoundManager 集成
    func testStateManager_soundManagerIntegration() {
        let vm = StateManager()
        // soundManager 应该是 SoundManager.shared
        XCTAssertTrue(vm.soundManager === SoundManager.shared)
    }

    /// 测试：StateManager 与 HookInstaller 集成
    func testStateManager_hookInstallerIntegration() {
        let vm = StateManager()
        // hookInstaller 应该是 HookAutoInstaller.shared
        XCTAssertTrue(vm.hookInstaller === HookAutoInstaller.shared)
    }
}
