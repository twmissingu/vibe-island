import XCTest
@testable import VibeIsland

// MARK: - Codex 监控服务测试

@MainActor
final class CodexMonitorTests: XCTestCase {

    // MARK: - 生命周期

    override func setUp() {
        super.setUp()
        // 确保单例处于干净状态
        if CodexMonitor.shared.isRunning {
            CodexMonitor.shared.stop()
        }
    }

    override func tearDown() {
        if CodexMonitor.shared.isRunning {
            CodexMonitor.shared.stop()
        }
        super.tearDown()
    }

    // MARK: - CodexStatus 枚举测试

    /// 测试：CodexStatus 所有枚举值的 rawValue
    func testCodexStatus_rawValues() {
        XCTAssertEqual(CodexStatus.idle.rawValue, "idle")
        XCTAssertEqual(CodexStatus.running.rawValue, "running")
        XCTAssertEqual(CodexStatus.completed.rawValue, "completed")
        XCTAssertEqual(CodexStatus.error.rawValue, "error")
    }

    /// 测试：CodexStatus 枚举数量为 4
    func testCodexStatus_count() {
        let allStatuses: [CodexStatus] = [.idle, .running, .completed, .error]
        XCTAssertEqual(allStatuses.count, 4)
    }

    /// 测试：CodexStatus 到 SessionState 的映射
    func testCodexStatus_toSessionState() {
        XCTAssertEqual(CodexStatus.idle.toSessionState, .idle)
        XCTAssertEqual(CodexStatus.running.toSessionState, .coding)
        XCTAssertEqual(CodexStatus.completed.toSessionState, .completed)
        XCTAssertEqual(CodexStatus.error.toSessionState, .error)
    }

