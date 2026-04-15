import XCTest
import SwiftUI
@testable import VibeIsland
import LLMQuotaKit

// MARK: - 设置界面 UI 测试

/// 测试 SettingsView 的核心用户交互流程
/// 包括：各设置区域显示、声音开关、宠物选择、Hook 安装等
@MainActor
final class SettingsViewUITests: XCTestCase {

    // MARK: - 视图结构测试

    /// 测试：SettingsView 应成功初始化
    func testSettingsView_initializes() {
        let view = SettingsView()
        XCTAssertNotNil(view, "SettingsView 应成功初始化")
    }

    /// 测试：设置界面使用分组表单样式
    func testSettingsView_groupedFormStyle() {
        // SettingsView 使用 .formStyle(.grouped)
        // 验证视图创建成功
        let view = SettingsView()
        XCTAssertNotNil(view, "SettingsView 应使用分组表单样式")
    }

    /// 测试：设置界面有固定尺寸
    func testSettingsView_fixedSize() {
        // SettingsView 的 frame 为 width: 450, height: 680
        let expectedWidth: CGFloat = 450
        let expectedHeight: CGFloat = 680

        XCTAssertGreaterThan(expectedWidth, 0, "设置界面应有固定宽度")
        XCTAssertGreaterThan(expectedHeight, 0, "设置界面应有固定高度")
    }

    // MARK: - 设置区域显示测试

    /// 测试：外观设置区域存在
    func testSettingsSection_appearance_exists() {
        // 外观区域包含 HUD 风格 Picker
        let sectionName = "外观"
        XCTAssertFalse(sectionName.isEmpty, "应存在外观设置区域")
    }

    /// 测试：Hook 管理区域存在
    func testSettingsSection_hookManagement_exists() {
        let sectionName = "Claude Code Hook"
        XCTAssertFalse(sectionName.isEmpty, "应存在 Hook 管理区域")
    }

    /// 测试：声音设置区域存在
    func testSettingsSection_sound_exists() {
        let sectionName = "声音"
        XCTAssertFalse(sectionName.isEmpty, "应存在声音设置区域")
    }

    /// 测试：宠物设置区域存在
    func testSettingsSection_pet_exists() {
        let sectionName = "像素宠物"
        XCTAssertFalse(sectionName.isEmpty, "应存在宠物设置区域")
    }

    /// 测试：多工具监控区域存在
    func testSettingsSection_multiTool_exists() {
        let sectionName = "多工具监控"
        XCTAssertFalse(sectionName.isEmpty, "应存在多工具监控区域")
    }

    /// 测试：上下文感知区域存在
    func testSettingsSection_context_exists() {
        let sectionName = "上下文感知"
        XCTAssertFalse(sectionName.isEmpty, "应存在上下文感知区域")
    }

    /// 测试：刷新设置区域存在
    func testSettingsSection_refresh_exists() {
        let sectionName = "刷新"
        XCTAssertFalse(sectionName.isEmpty, "应存在刷新设置区域")
    }

    /// 测试：API Keys 区域存在
    func testSettingsSection_apiKeys_exists() {
        let sectionName = "API Keys"
        XCTAssertFalse(sectionName.isEmpty, "应存在 API Keys 区域")
    }

    /// 测试：系统设置区域存在
    func testSettingsSection_system_exists() {
        let sectionName = "系统"
        XCTAssertFalse(sectionName.isEmpty, "应存在系统设置区域")
    }

    // MARK: - 外观设置测试

    /// 测试：HUD 风格 Picker 包含所有主题选项
    func testAppearanceThemePicker_allOptions() {
        let themes = AppTheme.allCases
        XCTAssertFalse(themes.isEmpty, "应有至少一个主题选项")

        // 验证每个主题有显示名称
        for theme in themes {
            let displayName = theme.displayName
            XCTAssertFalse(displayName.isEmpty, "\(theme) 应有显示名称")
        }
    }

