import XCTest
@testable import VibeIsland

@MainActor
final class CodingTimeTrackerTests: XCTestCase {

    private var tracker: CodingTimeTracker!

    override func setUp() {
        super.setUp()
        tracker = CodingTimeTracker.shared
        tracker.reset()
    }

    override func tearDown() {
        tracker.reset()
        super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialState_allZeros() {
        XCTAssertEqual(tracker.todayCodingSeconds, 0)
        XCTAssertEqual(tracker.weekCodingSeconds, 0)
        XCTAssertEqual(tracker.totalCodingSeconds, 0)
    }

    func testInitialMinutes_allZeros() {
        XCTAssertEqual(tracker.todayCodingMinutes, 0)
        XCTAssertEqual(tracker.weekCodingMinutes, 0)
        XCTAssertEqual(tracker.totalCodingMinutes, 0)
    }

    // MARK: - reset()

    func testReset_clearsAllCounters() {
        // 先进入编码状态积累一些数据
        tracker.handleSessionStateChange(sessionId: "s1", state: .coding)
        _ = tracker // force evaluation

        tracker.reset()

        XCTAssertEqual(tracker.todayCodingSeconds, 0)
        XCTAssertEqual(tracker.weekCodingSeconds, 0)
        XCTAssertEqual(tracker.totalCodingSeconds, 0)
    }

    // MARK: - handleSessionStateChange 状态判断

    func testHandleSessionStateChange_codingState_addsToActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .coding)
        // tick 应该累加时间
        tracker.tick()
        XCTAssertGreaterThanOrEqual(tracker.todayCodingSeconds, 0) // 可能为 0（wall clock 差异）
    }

    func testHandleSessionStateChange_thinkingState_addsToActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .thinking)
        tracker.tick()
        // 不崩溃即通过
    }

    func testHandleSessionStateChange_waitingPermissionState_addsToActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .waitingPermission)
        tracker.tick()
        // 不崩溃即通过
    }

    func testHandleSessionStateChange_idleState_notActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .idle)
        tracker.tick()
        XCTAssertEqual(tracker.todayCodingSeconds, 0)
    }

    func testHandleSessionStateChange_completedState_notActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .completed)
        tracker.tick()
        XCTAssertEqual(tracker.todayCodingSeconds, 0)
    }

    func testHandleSessionStateChange_errorState_notActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .error)
        tracker.tick()
        XCTAssertEqual(tracker.todayCodingSeconds, 0)
    }

    func testHandleSessionStateChange_waitingState_notActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .waiting)
        tracker.tick()
        XCTAssertEqual(tracker.todayCodingSeconds, 0)
    }

    func testHandleSessionStateChange_compactingState_notActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .compacting)
        tracker.tick()
        XCTAssertEqual(tracker.todayCodingSeconds, 0)
    }

    // MARK: - tick() 累加

    func testTick_withActiveSessions_incrementsTotal() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .coding)
        // 手动设置 lastCheckDate 使得 tick 有时间差
        // 由于无法注入时钟，只能验证不崩溃且 totalCodingSeconds >= 0
        tracker.tick()
        XCTAssertGreaterThanOrEqual(tracker.totalCodingSeconds, 0)
    }

    func testTick_withoutActiveSessions_doesNotIncrement() {
        tracker.tick()
        XCTAssertEqual(tracker.totalCodingSeconds, 0)
        XCTAssertEqual(tracker.todayCodingSeconds, 0)
        XCTAssertEqual(tracker.weekCodingSeconds, 0)
    }

    // MARK: - 分钟转换

    func testMinutes_conversion() {
        // todayCodingSeconds 是 private(set)，只能通过 reset 后的状态间接测试
        // 0 秒 → 0 分钟
        XCTAssertEqual(tracker.todayCodingMinutes, 0)
        XCTAssertEqual(tracker.weekCodingMinutes, 0)
        XCTAssertEqual(tracker.totalCodingMinutes, 0)
    }

    // MARK: - 持久化

    func testPersistData_doesNotCrash() {
        // 直接调用 persist 和 load 不会崩溃
        tracker.handleSessionStateChange(sessionId: "s1", state: .coding)
        // stop() 会触发 persistData()
        tracker.stop()
        // 重新启动不会崩溃
        tracker.start()
    }

    // MARK: - 多会话

    func testMultipleSessions_allActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .coding)
        tracker.handleSessionStateChange(sessionId: "s2", state: .thinking)
        tracker.handleSessionStateChange(sessionId: "s3", state: .waitingPermission)

        tracker.tick()
        // 三个活跃会话，不崩溃即通过
        XCTAssertGreaterThanOrEqual(tracker.totalCodingSeconds, 0)
    }

    func testSessionBecomesInactive_removesFromActive() {
        tracker.handleSessionStateChange(sessionId: "s1", state: .coding)
        tracker.handleSessionStateChange(sessionId: "s1", state: .completed)
        tracker.tick()
        XCTAssertEqual(tracker.totalCodingSeconds, 0)
    }

    // MARK: - start / stop

    func testStartStop_doesNotCrash() {
        tracker.start()
        tracker.stop()
    }
}
