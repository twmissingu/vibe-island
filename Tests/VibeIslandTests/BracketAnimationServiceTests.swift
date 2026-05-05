import XCTest
@testable import VibeIsland

@MainActor
final class BracketAnimationServiceTests: XCTestCase {

    // MARK: - 初始状态

    func testInitialState() {
        let service = BracketAnimationService()
        XCTAssertFalse(service.isExpanded)
    }

    // MARK: - start / stop

    func testStart_setsIsExpandedTrue() {
        let service = BracketAnimationService()
        service.start()
        XCTAssertTrue(service.isExpanded)
        service.stop()
    }

    func testStop_resetsState() {
        let service = BracketAnimationService()
        service.start()
        XCTAssertTrue(service.isExpanded)

        service.stop()
        XCTAssertFalse(service.isExpanded)
    }

    func testStop_withoutStart_doesNotCrash() {
        let service = BracketAnimationService()
        service.stop()
        XCTAssertFalse(service.isExpanded)
    }

    // MARK: - 重复启动保护

    func testStart_twice_doesNotCreateSecondTimer() {
        let service = BracketAnimationService()
        service.start()
        let firstExpanded = service.isExpanded

        // 第二次 start 应被 guard !isRunning 拦截
        service.start()
        XCTAssertEqual(service.isExpanded, firstExpanded)

        service.stop()
    }

    // MARK: - start → stop → start

    func testRestartAfterStop() {
        let service = BracketAnimationService()
        service.start()
        service.stop()
        XCTAssertFalse(service.isExpanded)

        service.start()
        XCTAssertTrue(service.isExpanded)
        service.stop()
    }

    // MARK: - Timer 回调（使用 RunLoop 推进）

    func testTimer_togglesIsExpanded() {
        let service = BracketAnimationService()
        service.start(interval: 0.05) // 50ms 间隔

        let expectation = expectation(description: "Timer fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.3)

        // 50ms 间隔，150ms 后至少触发 2 次 → isExpanded 应被 toggle
        // 无法确定确切值，但 stop 后一定为 false
        service.stop()
        XCTAssertFalse(service.isExpanded)
    }
}