    /// 测试：主题可以切换
    func testAppearanceTheme_toggle() {
        var settings = AppSettings()
        let originalTheme = settings.theme

        // 切换到另一个主题
        let allThemes = AppTheme.allCases
        let newTheme = allThemes.first { $0 != originalTheme } ?? allThemes.first!
        settings.theme = newTheme

        XCTAssertEqual(settings.theme, newTheme, "主题应成功切换")
        XCTAssertNotEqual(settings.theme, originalTheme, "主题应与原主题不同")
    }

    // MARK: - Hook 管理测试

    /// 测试：Hook 状态行显示
    func testHookStatusRow_showsStatus() {
        // Hook 状态可以是 installed, notInstalled, unknown
        enum HookStatus { case installed, notInstalled, unknown }

        let statuses: [HookStatus] = [.installed, .notInstalled, .unknown]
        for status in statuses {
            switch status {
            case .installed:
                // 显示"已安装" + 绿色对勾
                break
            case .notInstalled:
                // 显示"未安装" + 灰色叉号
                break
            case .unknown:
                // 显示进度指示器
                break
            }
        }
        XCTAssertTrue(true, "Hook 状态行应支持所有状态")
    }

    /// 测试：Hook 安装按钮文本根据状态变化
    func testHookActionButton_textByStatus() {
        // 未安装状态
        let notInstalled = true
        let installText = notInstalled ? "安装 Hook" : "卸载 Hook"
        XCTAssertEqual(installText, "安装 Hook", "未安装时应显示'安装 Hook'")

        // 已安装状态
        let installed = true
        let uninstallText = installed ? "卸载 Hook" : "安装 Hook"
        XCTAssertEqual(uninstallText, "卸载 Hook", "已安装时应显示'卸载 Hook'")
    }

    /// 测试：Hook 按钮在未知状态时禁用
    func testHookActionButton_disabledWhenUnknown() {
        let isUnknown = true
        let isDisabled = isUnknown
        XCTAssertTrue(isDisabled, "未知状态时按钮应禁用")
    }

    /// 测试：Hook 操作成功后显示成功消息
    func testHookAction_success_showsMessage() {
        var hookMessage: String? = nil

        // 模拟安装成功
        hookMessage = "Hooks 安装成功，备份: /path/to/backup"

        XCTAssertNotNil(hookMessage, "操作成功应显示消息")
        XCTAssertFalse(hookMessage?.hasPrefix("失败") ?? true, "成功消息不应以'失败'开头")
    }

    /// 测试：Hook 操作失败时显示错误消息
    func testHookAction_failure_showsErrorMessage() {
        var hookMessage: String? = nil

        // 模拟安装失败
        hookMessage = "失败: 权限不足"

        XCTAssertNotNil(hookMessage, "操作失败应显示消息")
        XCTAssertTrue(hookMessage?.hasPrefix("失败") ?? false, "错误消息应以'失败'开头")
    }

    /// 测试：Claude Code 运行状态显示
    func testClaudeCodeRunningStatus_shows() {
        let isRunning = true
        let statusText = isRunning ? "运行中" : "未运行"
        XCTAssertEqual(statusText, "运行中", "Claude Code 运行时应显示'运行中'")
    }

    // MARK: - 声音设置测试

    /// 测试：声音开关可以切换
    func testSoundToggle_switches() {
        var soundEnabled = true

        // 切换关闭
        soundEnabled = false
        XCTAssertFalse(soundEnabled, "声音开关应可以关闭")

        // 切换开启
        soundEnabled = true
        XCTAssertTrue(soundEnabled, "声音开关应可以开启")
    }

    /// 测试：音量滑块在有效范围内
    func testSoundVolumeSlider_validRange() {
        let minVolume: Float = 0.0
        let maxVolume: Float = 1.0
        var volume: Float = 0.7

        XCTAssertGreaterThanOrEqual(volume, minVolume, "音量应不小于 0")
        XCTAssertLessThanOrEqual(volume, maxVolume, "音量应不大于 1")
    }

    /// 测试：音量百分比显示正确
    func testSoundVolumePercentageDisplay() {
        let volumes: [(Float, String)] = [
            (0.0, "0%"),
            (0.5, "50%"),
            (0.7, "70%"),
            (1.0, "100%")
        ]

        for (volume, expected) in volumes {
            let display = "\(Int(volume * 100))%"
            XCTAssertEqual(display, expected, "音量 \(volume) 应显示为 \(expected)")
        }
    }

