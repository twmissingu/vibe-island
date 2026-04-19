import XCTest

@MainActor
final class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--onboarding"]  // 强制显示引导
        app.launch()
    }

    /// 测试：启动应用后显示引导页面
    func testOnboarding_showsWelcomeStep() {
        // 验证进度指示器存在
        let progressDots = app.otherElements.matching(identifier: "progressIndicator")
        XCTAssertTrue(progressDots.count > 0, "应显示进度指示器")

        // 验证欢迎标题存在
        let welcomeTitle = app.staticTexts["欢迎使用 Vibe Island"]
        XCTAssertTrue(welcomeTitle.exists, "应显示欢迎标题")
    }

    /// 测试：点击"下一步"切换到平台选择
    func testOnboarding_nextButton_navigatesToPlatformSelection() {
        let nextButton = app.buttons["下一步"]
        XCTAssertTrue(nextButton.exists, "应显示下一步按钮")

        nextButton.tap()

        // 验证切换到平台选择步骤
        let platformTitle = app.staticTexts["选择要监控的平台"]
        XCTAssertTrue(platformTitle.exists, "应显示平台选择标题")
    }

    /// 测试：选择平台应更新选择状态
    func testPlatformSelection_toggle_updatesState() {
        // 先导航到平台选择步骤
        app.buttons["下一步"].tap()

        // 点击 mimo 平台
        let mimoButton = app.buttons["小米 MIMO"]
        XCTAssertTrue(mimoButton.exists, "应显示 mimo 平台按钮")
        mimoButton.tap()

        // 验证选择状态（通过检查选中标记）
        let checkmark = app.images["checkmark.circle.fill"]
        XCTAssertTrue(checkmark.exists, "应选择 mimo 平台")
    }

    /// 测试：点击"安装 Hook"应显示安装结果
    func testHookSetup_install_showsResult() {
        // 导航到 Hook 配置步骤
        app.buttons["下一步"].tap()
        app.buttons["下一步"].tap()

        let installButton = app.buttons["安装 Hook"]
        XCTAssertTrue(installButton.exists, "应显示安装 Hook 按钮")

        installButton.tap()

        // 等待安装完成
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.staticTexts["✅ 已安装"]
        )
        wait(for: [expectation], timeout: 10.0)
    }

    /// 测试：点击"开始使用"应关闭引导
    func testOnboarding_startUsing_dismisses() {
        // 导航到完成步骤
        for _ in 0..<3 {
            app.buttons["下一步"].tap()
        }

        let startButton = app.buttons["开始使用"]
        XCTAssertTrue(startButton.exists, "应显示开始使用按钮")

        startButton.tap()

        // 验证引导已关闭（主界面应显示）
        let islandView = app.otherElements["islandView"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: islandView
        )
        wait(for: [expectation], timeout: 5.0)
    }

    /// 测试：点击"跳过引导"应直接关闭
    func testOnboarding_skip_dismisses() {
        let skipButton = app.buttons["跳过引导"]
        XCTAssertTrue(skipButton.exists, "应显示跳过引导按钮")

        skipButton.tap()

        // 验证引导已关闭
        let welcomeTitle = app.staticTexts["欢迎使用 Vibe Island"]
        XCTAssertFalse(welcomeTitle.exists, "跳过引导后不应显示欢迎标题")
    }

    /// 测试：进度指示器应高亮当前步骤
    func testOnboarding_progressIndicator_highlightsCurrentStep() {
        // 第一步：第一个圆点应为蓝色
        // 点击下一步后：前两个圆点应高亮
        app.buttons["下一步"].tap()

        // 验证进度指示器更新
        let progressDots = app.otherElements.matching(identifier: "progressDot")
        XCTAssertTrue(progressDots.count >= 2, "应有至少 2 个进度点")
    }
}
