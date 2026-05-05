import XCTest
@testable import VibeIsland

@MainActor
final class SessionStateTests: XCTestCase {

    // MARK: - 优先级排序

    func testPriority_ordering() {
        let states: [SessionState] = [
            .idle, .thinking, .coding, .waiting,
            .waitingPermission, .completed, .error, .compacting
        ]
        let sorted = states.sorted(by: { $0.priority < $1.priority })

        XCTAssertEqual(sorted[0], .waitingPermission, "waitingPermission 最高优先级")
        XCTAssertEqual(sorted[1], .error)
        XCTAssertEqual(sorted[2], .compacting)
        XCTAssertEqual(sorted[3], .coding)
        XCTAssertEqual(sorted[4], .thinking)
        XCTAssertEqual(sorted[5], .waiting)
        XCTAssertEqual(sorted[6], .completed)
        XCTAssertEqual(sorted[7], .idle, "idle 最低优先级")
    }

    func testPriority_uniqueValues() {
        let allCases = SessionState.allCases
        let priorities = allCases.map(\.priority)
        XCTAssertEqual(priorities.count, Set(priorities).count, "每个状态的优先级应唯一")
    }

    // MARK: - 颜色映射

    func testColor_allStatesHaveColor() {
        for state in SessionState.allCases {
            // 只要不崩溃即可；颜色相等性在 SwiftUI 中难以断言
            _ = state.color
        }
    }

    func testColor_errorStateIsRed() {
        XCTAssertEqual(SessionState.error.color, .red)
    }

    func testColor_completedStateIsGreen() {
        XCTAssertEqual(SessionState.completed.color, .green)
    }

    func testColor_idleStateIsGray() {
        XCTAssertEqual(SessionState.idle.color, .gray)
    }

    // MARK: - 闪烁属性

    func testIsBlinking_approvalStates() {
        XCTAssertTrue(SessionState.waitingPermission.isBlinking)
        XCTAssertTrue(SessionState.compacting.isBlinking)
        XCTAssertTrue(SessionState.completed.isBlinking)
        XCTAssertTrue(SessionState.error.isBlinking)
    }

    func testIsBlinking_nonBlinkingStates() {
        XCTAssertFalse(SessionState.idle.isBlinking)
        XCTAssertFalse(SessionState.thinking.isBlinking)
        XCTAssertFalse(SessionState.coding.isBlinking)
        XCTAssertFalse(SessionState.waiting.isBlinking)
    }

    // MARK: - 显示名称

    func testDisplayName_allStatesNonEmpty() {
        for state in SessionState.allCases {
            XCTAssertFalse(state.displayName.isEmpty, "\(state) 的 displayName 不应为空")
        }
    }

    func testDisplayName_expectedValues() {
        XCTAssertEqual(SessionState.idle.displayName, "Idle")
        XCTAssertEqual(SessionState.thinking.displayName, "Thinking")
        XCTAssertEqual(SessionState.coding.displayName, "Coding")
        XCTAssertEqual(SessionState.waiting.displayName, "Waiting")
        XCTAssertEqual(SessionState.waitingPermission.displayName, "Permission")
        XCTAssertEqual(SessionState.completed.displayName, "Completed")
        XCTAssertEqual(SessionState.error.displayName, "Error")
        XCTAssertEqual(SessionState.compacting.displayName, "Compacting")
    }

    // MARK: - 状态转换

    func testTransition_sessionStart_goesToIdle() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .sessionStart),
            .idle
        )
    }

    func testTransition_userPromptSubmit_goesToCoding() {
        XCTAssertEqual(
            SessionState.transition(from: .idle, event: .userPromptSubmit),
            .coding
        )
    }

    func testTransition_preToolUse_goesToWaiting() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .preToolUse),
            .waiting
        )
    }

    func testTransition_postToolUse_goesToCoding() {
        XCTAssertEqual(
            SessionState.transition(from: .waiting, event: .postToolUse),
            .coding
        )
    }

    func testTransition_stop_goesToCompleted() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .stop),
            .completed
        )
    }

    func testTransition_permissionRequest_goesToWaitingPermission() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .permissionRequest),
            .waitingPermission
        )
    }

    func testTransition_preCompact_goesToCompacting() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .preCompact),
            .compacting
        )
    }

    func testTransition_notification_keepsCurrentState() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .notification),
            .coding
        )
        XCTAssertEqual(
            SessionState.transition(from: .idle, event: .notification),
            .idle
        )
    }

    func testTransition_subagentEvents_keepCurrentState() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .subagentStart),
            .coding
        )
        XCTAssertEqual(
            SessionState.transition(from: .waiting, event: .subagentStop),
            .waiting
        )
    }

    func testTransition_sessionError_goesToError() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .sessionError),
            .error
        )
    }

    func testTransition_sessionEnd_goesToCompleted() {
        XCTAssertEqual(
            SessionState.transition(from: .coding, event: .sessionEnd),
            .completed
        )
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        for state in SessionState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(SessionState.self, from: data)
            XCTAssertEqual(state, decoded)
        }
    }

    // MARK: - CaseIterable

    func testAllCases_count() {
        XCTAssertEqual(SessionState.allCases.count, 8)
    }

    // MARK: - 渐变色

    func testGradientColors_returnsTwoColors() {
        for state in SessionState.allCases {
            let colors = state.gradientColors
            XCTAssertEqual(colors.count, 2, "\(state) 应有 2 个渐变色")
        }
    }
}