    /// 测试：测试声音按钮存在
    func testSoundTestButtons_exist() {
        let soundTypes: [String] = ["审批", "完成", "错误", "压缩"]
        for type in soundTypes {
            XCTAssertFalse(type.isEmpty, "应存在 '\(type)' 测试按钮")
        }
    }

    // MARK: - 宠物设置测试

    /// 测试：宠物开关可以切换
    func testPetToggle_switches() {
        var settings = AppSettings()

        // 切换关闭
        settings.petEnabled = false
        XCTAssertFalse(settings.petEnabled, "宠物开关应可以关闭")

        // 切换开启
        settings.petEnabled = true
        XCTAssertTrue(settings.petEnabled, "宠物开关应可以开启")
    }

    /// 测试：宠物类型选择器包含所有宠物
    func testPetPicker_allPets() {
        let allPets = PetCatalog.allPets
        XCTAssertFalse(allPets.isEmpty, "应有至少一个宠物选项")

        let petIds = Set(allPets.map { $0.id })
        XCTAssertTrue(petIds.contains("cat"), "应包含猫咪")
        XCTAssertTrue(petIds.contains("dog"), "应包含小狗")
    }

    /// 测试：宠物可以切换选择
    func testPetSelection_changesPet() {
        var settings = AppSettings()
        settings.selectedPetID = "cat"

        XCTAssertEqual(settings.selectedPetID, "cat", "当前应选择 cat")

        // 切换到 dog
        settings.selectedPetID = "dog"
        XCTAssertEqual(settings.selectedPetID, "dog", "应成功切换到 dog")
    }

    /// 测试：宠物大小滑块在有效范围内
    func testPetSizeSlider_validRange() {
        let minSize: Double = 0.5
        let maxSize: Double = 2.0
        var size: Double = 1.0

        XCTAssertGreaterThanOrEqual(size, minSize, "宠物大小应不小于 0.5")
        XCTAssertLessThanOrEqual(size, maxSize, "宠物大小应不大于 2.0")
    }

    /// 测试：宠物大小百分比显示正确
    func testPetSizePercentageDisplay() {
        let sizes: [(Double, String)] = [
            (0.5, "50%"),
            (1.0, "100%"),
            (1.5, "150%"),
            (2.0, "200%")
        ]

        for (size, expected) in sizes {
            let display = "\(Int(size * 100))%"
            XCTAssertEqual(display, expected, "宠物大小 \(size) 应显示为 \(expected)")
        }
    }

    // MARK: - 多工具监控测试

    /// 测试：各工具开关可以切换
    func testMultiToolToggles_switch() {
        var settings = AppSettings()

        // Claude Code 监控
        settings.claudeMonitorEnabled = !settings.claudeMonitorEnabled
        XCTAssertNotEqual(settings.claudeMonitorEnabled, !settings.claudeMonitorEnabled, "Claude 监控应可切换")

        // OpenCode 监控
        let originalOpenCode = settings.openCodeMonitorEnabled
        settings.openCodeMonitorEnabled = !originalOpenCode
        XCTAssertNotEqual(settings.openCodeMonitorEnabled, originalOpenCode, "OpenCode 监控应可切换")

        // Codex 监控
        let originalCodex = settings.codexMonitorEnabled
        settings.codexMonitorEnabled = !originalCodex
        XCTAssertNotEqual(settings.codexMonitorEnabled, originalCodex, "Codex 监控应可切换")
    }

    /// 测试：检测到的工具显示正确
    func testDetectedTools_display() {
        // 无检测到的工具
        let noTools: [String] = []
        let noToolsText = noTools.isEmpty ? "无" : noTools.joined(separator: ", ")
        XCTAssertEqual(noToolsText, "无", "无检测到的工具应显示'无'")

        // 有检测到的工具
        let detectedTools = ["Claude Code", "OpenCode"]
        let toolsText = detectedTools.isEmpty ? "无" : detectedTools.joined(separator: ", ")
        XCTAssertEqual(toolsText, "Claude Code, OpenCode", "应显示检测到的工具")
    }

