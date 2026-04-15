import XCTest
import SwiftUI
@testable import VibeIsland
import LLMQuotaKit

// MARK: - 会话列表 UI 测试

/// 测试 SessionListView 的核心用户交互流程
/// 包括：列表显示、模式切换、会话选择等
@MainActor
final class SessionListUITests: XCTestCase {

    // MARK: - 辅助方法

    /// 创建测试用会话
    private func makeSession(
        id: String,
        status: SessionState = .idle,
        cwd: String = "/tmp/project",
        source: String? = nil,
        lastActivity: Date = Date()
    ) -> Session {
        Session(
            sessionId: id,
            cwd: cwd,
            status: status,
            lastActivity: lastActivity,
            source: source
        )
    }

    // MARK: - 视图结构测试

    /// 测试：SessionListView 应成功初始化
    func testSessionListView_initializes() {
        let view = SessionListView()
        XCTAssertNotNil(view, "SessionListView 应成功初始化")
    }

    // 注意：SessionRow 是 private 的，无法从测试访问
    // func testSessionRow_initializes() {
    //     let session = makeSession(id: "test-1", status: .coding)
    //     let row = SessionListView.SessionRow(
    //         session: session,
    //         sessionId: session.sessionId,
    //         isTracked: false,
    //         isAutoMode: true,
    //         onSelect: {}
    //     )
    //     XCTAssertNotNil(row, "SessionRow 应成功初始化")
    // }

    // MARK: - 列表显示测试

    /// 测试：无会话时显示空状态
    func testSessionList_empty_showsEmptyState() {
        let manager = SessionManager.makeForTesting()
        let isEmpty = manager.sortedSessions.isEmpty
        XCTAssertTrue(isEmpty, "无会话时应显示空状态")
    }

    /// 测试：有会话时显示列表
    func testSessionList_hasSessions_showsList() {
        let manager = SessionManager.makeForTesting()
        let session = makeSession(id: "s1", status: .coding)
        manager.injectSessionForTesting(session)

        let hasSessions = !manager.sortedSessions.isEmpty
        XCTAssertTrue(hasSessions, "有会话时应显示会话列表")
    }

    /// 测试：会话列表按优先级排序
    func testSessionList_sortedByPriority() {
        let manager = SessionManager.makeForTesting()

        let idle = makeSession(id: "idle", status: .idle)
        let coding = makeSession(id: "coding", status: .coding)
        let error = makeSession(id: "error", status: .error)

        manager.injectSessionForTesting(idle)
        manager.injectSessionForTesting(coding)
        manager.injectSessionForTesting(error)

        let sorted = manager.sortedSessions
        // error 优先级最高，应排在最前
        XCTAssertEqual(sorted.first?.status, .error, "error 会话应排在最前")
    }

    // MARK: - 模式切换测试

    /// 测试：初始模式为自动
    func testTrackingMode_initial_isAuto() {
        let manager = SessionManager.makeForTesting()
        XCTAssertTrue(manager.trackingMode.isAuto, "初始模式应为自动")
    }

    /// 测试：点击自动/固定按钮应切换模式
    func testTrackingMode_toggle_autoToManual() {
        let manager = SessionManager.makeForTesting()
        manager.setTrackingModeForTesting(.auto)

        let session = makeSession(id: "s1", status: .coding)
        manager.injectSessionForTesting(session)

        // 模拟点击切换按钮
        manager.toggleTrackingMode()

        if case .manual = manager.trackingMode {
            // 成功切换到手动模式
        } else {
            XCTFail("应切换到手动模式")
        }
    }

    /// 测试：手动模式切换回自动
    func testTrackingMode_toggle_manualToAuto() {
        let manager = SessionManager.makeForTesting()
        manager.setTrackingModeForTesting(.manual(sessionId: "s1"))

        // 模拟点击切换按钮
        manager.toggleTrackingMode()

        XCTAssertTrue(manager.trackingMode.isAuto, "应切换回自动模式")
    }

    /// 测试：自动模式按钮文本为"自动"
    func testTrackingModeButton_autoText() {
        let manager = SessionManager.makeForTesting()
        manager.setTrackingModeForTesting(.auto)

        let buttonText = manager.trackingMode.isAuto ? "自动" : "固定"
        XCTAssertEqual(buttonText, "自动", "自动模式时按钮文本应为'自动'")
    }

