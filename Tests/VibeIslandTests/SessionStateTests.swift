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
        // 测试颜色不为 nil
        XCTAssertNotNil(SessionState.idle.color)
        XCTAssertNotNil(SessionState.completed.color)
        XCTAssertNotNil(SessionState.thinking.color)
        XCTAssertNotNil(SessionState.coding.color)
        XCTAssertNotNil(SessionState.waiting.color)
        XCTAssertNotNil(SessionState.waitingPermission.color)
        XCTAssertNotNil(SessionState.error.color)
        XCTAssertNotNil(SessionState.compacting.color)
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
        // 测试显示名称不为空
        for state in SessionState.allCases {
            XCTAssertFalse(state.displayName.isEmpty, "\(state) display name should not be empty")
        }
    }
}
