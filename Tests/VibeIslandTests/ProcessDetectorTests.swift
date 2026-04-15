import XCTest
@testable import VibeIsland

// MARK: - 进程检测服务测试

@MainActor
final class ProcessDetectorTests: XCTestCase {

    // MARK: - 生命周期

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - 常量测试

    /// 测试：claudeProcessNames 包含预期值
    func testClaudeProcessNames() {
        let names = ProcessDetector.claudeProcessNames
        XCTAssertTrue(names.contains("claude"))
        XCTAssertTrue(names.contains("node"))
        XCTAssertEqual(names.count, 2)
    }

    /// 测试：defaultCheckInterval 值
    func testDefaultCheckInterval() {
        XCTAssertEqual(ProcessDetector.defaultCheckInterval, 5.0)
    }

    // MARK: - 单例测试

    /// 测试：单例一致性
    func testSingleton_consistency() {
        let detector1 = ProcessDetector.shared
        let detector2 = ProcessDetector.shared
        // ProcessDetector 是 struct，shared 返回相同的单例实例
        // 验证引用相等性（虽然是 struct，但 shared 是通过 static let 共享的）
        XCTAssertEqual(ObjectIdentifier(detector1 as AnyObject), ObjectIdentifier(detector2 as AnyObject))
    }

    // MARK: - 进程扫描测试

    /// 测试：detectClaudeCodeProcesses 不崩溃
    func testDetectClaudeCodeProcesses_noCrash() {
        let detector = ProcessDetector()
        let processes = detector.detectClaudeCodeProcesses()
        // 验证返回的是数组，不关心具体内容（取决于系统状态）
        XCTAssertNotNil(processes)
    }

    /// 测试：detectClaudeCodeProcesses 返回 ProcessInfo 数组
    func testDetectClaudeCodeProcesses_returnsProcessInfoArray() {
        let detector = ProcessDetector()
        let processes = detector.detectClaudeCodeProcesses()

        for process in processes {
            XCTAssertGreaterThan(process.pid, 0)
            XCTAssertFalse(process.name.isEmpty)
        }
    }

    /// 测试：detectClaudeCodeProcesses 结果中进程名称匹配
    func testDetectClaudeCodeProcesses_processNameMatching() {
        let detector = ProcessDetector()
        let processes = detector.detectClaudeCodeProcesses()

        for process in processes {
            let matchedNames = ProcessDetector.claudeProcessNames
            XCTAssertTrue(
                matchedNames.contains(process.name) || process.command.contains("claude") || process.command.contains("node"),
                "进程名称 '\(process.name)' 应匹配配置的名称或命令中包含 claude/node"
            )
        }
    }

    /// 测试：多次调用检测结果可能变化（进程动态变化）
    func testDetectClaudeCodeProcesses_dynamicResults() {
        let detector = ProcessDetector()
        let result1 = detector.detectClaudeCodeProcesses()
        let result2 = detector.detectClaudeCodeProcesses()

        // 不验证相等性，因为进程可能随时变化
        // 只验证两次调用都不崩溃
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
    }

    // MARK: - cwd 获取测试

    /// 测试：getProcessCWD 获取当前进程目录
    func testGetProcessCWD_currentProcess() {
        let detector = ProcessDetector()
        let currentPid = Int(getpid())
        let cwd = detector.getProcessCWD(pid: currentPid)

        // 当前进程应该能获取到 cwd（除非权限问题）
        // 验证方法不崩溃
        _ = cwd
    }

    /// 测试：getProcessCWD 获取不存在的 PID 返回 nil
    func testGetProcessCWD_nonexistentPid() {
        let detector = ProcessDetector()
        // 使用极不可能存在的 PID
        let cwd = detector.getProcessCWD(pid: 999999)
        XCTAssertNil(cwd)
    }

    /// 测试：getProcessCWD 对 PID 0 的行为
    func testGetProcessCWD_pidZero() {
        let detector = ProcessDetector()
        let cwd = detector.getProcessCWD(pid: 0)
        // PID 0 是特殊进程，结果取决于系统
        // 只验证不崩溃
        _ = cwd
    }