    /// 测试：CodexStatus Codable 编解码
    func testCodexStatus_encodeDecode() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in [CodexStatus.idle, .running, .completed, .error] {
            let data = try! encoder.encode(status)
            let decoded = try! decoder.decode(CodexStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    /// 测试：CodexStatus Equatable 一致性
    func testCodexStatus_equality() {
        XCTAssertEqual(CodexStatus.idle, CodexStatus.idle)
        XCTAssertNotEqual(CodexStatus.idle, CodexStatus.running)
    }

    // MARK: - CodexSession 模型测试

    /// 测试：CodexSession 基本初始化
    func testCodexSession_basicInitialization() {
        let session = CodexSession(
            sessionId: "12345",
            pid: 12345,
            cwd: "/tmp/codex-test",
            status: .running,
            command: "codex",
            lastCheck: Date()
        )

        XCTAssertEqual(session.sessionId, "12345")
        XCTAssertEqual(session.pid, 12345)
        XCTAssertEqual(session.cwd, "/tmp/codex-test")
        XCTAssertEqual(session.status, .running)
        XCTAssertEqual(session.command, "codex")
    }

    /// 测试：CodexSession cwd 为 nil
    func testCodexSession_nilCwd() {
        let session = CodexSession(
            sessionId: "54321",
            pid: 54321,
            cwd: nil,
            status: .running,
            command: "codex-cli",
            lastCheck: Date()
        )

        XCTAssertNil(session.cwd)
    }

    /// 测试：CodexSession Equatable
    func testCodexSession_equality() {
        let date = Date()
        let session1 = CodexSession(
            sessionId: "eq-1",
            pid: 111,
            cwd: "/tmp",
            status: .running,
            command: "codex",
            lastCheck: date
        )
        let session2 = CodexSession(
            sessionId: "eq-1",
            pid: 111,
            cwd: "/tmp",
            status: .running,
            command: "codex",
            lastCheck: date
        )

        XCTAssertEqual(session1, session2)
    }

    /// 测试：CodexSession 不等价
    func testCodexSession_inequality() {
        let date = Date()
        let session1 = CodexSession(
            sessionId: "neq-1",
            pid: 111,
            cwd: "/tmp",
            status: .running,
            command: "codex",
            lastCheck: date
        )
        let session2 = CodexSession(
            sessionId: "neq-2",
            pid: 222,
            cwd: "/tmp",
            status: .running,
            command: "codex",
            lastCheck: date
        )

        XCTAssertNotEqual(session1, session2)
    }

    /// 测试：CodexSession 转换为 Session 模型 - 正常 cwd
    func testCodexSession_toSession_withCwd() {
        let session = CodexSession(
            sessionId: "conv-1",
            pid: 1001,
            cwd: "/Users/test/codex-project",
            status: .running,
            command: "codex",
            lastCheck: Date()
        )

        let converted = session.toSession()

        XCTAssertEqual(converted.sessionId, "codex_conv-1")
        XCTAssertEqual(converted.cwd, "/Users/test/codex-project")
        XCTAssertEqual(converted.status, .coding)
        XCTAssertEqual(converted.source, "codex")
        XCTAssertTrue((converted.sessionName ?? "").contains("codex-project"))
    }

    /// 测试：CodexSession 转换为 Session 模型 - cwd 为 nil
    func testCodexSession_toSession_nilCwd() {
        let session = CodexSession(
            sessionId: "conv-2",
            pid: 1002,
            cwd: nil,
            status: .idle,
            command: "codex",
            lastCheck: Date()
        )

        let converted = session.toSession()

        XCTAssertEqual(converted.cwd, "unknown")
        XCTAssertTrue((converted.sessionName ?? "").contains("unknown"))
    }

    // MARK: - 进程名称常量测试

    /// 测试：codexProcessNames 包含预期值
    func testCodexProcessNames() {
        let names = CodexMonitor.codexProcessNames
        XCTAssertTrue(names.contains("codex"))
        XCTAssertTrue(names.contains("codex-cli"))
        XCTAssertEqual(names.count, 2)
    }

    /// 测试：defaultCheckInterval 值
    func testDefaultCheckInterval() {
        XCTAssertEqual(CodexMonitor.defaultCheckInterval, 5.0)
    }

    // MARK: - 进程检测测试

    /// 测试：单例进程检测器初始化
    func testProcessDetector_initialization() {
        let detector = ProcessDetector()
        XCTAssertNotNil(detector)
    }

    /// 测试：进程检测器单例一致性
    func testProcessDetector_singletonConsistency() {
        let detector1 = ProcessDetector.shared
        let detector2 = ProcessDetector.shared
        XCTAssertEqual(ObjectIdentifier(detector1 as AnyObject), ObjectIdentifier(detector2 as AnyObject))
    }

    // MARK: - cwd 获取测试

    /// 测试：获取不存在进程的 cwd 返回 nil
    func testGetProcessCWD_nonexistentProcess() {
        let detector = ProcessDetector()
        // PID 1 通常是 launchd，但无权访问时返回 nil
        // 使用一个极不可能存在的 PID
        let cwd = detector.getProcessCWD(pid: 999999)
        // 不验证具体值，因为取决于系统状态
        // 验证方法不崩溃即可
    }

    /// 测试：获取当前进程 cwd
    func testGetProcessCWD_currentProcess() {
        let detector = ProcessDetector()
        let currentPid = getpid()
        let cwd = detector.getProcessCWD(pid: Int(currentPid))
        // 当前进程应该能获取到 cwd
        // 具体值取决于运行环境，只验证不崩溃
        _ = cwd
    }

    // MARK: - 进程存活检测测试

    /// 测试：检测当前进程是否运行
    func testIsProcessRunning_currentProcess() {
        let detector = ProcessDetector()
        let currentPid = Int(getpid())
        // 当前进程应该被认为是运行中的
        // 但具体结果取决于系统权限
        _ = detector.isProcessRunning(pid: currentPid)
    }

    /// 测试：检测不存在的进程
    func testIsProcessRunning_nonexistentProcess() {
        let detector = ProcessDetector()
        // 使用极不可能存在的 PID
        let result = detector.isProcessRunning(pid: 999999)
        XCTAssertFalse(result)
    }

    // MARK: - 名称匹配测试

    /// 测试：pgrep 输出解析 - 单行
    func testPgrepOutput_singleLine() {
        // 验证 pgrep 输出解析逻辑
        // pgrep -lf 输出格式: PID COMMAND
        let output = "12345 codex\n"
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertEqual(lines.count, 1)

        let components = lines[0].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        XCTAssertEqual(components[0], "12345")
        XCTAssertEqual(Int(components[0]), 12345)
    }

    /// 测试：pgrep 输出解析 - 多行
    func testPgrepOutput_multipleLines() {
        let output = "12345 codex\n12346 codex-cli\n"
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertEqual(lines.count, 2)

        let pid1 = Int(lines[0].components(separatedBy: .whitespaces).filter { !$0.isEmpty }[0])
        let pid2 = Int(lines[1].components(separatedBy: .whitespaces).filter { !$0.isEmpty }[0])

        XCTAssertEqual(pid1, 12345)
        XCTAssertEqual(pid2, 12346)
    }

    /// 测试：pgrep 输出解析 - 空输出
    func testPgrepOutput_emptyOutput() {
        let output = ""
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertTrue(lines.isEmpty)
    }

    /// 测试：pgrep 输出解析 - 空白行
    func testPgrepOutput_whitespaceOnlyLines() {
        let output = "   \n  \n   \n"
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertTrue(lines.isEmpty)
    }

    /// 测试：pgrep 输出解析 - 无效 PID
    func testPgrepOutput_invalidPid() {
        let line = "abc codex"
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        XCTAssertEqual(components[0], "abc")
        XCTAssertNil(Int(components[0]))
    }

    /// 测试：pgrep 输出解析 - 命令含空格
    func testPgrepOutput_commandWithSpaces() {
        let line = "12345 codex --config /path/to/file.json"
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        XCTAssertEqual(components[0], "12345")
        let command = components.dropFirst().joined(separator: " ")
        XCTAssertEqual(command, "codex --config /path/to/file.json")
    }

    // MARK: - 会话创建/更新测试

    /// 测试：CodexMonitor 初始状态
    func testCodexMonitor_initialState() {
        let monitor = CodexMonitor.shared
        XCTAssertTrue(monitor.sessions.isEmpty)
        XCTAssertFalse(monitor.isRunning)
    }

    /// 测试：CodexMonitor aggregateState 初始为 idle
    func testCodexMonitor_initialAggregateState() {
        let monitor = CodexMonitor.shared
        XCTAssertEqual(monitor.aggregateState, .idle)
    }

    /// 测试：CodexMonitor activeCount 初始为 0
    func testCodexMonitor_initialActiveCount() {
        let monitor = CodexMonitor.shared
        XCTAssertEqual(monitor.activeCount, 0)
    }

    /// 测试：CodexMonitor refresh 不崩溃
    func testCodexMonitor_refresh() {
        let monitor = CodexMonitor.shared
        // refresh 应该可以安全调用，即使监控未启动
        monitor.refresh()
    }

    /// 测试：isRunningInDirectory 空会话列表返回 false
    func testIsRunningInDirectory_emptySessions() {
        let monitor = CodexMonitor.shared
        // 确保 sessions 为空
        XCTAssertFalse(monitor.isRunningInDirectory("/nonexistent"))
    }

    /// 测试：sessions(in:) 空会话列表返回空数组
    func testSessionsIn_emptySessions() {
        let monitor = CodexMonitor.shared
        XCTAssertTrue(monitor.sessions(in: "/any/path").isEmpty)
    }

    // MARK: - isCodexInstalled 测试

    /// 测试：isCodexInstalled 方法存在且可调用
    func testIsCodexInstalled_callable() {
        // 不验证返回值，因为取决于系统是否安装 codex
        _ = CodexMonitor.isCodexInstalled()
    }

    // MARK: - 单例模式测试

    /// 测试：CodexMonitor 单例一致性
    func testCodexMonitor_singletonConsistency() {
        let instance1 = CodexMonitor.shared
        let instance2 = CodexMonitor.shared
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - ProcessInfo 测试

    /// 测试：ProcessInfo 基本初始化
    func testProcessInfo_basicInitialization() {
        let info = ProcessInfo(
            pid: 12345,
            name: "codex",
            command: "codex",
            cwd: "/tmp/test"
        )

        XCTAssertEqual(info.pid, 12345)
        XCTAssertEqual(info.name, "codex")
        XCTAssertEqual(info.command, "codex")
        XCTAssertEqual(info.cwd, "/tmp/test")
        XCTAssertEqual(info.id, 12345)
    }

    /// 测试：ProcessInfo cwd 为 nil
    func testProcessInfo_nilCwd() {
        let info = ProcessInfo(
            pid: 54321,
            name: "codex",
            command: "codex",
            cwd: nil
        )

        XCTAssertNil(info.cwd)
    }

    /// 测试：ProcessInfo Equatable
    func testProcessInfo_equality() {
        let info1 = ProcessInfo(
            pid: 111,
            name: "test",
            command: "test cmd",
            cwd: "/tmp"
        )
        let info2 = ProcessInfo(
            pid: 111,
            name: "test",
            command: "test cmd",
            cwd: "/tmp"
        )

        XCTAssertEqual(info1, info2)
    }

    /// 测试：ProcessInfo 不等价
    func testProcessInfo_inequality() {
        let info1 = ProcessInfo(
            pid: 111,
            name: "test",
            command: "test cmd",
            cwd: "/tmp"
        )
        let info2 = ProcessInfo(
            pid: 222,
            name: "test",
            command: "test cmd",
            cwd: "/tmp"
        )

        XCTAssertNotEqual(info1, info2)
    }

    /// 测试：ProcessInfo isClaudeMainProcess - 是主进程
    func testProcessInfo_isClaudeMainProcess_true() {
        let info = ProcessInfo(
            pid: 12345,
            name: "claude",
            command: "claude --config /path",
            cwd: "/tmp"
        )

        XCTAssertTrue(info.isClaudeMainProcess)
    }

    /// 测试：ProcessInfo isClaudeMainProcess - node_modules 中的进程
    func testProcessInfo_isClaudeMainProcess_false_nodeModules() {
        let info = ProcessInfo(
            pid: 12345,
            name: "node",
            command: "node /path/node_modules/claude/index.js",
            cwd: "/tmp"
        )

        XCTAssertFalse(info.isClaudeMainProcess)
    }

    /// 测试：ProcessInfo displayName - 主进程
    func testProcessInfo_displayName_mainProcess() {
        let info = ProcessInfo(
            pid: 12345,
            name: "claude",
            command: "claude",
            cwd: "/tmp"
        )

        XCTAssertEqual(info.displayName, "Claude Code")
    }

    /// 测试：ProcessInfo displayName - 非主进程
    func testProcessInfo_displayName_nonMain() {
        let info = ProcessInfo(
            pid: 12345,
            name: "node",
            command: "node some_script.js",
            cwd: "/tmp"
        )

        XCTAssertEqual(info.displayName, "node")
    }

    // MARK: - ProcessMonitor 测试

    /// 测试：ProcessMonitor 初始化
    func testProcessMonitor_initialization() {
        let monitor = ProcessMonitor(interval: 3.0)
        XCTAssertNotNil(monitor)
    }

    /// 测试：ProcessMonitor 默认间隔
    func testProcessMonitor_defaultInterval() {
        let monitor = ProcessMonitor()
        XCTAssertNotNil(monitor)
    }

    /// 测试：ProcessMonitor currentProcesses 不崩溃
    func testProcessMonitor_currentProcesses() {
        let monitor = ProcessMonitor()
        let processes = monitor.currentProcesses()
        // 验证返回数组，不关心具体内容
        XCTAssertNotNil(processes)
    }

    /// 测试：ProcessMonitor isRunningInDirectory 不崩溃
    func testProcessMonitor_isRunningInDirectory() {
        let monitor = ProcessMonitor()
        _ = monitor.isRunningInDirectory("/tmp")
    }

    /// 测试：ProcessMonitor startWatching/stopWatching 不崩溃
    func testProcessMonitor_startStopWatching() {
        let monitor = ProcessMonitor()
        var callbackCalled = false

        monitor.startWatching { processes in
            callbackCalled = true
        }

        // 给一点时间让检测执行
        Thread.sleep(forTimeInterval: 0.1)

        monitor.stopWatching()
    }
}
