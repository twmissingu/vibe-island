import XCTest

@MainActor
final class SettingsViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]  // 跳过引导直接进入主界面
        app.launch()
    }

    /// 测试：打开设置窗口
    func testSettingsView_openWindow() {
        // 使用快捷键 Cmd+, 打开设置
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
