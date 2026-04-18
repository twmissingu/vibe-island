import XCTest
@testable import VibeIsland

// MARK: - 性能测试

/// 验证关键路径在并发场景下的性能表现
@MainActor
final class PerformanceTests: XCTestCase {

    // MARK: Session 状态转换性能

    func testStateTransitionPerformance() {
        let events: [SessionEventName] = [
            .sessionStart, .userPromptSubmit, .preToolUse, .postToolUse,
            .preToolUse, .postToolUse, .preToolUse, .postToolUse,
            .stop, .sessionEnd
        ]

        // 10000 次状态转换应在合理时间内完成
        measure {
            for _ in 0..<10000 {
                var state = SessionState.idle
                for event in events {
                    state = SessionState.transition(from: state, event: event)
                }
            }
        }
    }

    // MARK: Session 文件读写性能

    func testSessionFileReadWritePerformance() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("perf-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let session = Session(
            sessionId: "perf-test",
            cwd: "/tmp/perf",
            status: .coding,
            lastActivity: Date(),
            branch: "main",
            source: "claude",
            sessionName: "Performance Test",
            lastTool: "Bash",
            lastToolDetail: "echo hello",
            activeSubagents: [],
            pid: 12345,
            pidStartTime: Date().timeIntervalSince1970
        )

        let fileURL = tempDir.appendingPathComponent("session.json")

        // 1000 次读写应在合理时间内完成
        measure {
            for _ in 0..<1000 {
                try? session.writeToFile()
                _ = try? Session.loadFromFile(url: fileURL)
            }
        }

        try FileManager.default.removeItem(at: tempDir)
    }

    // MARK: SessionManager 并发注入性能

    func testSessionManagerConcurrentInjectionPerformance() async {
        let manager = SessionManager.makeForTesting()

        // 并发注入 100 个会话
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask { @MainActor in
                    let session = Session(
                        sessionId: "session-\(index)",
                        cwd: "/tmp/test-\(index)",
                        status: index % 2 == 0 ? .coding : .thinking,
                        lastActivity: Date()
                    )
                    manager.injectSessionForTesting(session)
                }
            }
        }

        XCTAssertEqual(manager.sessions.count, 100)
    }

    // MARK: MultiToolAggregator 排序性能

    func testMultiToolSortPerformance() {
        let sessions: [UnifiedSessionView] = (0..<1000).map { index in
            UnifiedSessionView(
                sessionId: "session-\(index)",
                sessionName: "Test Session \(index)",
                cwd: "/tmp/test-\(index)",
                status: SessionState.allCases[index % SessionState.allCases.count],
                source: index % 3 == 0 ? .claudeCode : (index % 3 == 1 ? .openCode : .codex),
                lastActivity: Date()
            )
        }

        let aggregator = MultiToolAggregator.shared

        measure {
            _ = sessions.sorted { $0.status.priority < $1.status.priority }
        }
    }

    // MARK: ContextMonitor 解析性能
    // 暂时注释，parseContextUsage为private方法
    /*
    func testContextParsingPerformance() {
        let monitor = ContextMonitor.shared
        let message = "Context usage: 85% (170000/200000 tokens)"

        // 10000 次解析应在合理时间内完成
        measure {
            for _ in 0..<10000 {
                _ = monitor.parseContextUsage(from: message, sessionId: "test")
            }
        }
    }
    */

    // MARK: 文件监听防抖动性能

    func testDebouncePerformance() throws {
        let watcher = SessionFileWatcher()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("debounce-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fileURL = tempDir.appendingPathComponent("session.json")
        let session = Session(sessionId: "debounce", cwd: tempDir.path, status: .idle, lastActivity: Date())
        try session.writeToFile()

        // 快速写入 50 次，验证防抖动不会导致性能问题
        measure {
            for _ in 0..<50 {
                try? session.writeToFile()
                // 小间隔写入
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        try FileManager.default.removeItem(at: tempDir)
    }

    // MARK: SoundManager 播放性能

    func testSoundPlaybackPerformance() {
        let soundManager = SoundManager.shared

        // 连续播放 10 次应无延迟
        measure {
            for _ in 0..<10 {
                _ = soundManager.play(type: .permissionRequest)
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }
}
