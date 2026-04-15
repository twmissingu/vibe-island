import XCTest
@testable import VibeIsland

// MARK: - SessionState 状态机测试

final class SessionStateTests: XCTestCase {
    
    // MARK: 状态转换测试
    
    func testSessionStartTransition() {
        let nextState = SessionState.transition(from: .idle, event: .sessionStart)
        XCTAssertEqual(nextState, .thinking)
    }
    
    func testUserPromptSubmitTransition() {
        let nextState = SessionState.transition(from: .idle, event: .userPromptSubmit)
        XCTAssertEqual(nextState, .thinking)
    }
    
    func testPreToolUseFromThinking() {
        let nextState = SessionState.transition(from: .thinking, event: .preToolUse)
        XCTAssertEqual(nextState, .coding)
    }
    
    func testPreToolUseFromWaiting() {
        let nextState = SessionState.transition(from: .waiting, event: .preToolUse)
        XCTAssertEqual(nextState, .coding)
    }
    
    func testPreToolUseFromWaitingPermission() {
        let nextState = SessionState.transition(from: .waitingPermission, event: .preToolUse)
        XCTAssertEqual(nextState, .coding)
    }
    
    func testPostToolUseFromCoding() {
        let nextState = SessionState.transition(from: .coding, event: .postToolUse)
        XCTAssertEqual(nextState, .thinking)
    }
    
    func testPostToolUseFailure() {
        let nextState = SessionState.transition(from: .coding, event: .postToolUseFailure)
        XCTAssertEqual(nextState, .error)
    }
    
    func testStopTransition() {
        let nextState = SessionState.transition(from: .thinking, event: .stop)
        XCTAssertEqual(nextState, .completed)
    }
    
    func testPermissionRequestTransition() {
        let nextState = SessionState.transition(from: .thinking, event: .permissionRequest)
        XCTAssertEqual(nextState, .waitingPermission)
    }
    
    func testPreCompactTransition() {
        let nextState = SessionState.transition(from: .thinking, event: .preCompact)
        XCTAssertEqual(nextState, .compacting)
    }
    
    func testPostCompactFromCompacting() {
        let nextState = SessionState.transition(from: .compacting, event: .postCompact)
        XCTAssertEqual(nextState, .thinking)
    }
    
    func testPostCompactFromOtherState() {
        let nextState = SessionState.transition(from: .idle, event: .postCompact)
        XCTAssertEqual(nextState, .idle)  // 不应该改变状态
    }
    
    func testSessionErrorTransition() {
        let nextState = SessionState.transition(from: .thinking, event: .sessionError)
        XCTAssertEqual(nextState, .error)
    }
    
    func testSessionEndTransition() {
        let nextState = SessionState.transition(from: .thinking, event: .sessionEnd)
        XCTAssertEqual(nextState, .completed)
    }
    
    // MARK: 优先级测试
    
    func testPriorityOrder() {
        // 审批 > 错误 > 压缩 > 编码 > 思考 > 等待 > 完成 > 空闲
        XCTAssertLessThan(SessionState.waitingPermission.priority, SessionState.error.priority)
        XCTAssertLessThan(SessionState.error.priority, SessionState.compacting.priority)
        XCTAssertLessThan(SessionState.compacting.priority, SessionState.coding.priority)
        XCTAssertLessThan(SessionState.coding.priority, SessionState.thinking.priority)
        XCTAssertLessThan(SessionState.thinking.priority, SessionState.waiting.priority)
        XCTAssertLessThan(SessionState.waiting.priority, SessionState.completed.priority)
        XCTAssertLessThan(SessionState.completed.priority, SessionState.idle.priority)
    }
    
    func testWaitingPermissionHasHighestPriority() {
        let minPriority = SessionState.allCases.map(\.priority).min()
        XCTAssertEqual(minPriority, SessionState.waitingPermission.priority)
    }
    
    func testIdleHasLowestPriority() {
        let maxPriority = SessionState.allCases.map(\.priority).max()
        XCTAssertEqual(maxPriority, SessionState.idle.priority)
    }
    
    // MARK: 颜色测试

    func testStateColors() {
        XCTAssertEqual(SessionState.idle.color, .gray)
        XCTAssertEqual(SessionState.completed.color, .green)
        XCTAssertEqual(SessionState.thinking.color, .yellow)
        XCTAssertEqual(SessionState.coding.color, .green)
        XCTAssertEqual(SessionState.waiting.color, .orange)
        XCTAssertEqual(SessionState.waitingPermission.color, .yellow)
        XCTAssertEqual(SessionState.error.color, .red)
        XCTAssertEqual(SessionState.compacting.color, .orange)
    }
    
    // MARK: 闪烁测试
    
    func testBlinkingStates() {
        XCTAssertTrue(SessionState.waitingPermission.isBlinking)
        XCTAssertTrue(SessionState.compacting.isBlinking)
        XCTAssertFalse(SessionState.idle.isBlinking)
        XCTAssertFalse(SessionState.error.isBlinking)
    }
    
    // MARK: 显示名测试
    
    func testDisplayNames() {
        XCTAssertEqual(SessionState.idle.displayName, "空闲")
        XCTAssertEqual(SessionState.thinking.displayName, "思考中")
        XCTAssertEqual(SessionState.coding.displayName, "编码中")
        XCTAssertEqual(SessionState.waiting.displayName, "等待输入")
        XCTAssertEqual(SessionState.waitingPermission.displayName, "等待权限")
        XCTAssertEqual(SessionState.completed.displayName, "已完成")
        XCTAssertEqual(SessionState.error.displayName, "错误")
        XCTAssertEqual(SessionState.compacting.displayName, "压缩中")
    }
}