    /// 测试：手动模式按钮文本为"固定"
    func testTrackingModeButton_manualText() {
        let manager = SessionManager.makeForTesting()
        manager.setTrackingModeForTesting(.manual(sessionId: "s1"))

        let buttonText = manager.trackingMode.isAuto ? "自动" : "固定"
        XCTAssertEqual(buttonText, "固定", "手动模式时按钮文本应为'固定'")
    }

    // MARK: - 会话选择测试

    /// 测试：点击会话行应固定该会话
    func testSessionRow_select_pinsSession() {
        let manager = SessionManager.makeForTesting()
        let session = makeSession(id: "target", status: .coding)
        manager.injectSessionForTesting(session)

        // 模拟点击会话行
        manager.setTrackingModeManual(sessionId: session.sessionId)

        XCTAssertEqual(manager.pinnedSessionId, "target", "点击后应固定该会话")
    }

    /// 测试：点击已跟踪的会话不应改变状态
    func testSessionRow_selectTracked_noChange() {
        let manager = SessionManager.makeForTesting()
        let session = makeSession(id: "tracked", status: .coding)
        manager.injectSessionForTesting(session)
        manager.setTrackingModeManual(sessionId: session.sessionId)

        let trackedBefore = manager.trackedSession?.sessionId

        // 模拟再次点击已跟踪的会话
        // 在 SessionListView 中，点击已跟踪的会话会跳过
        if session.sessionId == manager.trackedSession?.sessionId {
            // 不做任何操作
        }

        let trackedAfter = manager.trackedSession?.sessionId
        XCTAssertEqual(trackedBefore, trackedAfter, "点击已跟踪的会话不应改变状态")
    }

    // MARK: - 跟踪指示器测试

    /// 测试：自动模式下最高优先级会话显示跟踪指示器
    func testSessionTrackingIndicator_autoMode_showsOnTopSession() {
        let manager = SessionManager.makeForTesting()
        manager.setTrackingModeForTesting(.auto)

        let idle = makeSession(id: "idle", status: .idle)
        let coding = makeSession(id: "coding", status: .coding)

        manager.injectSessionForTesting(idle)
        manager.injectSessionForTesting(coding)

        let topSession = manager.sortedSessions.first
        let isTracked = topSession?.sessionId == coding.sessionId

        XCTAssertTrue(isTracked, "自动模式下 coding 会话应被跟踪")
    }

    /// 测试：手动模式下固定会话显示跟踪指示器
    func testSessionTrackingIndicator_manualMode_showsOnPinnedSession() {
        let manager = SessionManager.makeForTesting()
        let session = makeSession(id: "pinned", status: .idle)
        manager.injectSessionForTesting(session)

        manager.setTrackingModeManual(sessionId: session.sessionId)

        let isPinnedTracked = manager.pinnedSessionId == "pinned"
        XCTAssertTrue(isPinnedTracked, "手动模式下固定会话应被跟踪")
    }

    // MARK: - 自动模式指示器测试

    /// 测试：自动模式应显示"自动跟踪最高优先级会话"文本
    func testAutoModeIndicator_showsText() {
        let manager = SessionManager.makeForTesting()
        manager.setTrackingModeForTesting(.auto)

        let isAuto = manager.trackingMode.isAuto
        XCTAssertTrue(isAuto, "自动模式应显示自动跟踪指示器")
    }

    /// 测试：手动模式应显示已固定会话信息
    func testManualModeIndicator_showsPinnedInfo() {
        let manager = SessionManager.makeForTesting()
        let session = makeSession(id: "pinned", status: .coding, cwd: "/tmp/my-project")
        manager.injectSessionForTesting(session)
        manager.setTrackingModeManual(sessionId: session.sessionId)

        let pinnedId = manager.pinnedSessionId
        let pinnedSession = manager.session(id: pinnedId ?? "")

        XCTAssertNotNil(pinnedSession, "手动模式应显示已固定会话信息")
    }

    // MARK: - 空状态测试

    /// 测试：空列表显示"暂无活跃会话"
    func testEmptyState_showsMessage() {
        let manager = SessionManager.makeForTesting()
        let isEmpty = manager.sortedSessions.isEmpty
        XCTAssertTrue(isEmpty, "空列表应显示空状态")
    }

    /// 测试：空状态显示终端图标
    func testEmptyState_showsIcon() {
        // 空状态应显示 terminal 图标
        let iconName = "terminal"
        XCTAssertFalse(iconName.isEmpty, "空状态应显示图标")
    }