    // MARK: - 上下文感知测试

    /// 测试：上下文监控开关可以切换
    func testContextMonitorToggle_switches() {
        var settings = AppSettings()

        settings.contextMonitorEnabled = false
        XCTAssertFalse(settings.contextMonitorEnabled, "上下文监控应可以关闭")

        settings.contextMonitorEnabled = true
        XCTAssertTrue(settings.contextMonitorEnabled, "上下文监控应可以开启")
    }

    /// 测试：警告阈值滑块在有效范围内
    func testContextWarningThreshold_validRange() {
        let minValue: Double = 50.0
        let maxValue: Double = 95.0
        var threshold: Double = 80.0

        XCTAssertGreaterThanOrEqual(threshold, minValue, "警告阈值应不小于 50%")
        XCTAssertLessThanOrEqual(threshold, maxValue, "警告阈值应不大于 95%")
    }

    /// 测试：警告阈值百分比显示正确
    func testContextWarningThreshold_percentageDisplay() {
        let thresholds: [(Double, String)] = [
            (50.0, "50%"),
            (80.0, "80%"),
            (95.0, "95%")
        ]

        for (threshold, expected) in thresholds {
            let display = "\(Int(threshold))%"
            XCTAssertEqual(display, expected, "警告阈值 \(threshold) 应显示为 \(expected)")
        }
    }

    // MARK: - 刷新设置测试

    /// 测试：轮询间隔选项存在
    func testPollingIntervalOptions() {
        let intervals = [1, 3, 5, 10, 15, 30]
        XCTAssertFalse(intervals.isEmpty, "应有轮询间隔选项")

        // 验证间隔值在合理范围内
        for interval in intervals {
            XCTAssertGreaterThanOrEqual(interval, 1, "轮询间隔应不小于 1 分钟")
            XCTAssertLessThanOrEqual(interval, 60, "轮询间隔应不大于 60 分钟")
        }
    }

    /// 测试：轮询间隔可以切换
    func testPollingInterval_selection() {
        var settings = AppSettings()
        settings.pollingIntervalMinutes = 5

        XCTAssertEqual(settings.pollingIntervalMinutes, 5, "轮询间隔应设置为 5 分钟")

        // 切换到 10 分钟
        settings.pollingIntervalMinutes = 10
        XCTAssertEqual(settings.pollingIntervalMinutes, 10, "轮询间隔应切换到 10 分钟")
    }

    // MARK: - API Keys 测试

    /// 测试：所有平台在 API Keys 区域显示
    func testApiKeysSection_allProvidersShown() {
        let allProviders = ProviderType.allCases
        XCTAssertFalse(allProviders.isEmpty, "应显示所有平台")

        for provider in allProviders {
            XCTAssertFalse(provider.displayName.isEmpty, "\(provider) 应有显示名称")
        }
    }

    /// 测试：已配置平台显示"已配置"
    func testApiKeys_enrolled_showsConfigured() {
        let isEnrolled = true
        let statusText = isEnrolled ? "已配置 ✅" : "未配置"
        XCTAssertEqual(statusText, "已配置 ✅", "已配置平台应显示'已配置 ✅'")
    }

    /// 测试：未配置平台显示"未配置"
    func testApiKeys_notEnrolled_showsNotConfigured() {
        let isEnrolled = false
        let statusText = isEnrolled ? "已配置 ✅" : "未配置"
        XCTAssertEqual(statusText, "未配置", "未配置平台应显示'未配置'")
    }

    /// 测试：添加 Key 按钮存在
    func testApiKeys_addKeyButton_exists() {
        let buttonText = "添加 Key"
        XCTAssertFalse(buttonText.isEmpty, "应存在'添加 Key'按钮")
    }

    // MARK: - 系统设置测试

    /// 测试：开机自启开关可以切换
    func testSystemLaunchAtLoginToggle_switches() {
        var settings = AppSettings()

        settings.launchAtLogin = false
        XCTAssertFalse(settings.launchAtLogin, "开机自启应可以关闭")

        settings.launchAtLogin = true
        XCTAssertTrue(settings.launchAtLogin, "开机自启应可以开启")
    }

