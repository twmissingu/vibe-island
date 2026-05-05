import XCTest
@testable import VibeIsland

@MainActor
final class SessionFileWatcherTests: XCTestCase {

    private var watcher: SessionFileWatcher!

    override func setUp() {
        super.setUp()
        watcher = SessionFileWatcher()
    }

    override func tearDown() {
        watcher.stopWatching()
        watcher = nil
        super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialSessionsEmpty() {
        XCTAssertTrue(watcher.allSessions.isEmpty)
    }

    func testInitialIsWatchingFalse() {
        XCTAssertFalse(watcher.isWatching)
    }

    func testInitialTopSessionNil() {
        XCTAssertNil(watcher.topSession)
    }

    // MARK: - sessionsDirectory

    func testSessionsDirectory_pointsToCorrectPath() {
        let expectedSuffix = ".vibe-island/sessions"
        XCTAssertTrue(
            SessionFileWatcher.sessionsDirectory.path.hasSuffix(expectedSuffix),
            "sessionsDirectory 应以 \(expectedSuffix) 结尾，实际: \(SessionFileWatcher.sessionsDirectory.path)"
        )
    }

    // MARK: - sessionStatus 协议方法

    func testSessionStatus_returnsSessionStatus() {
        let session = Session(
            sessionId: "test-1",
            cwd: "/tmp",
            status: .coding,
            lastActivity: Date()
        )
        XCTAssertEqual(watcher.sessionStatus(session), .coding)
    }

    // MARK: - startWatching / stopWatching

    func testStartStopWatching_doesNotCrash() {
        watcher.startWatching()
        XCTAssertTrue(watcher.isWatching)

        watcher.stopWatching()
        XCTAssertFalse(watcher.isWatching)
    }

    func testStopWatching_withoutStart_doesNotCrash() {
        watcher.stopWatching()
        XCTAssertFalse(watcher.isWatching)
    }

    // MARK: - onSessionUpdated 回调

    func testOnSessionUpdated_setsCallback() {
        // 验证设置回调不会崩溃
        watcher.onSessionUpdated { _, _ in
            // 回调在实际文件变化时触发
        }
    }

    // MARK: - topSession 计算

    func testTopSession_returnsHighestPrioritySession() {
        // 通过 injectSessions 模拟（使用 SessionAggregatable 协议间接测试）
        // 由于 SessionFileWatcher 的 sessions 是 private(set)，
        // 只能通过 startWatching → 文件扫描来填充
        // 这里测试 nil 的情况
        XCTAssertNil(watcher.topSession)
    }

    // MARK: - SessionAggregatable 协议

    func testAggregateState_emptyIsIdle() {
        XCTAssertEqual(watcher.aggregateState, .idle)
    }

    func testActiveCount_emptyIsZero() {
        XCTAssertEqual(watcher.activeCount, 0)
    }

    func testHasPendingPermission_emptyIsFalse() {
        XCTAssertFalse(watcher.hasPendingPermission)
    }

    func testHasError_emptyIsFalse() {
        XCTAssertFalse(watcher.hasError)
    }
}