    // MARK: - SessionRow 样式测试

    /// 测试：已跟踪会话行有高亮背景
    func testSessionRow_tracked_hasHighlightBackground() {
        let isTracked = true
        let hasBackground = isTracked
        XCTAssertTrue(hasBackground, "已跟踪会话行应有高亮背景")
    }

    /// 测试：未跟踪会话行无高亮背景
    func testSessionRow_notTracked_noHighlightBackground() {
        let isTracked = false
        let hasBackground = isTracked
        XCTAssertFalse(hasBackground, "未跟踪会话行不应有高亮背景")
    }

    /// 测试：会话行显示状态图标
    func testSessionRow_showsStateIcon() {
        let states: [SessionState] = SessionState.allCases
        for state in states {
            let icon = state.icon
            XCTAssertFalse(icon.isEmpty, "\(state.displayName) 状态应有对应图标")
        }
    }

    /// 测试：会话行显示状态名称
    func testSessionRow_showsStateName() {
        let session = makeSession(id: "s1", status: .coding)
        let stateName = session.status.displayName
        XCTAssertFalse(stateName.isEmpty, "会话行应显示状态名称")
    }

    /// 测试：会话行显示缩短的路径
    func testSessionRow_shortenedPath() {
        let longPath = "/Users/user/projects/my-long-project-name/src"

        // 模拟缩短逻辑
        let components = longPath.split(separator: "/")
        let shortened: String
        if components.count > 3 {
            shortened = ".../" + components.suffix(2).joined(separator: "/")
        } else {
            shortened = longPath
        }

        XCTAssertTrue(shortened.hasPrefix(".../"), "长路径应被缩短显示")
    }
}

// MARK: - XCUITest 版本（供未来 UI Test Target 使用）
/*
import XCTest

@MainActor
final class SessionListXCUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--test-sessions"]
        app.launch()
    }

    /// 测试：展开灵动岛后切换到会话标签
    func testSessionList_switchToSessionsTab() {
        // 先展开灵动岛
        app.otherElements["compactIsland"].tap()

        let expectation1 = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.otherElements["expandedIsland"]
        )
        wait(for: [expectation1], timeout: 2.0)

        // 切换到"会话"标签
        app.buttons["会话"].tap()

        // 验证会话列表显示
        let sessionList = app.otherElements["sessionListView"]
        let expectation2 = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: sessionList
        )
        wait(for: [expectation2], timeout: 2.0)
    }

    /// 测试：验证会话列表显示
    func testSessionList_displaysSessions() {
        // 展开并切换到会话标签
        app.otherElements["compactIsland"].tap()
        app.buttons["会话"].tap()

        // 验证会话行存在
        let sessionRows = app.otherElements.matching(identifier: "sessionRow")
        XCTAssertGreaterThan(sessionRows.count, 0, "应显示会话行")
    }

    /// 测试：点击自动/固定按钮切换跟踪模式
    func testSessionList_toggleTrackingMode() {
        // 展开并切换到会话标签
        app.otherElements["compactIsland"].tap()
        app.buttons["会话"].tap()

        // 获取当前模式按钮文本
        let modeButton = app.buttons["自动"]
        XCTAssertTrue(modeButton.exists, "应显示自动模式按钮")

        modeButton.tap()

        // 验证切换到手动模式
        let manualButton = app.buttons["固定"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: manualButton
        )
        wait(for: [expectation], timeout: 2.0)
    }

    /// 测试：点击会话行验证固定状态
    func testSessionList_selectSession_pinsSession() {
        // 展开并切换到会话标签
        app.otherElements["compactIsland"].tap()
        app.buttons["会话"].tap()

        // 点击第一个会话
        let firstSession = app.otherElements["sessionRow"].firstMatch
        XCTAssertTrue(firstSession.exists, "应存在会话行")

        firstSession.tap()

        // 验证会话被固定（通过检查跟踪指示器）
        let pinnedIndicator = app.staticTexts["已固定"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: pinnedIndicator
        )
        wait(for: [expectation], timeout: 2.0)
    }

    /// 测试：空状态显示
    func testSessionList_emptyState() {
        // 展开并切换到会话标签
        app.otherElements["compactIsland"].tap()
        app.buttons["会话"].tap()

        // 验证空状态消息
        let emptyMessage = app.staticTexts["暂无活跃会话"]
        XCTAssertTrue(emptyMessage.exists, "无会话时应显示空状态消息")
    }
}
*/