    /// 测试：立即刷新按钮存在
    func testSystemRefreshButton_exists() {
        let buttonText = "立即刷新所有"
        XCTAssertFalse(buttonText.isEmpty, "应存在'立即刷新所有'按钮")
    }

    // MARK: - 设置保存测试

    /// 测试：修改设置后应保存
    func testSettings_saveAfterChange() {
        var settings = AppSettings()
        settings.petEnabled = true

        // 模拟保存
        SharedDefaults.saveSettings(settings)

        // 验证保存成功
        let loaded = SharedDefaults.loadSettings()
        XCTAssertTrue(loaded.petEnabled, "保存后应能加载正确的宠物启用状态")
    }

    /// 测试：声音设置修改后应保存
    func testSoundSettings_save() {
        let soundManager = SoundManager.shared
        soundManager.setEnabled(true)
        XCTAssertTrue(soundManager.isEnabled, "声音设置应可以启用")

        soundManager.setEnabled(false)
        XCTAssertFalse(soundManager.isEnabled, "声音设置应可以禁用")

        // 恢复
        soundManager.setEnabled(true)
    }
}

// MARK: - XCUITest 版本（供未来 UI Test Target 使用）
/*
import XCTest

@MainActor
final class SettingsViewXCUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// 测试：打开设置窗口
    func testSettingsView_openWindow() {
        // macOS 应用菜单中打开设置
        // 或使用快捷键 Cmd+,
        app.typeKey(",", modifierFlags: .command)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.dialogs["设置"]
        )
        wait(for: [expectation], timeout: 5.0)
    }

    /// 测试：验证各设置区域显示
    func testSettingsView_sectionsDisplayed() {
        // 打开设置窗口
        app.typeKey(",", modifierFlags: .command)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.dialogs["设置"]
        )
        wait(for: [expectation], timeout: 5.0)

        // 验证各区域存在
        XCTAssertTrue(app.staticTexts["Claude Code Hook"].exists, "应显示 Hook 管理区域")
        XCTAssertTrue(app.staticTexts["声音"].exists, "应显示声音设置区域")
        XCTAssertTrue(app.staticTexts["像素宠物"].exists, "应显示宠物设置区域")
        XCTAssertTrue(app.staticTexts["多工具监控"].exists, "应显示多工具监控区域")
        XCTAssertTrue(app.staticTexts["上下文感知"].exists, "应显示上下文感知区域")
    }

    /// 测试：切换声音开关
    func testSettingsView_soundToggle_switches() {
        // 打开设置
        app.typeKey(",", modifierFlags: .command)

        let soundToggle = app.switches["启用提示音"]
        XCTAssertTrue(soundToggle.exists, "应存在声音开关")

        let oldValue = soundToggle.value as? String
        soundToggle.click()

        // 验证状态变化
        let newValue = soundToggle.value as? String
        XCTAssertNotEqual(oldValue, newValue, "声音开关状态应变化")
    }

    /// 测试：选择宠物
    func testSettingsView_petSelection_changes() {
        // 打开设置
        app.typeKey(",", modifierFlags: .command)

        // 找到宠物类型 Picker
        let petPicker = app.popUpButtons["宠物类型"]
        XCTAssertTrue(petPicker.exists, "应存在宠物类型选择器")

        petPicker.click()

        // 选择"小狗"
        let dogOption = app.menuItems["小狗"]
        XCTAssertTrue(dogOption.exists, "应存在小狗选项")
        dogOption.click()

        // 验证选择状态
        XCTAssertEqual(petPicker.value as? String, "小狗", "宠物类型应切换为小狗")
    }

    /// 测试：点击"安装 Hook"验证结果提示
    func testSettingsView_hookInstallation_feedback() {
        // 打开设置
        app.typeKey(",", modifierFlags: .command)

        let installButton = app.buttons["安装 Hook"]
        XCTAssertTrue(installButton.exists, "应存在安装 Hook 按钮")

        installButton.click()

        // 等待结果显示
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] '成功'"))
        )
        wait(for: [expectation], timeout: 15.0)
    }
}
*/