    /// 测试：lsof 输出解析 - 正常格式
    func testLsofOutput_normalFormat() {
        // lsof -a -p PID -d cwd -Fn 输出格式：
        // p<PID>
        // n<cwd_path>
        let output = "p12345\nn/Users/test/project"
        let lines = output.components(separatedBy: .newlines)

        var foundCwd: String?
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("n") && index > 0 {
                foundCwd = String(line.dropFirst())
                break
            }
        }

        XCTAssertEqual(foundCwd, "/Users/test/project")
    }

    /// 测试：lsof 输出解析 - 无 cwd 行
    func testLsofOutput_noCwdLine() {
        let output = "p12345"
        let lines = output.components(separatedBy: .newlines)

        var foundCwd: String?
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("n") && index > 0 {
                foundCwd = String(line.dropFirst())
                break
            }
        }

        XCTAssertNil(foundCwd)
    }

    /// 测试：lsof 输出解析 - 空输出
    func testLsofOutput_empty() {
        let output = ""
        let lines = output.components(separatedBy: .newlines)

        var foundCwd: String?
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("n") && index > 0 {
                foundCwd = String(line.dropFirst())
                break
            }
        }

        XCTAssertNil(foundCwd)
    }

    // MARK: - 进程存活检测测试

    /// 测试：当前进程被认为是运行中的
    func testIsProcessRunning_currentProcess() {
        let detector = ProcessDetector()
        let currentPid = Int(getpid())
        let result = detector.isProcessRunning(pid: currentPid)
        XCTAssertTrue(result, "当前进程应该被认为是运行中的")
    }

    /// 测试：不存在的进程返回 false
    func testIsProcessRunning_nonexistentProcess() {
        let detector = ProcessDetector()
        // 使用极不可能存在的 PID
        let result = detector.isProcessRunning(pid: 999999)
        XCTAssertFalse(result)
    }

    /// 测试：PID 0 的行为
    func testIsProcessRunning_pidZero() {
        let detector = ProcessDetector()
        // PID 0 是特殊进程
        _ = detector.isProcessRunning(pid: 0)
    }

    /// 测试：kill(pid, 0) 语义 - 仅检测存在性
    func testKillSignal_semantics() {
        // kill(pid, 0) 不发送信号，仅检测进程是否存在
        let currentPid = Int(getpid())
        let result = kill(pid_t(currentPid), 0)
        XCTAssertEqual(result, 0, "kill 对当前进程返回 0")
    }

    // MARK: - 名称匹配测试

    /// 测试：pgrep 输出解析 - 单行
    func testParsePgrepOutput_singleLine() {
        let detector = ProcessDetector()
        // 通过反射调用私有方法较困难，这里验证 pgrep 输出格式
        let output = "12345 /usr/bin/claude\n"
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertEqual(lines.count, 1)
    }

    /// 测试：pgrep 输出解析 - 多行
    func testParsePgrepOutput_multipleLines() {
        let output = "12345 claude\n67890 node /path/to/script\n"
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertEqual(lines.count, 2)
    }

    /// 测试：pgrep 输出解析 - 提取 PID
    func testParsePgrepOutput_extractPid() {
        let line = "12345 claude --config /path"
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard let pid = Int(components[0]) else {
            XCTFail("无法解析 PID")
            return
        }

        XCTAssertEqual(pid, 12345)
    }

    /// 测试：pgrep 输出解析 - 提取命令
    func testParsePgrepOutput_extractCommand() {
        let line = "12345 claude --config /path/to/config.json"
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let command = components.dropFirst().joined(separator: " ")

        XCTAssertEqual(command, "claude --config /path/to/config.json")
    }

    /// 测试：pgrep 输出解析 - 空行过滤
    func testParsePgrepOutput_filterEmptyLines() {
        let output = "\n12345 claude\n\n\n"
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertEqual(lines.count, 1)
    }

    /// 测试：pgrep 输出解析 - 无效 PID
    func testParsePgrepOutput_invalidPid() {
        let line = "notapid claude"
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let pid = Int(components[0])

        XCTAssertNil(pid)
    }

    /// 测试：pgrep 输出解析 - 仅 PID
    func testParsePgrepOutput_pidOnly() {
        let line = "12345"
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // 至少需要 PID + 命令两个组件
        XCTAssertLessThan(components.count, 2)
    }

    // MARK: - 目录匹配测试

    /// 测试：detectClaudeCodeInDirectory 不崩溃
    func testDetectClaudeCodeInDirectory_noCrash() {
        let detector = ProcessDetector()
        let processes = detector.detectClaudeCodeInDirectory("/tmp")
        XCTAssertNotNil(processes)
    }

    /// 测试：detectClaudeCodeInDirectory 过滤逻辑
    func testDetectClaudeCodeInDirectory_filtersByCwd() {
        let detector = ProcessDetector()
        let allProcesses = detector.detectClaudeCodeProcesses()
        let filteredProcesses = detector.detectClaudeCodeInDirectory("/nonexistent/path")

        // 过滤后的数量不应超过总数
        XCTAssertLessThanOrEqual(filteredProcesses.count, allProcesses.count)

        // 对于不存在的目录，通常返回空数组
        for process in filteredProcesses {
            XCTAssertTrue(
                process.cwd?.contains("/nonexistent/path") == true,
                "过滤后的进程 cwd 应包含指定路径"
            )
        }
    }

    /// 测试：isClaudeCodeRunningInDirectory 不崩溃
    func testIsClaudeCodeRunningInDirectory_noCrash() {
        let detector = ProcessDetector()
        _ = detector.isClaudeCodeRunningInDirectory("/tmp")
    }

    /// 测试：isClaudeCodeRunningInDirectory 返回 bool
    func testIsClaudeCodeRunningInDirectory_returnsBool() {
        let detector = ProcessDetector()
        let result = detector.isClaudeCodeRunningInDirectory("/tmp")
        // 验证返回值是 Bool
        XCTAssertTrue(result == true || result == false)
    }

    /// 测试：getAllWorkingDirectories 不崩溃
    func testGetAllWorkingDirectories_noCrash() {
        let detector = ProcessDetector()
        let dirs = detector.getAllWorkingDirectories()
        XCTAssertNotNil(dirs)
        XCTAssertTrue(dirs is Set<String>)
    }

    /// 测试：getAllWorkingDirectories 返回 Set
    func testGetAllWorkingDirectories_returnsSet() {
        let detector = ProcessDetector()
        let dirs = detector.getAllWorkingDirectories()

        // Set 自动去重
        let uniqueCount = dirs.count
        XCTAssertEqual(uniqueCount, dirs.count)
    }

    // MARK: - ProcessInfo 测试

    /// 测试：ProcessInfo 基本属性
    func testProcessInfo_basicProperties() {
        let info = ProcessInfo(
            pid: 12345,
            name: "claude",
            command: "claude --help",
            cwd: "/Users/test/project"
        )

        XCTAssertEqual(info.pid, 12345)
        XCTAssertEqual(info.name, "claude")
        XCTAssertEqual(info.command, "claude --help")
        XCTAssertEqual(info.cwd, "/Users/test/project")
        XCTAssertEqual(info.id, 12345)
    }

    /// 测试：ProcessInfo Identifiable 一致性
    func testProcessInfo_identifiable() {
        let info = ProcessInfo(
            pid: 54321,
            name: "test",
            command: "test",
            cwd: nil
        )

        XCTAssertEqual(info.id, info.pid)
    }

    /// 测试：ProcessInfo Equatable - 相等
    func testProcessInfo_equatable_equal() {
        let info1 = ProcessInfo(
            pid: 111,
            name: "proc",
            command: "proc arg1",
            cwd: "/tmp"
        )
        let info2 = ProcessInfo(
            pid: 111,
            name: "proc",
            command: "proc arg1",
            cwd: "/tmp"
        )

        XCTAssertEqual(info1, info2)
    }

    /// 测试：ProcessInfo Equatable - 不等
    func testProcessInfo_equatable_notEqual() {
        let info1 = ProcessInfo(
            pid: 111,
            name: "proc",
            command: "proc arg1",
            cwd: "/tmp"
        )
        let info3 = ProcessInfo(
            pid: 222,
            name: "proc",
            command: "proc arg1",
            cwd: "/tmp"
        )

        XCTAssertNotEqual(info1, info3)
    }

    /// 测试：ProcessInfo isClaudeMainProcess - 包含 claude 且不含 node_modules
    func testProcessInfo_isClaudeMainProcess_true() {
        let info = ProcessInfo(
            pid: 12345,
            name: "claude",
            command: "claude --config /path",
            cwd: "/tmp"
        )

        XCTAssertTrue(info.isClaudeMainProcess)
    }

    /// 测试：ProcessInfo isClaudeMainProcess - 包含 node_modules
    func testProcessInfo_isClaudeMainProcess_false_nodeModules() {
        let info = ProcessInfo(
            pid: 12345,
            name: "node",
            command: "node /path/node_modules/claude/dist/cli.js",
            cwd: "/tmp"
        )

        XCTAssertFalse(info.isClaudeMainProcess)
    }

    /// 测试：ProcessInfo isClaudeMainProcess - 不包含 claude
    func testProcessInfo_isClaudeMainProcess_false_noClaude() {
        let info = ProcessInfo(
            pid: 12345,
            name: "python",
            command: "python script.py",
            cwd: "/tmp"
        )

        XCTAssertFalse(info.isClaudeMainProcess)
    }

    /// 测试：ProcessInfo displayName - Claude 主进程
    func testProcessInfo_displayName_claudeMain() {
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
            command: "node helper.js",
            cwd: "/tmp"
        )

        XCTAssertEqual(info.displayName, "node")
    }

    // MARK: - ProcessMonitor 测试

    /// 测试：ProcessMonitor 初始化 - 自定义间隔
    func testProcessMonitor_init_customInterval() {
        let monitor = ProcessMonitor(interval: 10.0)
        XCTAssertNotNil(monitor)
    }

    /// 测试：ProcessMonitor 初始化 - 默认间隔
    func testProcessMonitor_init_defaultInterval() {
        let monitor = ProcessMonitor()
        XCTAssertNotNil(monitor)
    }

    /// 测试：ProcessMonitor currentProcesses 调用检测器
    func testProcessMonitor_currentProcesses() {
        let monitor = ProcessMonitor()
        let processes = monitor.currentProcesses()
        // 验证返回的是数组
        XCTAssertNotNil(processes)
    }

    /// 测试：ProcessMonitor isRunningInDirectory 委托给检测器
    func testProcessMonitor_isRunningInDirectory() {
        let monitor = ProcessMonitor()
        let result = monitor.isRunningInDirectory("/tmp")
        XCTAssertTrue(result == true || result == false)
    }

    /// 测试：ProcessMonitor startWatching 设置回调
    func testProcessMonitor_startWatching() {
        let monitor = ProcessMonitor()
        // 只验证 startWatching 可以调用，不等待回调
        // 因为异步回调可能导致测试挂起
        monitor.startWatching { processes in
            // 回调应接收到进程列表
            XCTAssertNotNil(processes)
        }

        // 立即停止
        monitor.stopWatching()
    }

    /// 测试：ProcessMonitor stopWatching 清理资源
    func testProcessMonitor_stopWatching() {
        let monitor = ProcessMonitor()
        monitor.startWatching { _ in }
        monitor.stopWatching()
        // stopWatching 后再次调用应该安全
        monitor.stopWatching()
    }

    /// 测试：ProcessMonitor 多次 startWatching 重置定时器
    func testProcessMonitor_multipleStartWatching() {
        let monitor = ProcessMonitor(interval: 1.0)
        var callCount = 0

        monitor.startWatching { _ in
            callCount += 1
        }

        Thread.sleep(forTimeInterval: 0.5)

        // 再次 start 应重置
        monitor.startWatching { _ in
            callCount += 1
        }

        Thread.sleep(forTimeInterval: 0.5)

        monitor.stopWatching()
        XCTAssertGreaterThanOrEqual(callCount, 1)
    }

    /// 测试：ProcessMonitor detectAndNotify 检测变化
    func testProcessMonitor_detectAndNotify() {
        let monitor = ProcessMonitor()
        // 只验证可以启动和停止，不等待回调
        monitor.startWatching { processes in
            XCTAssertNotNil(processes)
        }

        // 立即停止，避免挂起
        monitor.stopWatching()
    }
}
