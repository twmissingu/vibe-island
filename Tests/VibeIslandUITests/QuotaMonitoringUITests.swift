import XCTest

@MainActor
final class QuotaMonitoringUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]  // 跳过引导
        app.launch()
    }

    /// 测试：点击灵动岛展开显示面板
    func testIslandView_tap_expands() {
        // 找到灵动岛视图
        let islandView = app.otherElements["compactIslandView"]
        XCTAssertTrue(islandView.exists, "应显示灵动岛视图")

        // 点击展开
        islandView.tap()

        // 验证展开视图显示
        let expandedView = app.otherElements["expandedIslandView"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: expandedView
        )
        wait(for: [expectation], timeout: 5.0)
    }

    /// 测试：展开视图显示三个标签页
    func testExpandedView_showsTabs() {
        // 展开灵动岛
        app.otherElements["compactIslandView"].tap()

        let expandedView = app.otherElements["expandedIslandView"]
        XCTAssertTrue(expandedView.waitForExistence(timeout: 5), "应显示展开视图")

        // 验证标签页存在
        XCTAssertTrue(app.buttons["额度"].exists, "应显示额度标签")
        XCTAssertTrue(app.buttons["会话"].exists, "应显示会话标签")
        XCTAssertTrue(app.buttons["上下文"].exists, "应显示上下文标签")
    }

    /// 测试：额度标签显示空状态（未配置 API Key）
    func testQuotaTab_showsEmptyState() {
        // 展开灵动岛
        app.otherElements["compactIslandView"].tap()
        XCTAssertTrue(app.otherElements["expandedIslandView"].waitForExistence(timeout: 5))

        // 切换到额度标签
        app.buttons["额度"].tap()

        // 验证空状态显示
        let emptyStateText = app.staticTexts["请在设置中添加 API Key"]
        XCTAssertTrue(emptyStateText.exists, "未配置 API Key 时应显示空状态")
    }

    /// 测试：切换标签页正常工作
    func testTabSwitching_worksCorrectly() {
        // 展开灵动岛
        app.otherElements["compactIslandView"].tap()
        XCTAssertTrue(app.otherElements["expandedIslandView"].waitForExistence(timeout: 5))

        // 切换到会话标签
        app.buttons["会话"].tap()
        XCTAssertTrue(app.staticTexts["会话"].exists || app.staticTexts["暂无活跃会话"].exists, "应显示会话标签内容")

        // 切换到上下文标签
        app.buttons["上下文"].tap()
        // 新版显示会话标题或 cwd，不再是固定文本 "上下文使用"
        XCTAssertTrue(app.staticTexts["暂无上下文数据"].exists || app.scrollViews.count > 0, "应显示上下文标签内容")

        // 切换回额度标签
        app.buttons["额度"].tap()
        XCTAssertTrue(app.staticTexts["请在设置中添加 API Key"].exists, "应回到额度标签")
    }
}
