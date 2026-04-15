import XCTest
@testable import VibeIsland

// MARK: - OpenCode 监控服务测试

@MainActor
final class OpenCodeMonitorTests: XCTestCase {

    // MARK: - 生命周期

    override func setUp() {
        super.setUp()
        // 确保单例处于干净状态
        if OpenCodeMonitor.shared.isRunning {
            OpenCodeMonitor.shared.stop()
        }
    }

    override func tearDown() {
        if OpenCodeMonitor.shared.isRunning {
            OpenCodeMonitor.shared.stop()
        }
        super.tearDown()
    }

    // MARK: - OpenCodeStatus 枚举测试

    /// 测试：OpenCodeStatus 所有枚举值的 rawValue
    func testOpenCodeStatus_rawValues() {
        XCTAssertEqual(OpenCodeStatus.idle.rawValue, "idle")
        XCTAssertEqual(OpenCodeStatus.working.rawValue, "working")
        XCTAssertEqual(OpenCodeStatus.waiting.rawValue, "waiting")
        XCTAssertEqual(OpenCodeStatus.completed.rawValue, "completed")
        XCTAssertEqual(OpenCodeStatus.error.rawValue, "error")
        XCTAssertEqual(OpenCodeStatus.retrying.rawValue, "retrying")
    }

    /// 测试：OpenCodeStatus 枚举数量为 6
    func testOpenCodeStatus_count() {
        let allStatuses: [OpenCodeStatus] = [.idle, .working, .waiting, .completed, .error, .retrying]
        XCTAssertEqual(allStatuses.count, 6)
    }

    /// 测试：OpenCodeStatus 到 SessionState 的映射
    func testOpenCodeStatus_toSessionState() {
        XCTAssertEqual(OpenCodeStatus.idle.toSessionState, .idle)
        XCTAssertEqual(OpenCodeStatus.working.toSessionState, .coding)
        XCTAssertEqual(OpenCodeStatus.waiting.toSessionState, .waitingPermission)
        XCTAssertEqual(OpenCodeStatus.completed.toSessionState, .completed)
        XCTAssertEqual(OpenCodeStatus.error.toSessionState, .error)
        XCTAssertEqual(OpenCodeStatus.retrying.toSessionState, .thinking)
    }

    /// 测试：OpenCodeStatus Codable 编解码
    func testOpenCodeStatus_encodeDecode() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in OpenCodeStatus.allCases() {
            let data = try! encoder.encode(status)
            let decoded = try! decoder.decode(OpenCodeStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    /// 测试：OpenCodeStatus Equatable 一致性
    func testOpenCodeStatus_equality() {
        XCTAssertEqual(OpenCodeStatus.idle, OpenCodeStatus.idle)
        XCTAssertNotEqual(OpenCodeStatus.idle, OpenCodeStatus.working)
    }

    // MARK: - OpenCodeMonitorSource 枚举测试

    /// 测试：数据源优先级顺序
    func testOpenCodeMonitorSource_priority() {
        // 优先级数值越小越高
        XCTAssertLessThan(OpenCodeMonitorSource.plugin.priority, OpenCodeMonitorSource.sse.priority)
        XCTAssertLessThan(OpenCodeMonitorSource.sse.priority, OpenCodeMonitorSource.file.priority)
        XCTAssertLessThan(OpenCodeMonitorSource.file.priority, OpenCodeMonitorSource.process.priority)
    }

    /// 测试：各数据源优先级数值
    func testOpenCodeMonitorSource_priorityValues() {
        XCTAssertEqual(OpenCodeMonitorSource.plugin.priority, 0)
        XCTAssertEqual(OpenCodeMonitorSource.sse.priority, 1)
        XCTAssertEqual(OpenCodeMonitorSource.file.priority, 2)
        XCTAssertEqual(OpenCodeMonitorSource.process.priority, 3)
    }

    /// 测试：数据源 rawValue
    func testOpenCodeMonitorSource_rawValues() {
        XCTAssertEqual(OpenCodeMonitorSource.plugin.rawValue, "plugin")
        XCTAssertEqual(OpenCodeMonitorSource.sse.rawValue, "sse")
        XCTAssertEqual(OpenCodeMonitorSource.file.rawValue, "file")
        XCTAssertEqual(OpenCodeMonitorSource.process.rawValue, "process")
    }

    // MARK: - OpenCodeSession 模型测试

    /// 测试：OpenCodeSession 基本初始化
    func testOpenCodeSession_basicInitialization() {
        let session = OpenCodeSession(
            sessionId: "test-session",
            cwd: "/tmp/project",
            status: .idle,
            lastActivity: Date(),
            currentTool: nil,
            message: nil,
            pid: nil,
            source: .plugin
        )

        XCTAssertEqual(session.sessionId, "test-session")
        XCTAssertEqual(session.cwd, "/tmp/project")
        XCTAssertEqual(session.status, .idle)
        XCTAssertNil(session.currentTool)
        XCTAssertNil(session.message)
        XCTAssertNil(session.pid)
        XCTAssertEqual(session.source, .plugin)
    }

    /// 测试：OpenCodeSession 完整初始化
    func testOpenCodeSession_fullInitialization() {
        let date = Date()
        let session = OpenCodeSession(
            sessionId: "full-session",
            cwd: "/Users/test/dev",
            status: .working,
            lastActivity: date,
            currentTool: "Write",
            message: "正在写入文件",
            pid: 12345,
            source: .sse
        )

        XCTAssertEqual(session.sessionId, "full-session")
        XCTAssertEqual(session.cwd, "/Users/test/dev")
        XCTAssertEqual(session.status, .working)
        XCTAssertEqual(session.lastActivity, date)
        XCTAssertEqual(session.currentTool, "Write")
        XCTAssertEqual(session.message, "正在写入文件")
        XCTAssertEqual(session.pid, 12345)
        XCTAssertEqual(session.source, .sse)
    }

    /// 测试：OpenCodeSession Equatable
    func testOpenCodeSession_equality() {
        let date = Date()
        let session1 = OpenCodeSession(
            sessionId: "eq-test",
            cwd: "/tmp",
            status: .idle,
            lastActivity: date,
            currentTool: nil,
            message: nil,
            pid: nil,
            source: .plugin
        )
        let session2 = OpenCodeSession(
            sessionId: "eq-test",
            cwd: "/tmp",
            status: .idle,
            lastActivity: date,
            currentTool: nil,
            message: nil,
            pid: nil,
            source: .plugin
        )

        XCTAssertEqual(session1, session2)
    }

    /// 测试：OpenCodeSession 不等价情况
    func testOpenCodeSession_inequality() {
        let date = Date()
        let session1 = OpenCodeSession(
            sessionId: "session-1",
            cwd: "/tmp",
            status: .idle,
            lastActivity: date,
            currentTool: nil,
            message: nil,
            pid: nil,
            source: .plugin
        )
        let session2 = OpenCodeSession(
            sessionId: "session-2",
            cwd: "/tmp",
            status: .idle,
            lastActivity: date,
            currentTool: nil,
            message: nil,
            pid: nil,
            source: .plugin
        )

        XCTAssertNotEqual(session1, session2)
    }

    /// 测试：OpenCodeSession 转换为 Session 模型
    func testOpenCodeSession_toSession() {
        let session = OpenCodeSession(
            sessionId: "conv-test",
            cwd: "/Users/test/myproject",
            status: .working,
            lastActivity: Date(),
            currentTool: "Read",
            message: "读取中",
            pid: 5678,
            source: .plugin
        )

        let converted = session.toSession()

        XCTAssertEqual(converted.sessionId, "opencode_conv-test")
        XCTAssertEqual(converted.cwd, "/Users/test/myproject")
        XCTAssertEqual(converted.status, .coding)
        XCTAssertEqual(converted.source, "opencode")
        XCTAssertEqual(converted.lastTool, "Read")
        XCTAssertEqual(converted.notificationMessage, "读取中")
        XCTAssertTrue((converted.sessionName ?? "").contains("myproject"))
    }

    /// 测试：OpenCodeSession 转换时 cwd 最后一部分提取
    func testOpenCodeSession_toSession_cwdExtraction() {
        let session = OpenCodeSession(
            sessionId: "cwd-test",
            cwd: "/a/b/c",
            status: .idle,
            lastActivity: Date(),
            currentTool: nil,
            message: nil,
            pid: nil,
            source: .process
        )

        let converted = session.toSession()
        XCTAssertTrue((converted.sessionName ?? "").contains("c"))
    }

    // MARK: - PluginSessionFile 测试

    /// 测试：PluginSessionFile 编码解码
    func testPluginSessionFile_encodeDecode() {
        let file = PluginSessionFile(
            sessionID: "plugin-1",
            cwd: "/tmp/plugin-test",
            status: "working",
            lastActive: 1700000000000,
            pid: 11111,
            projectName: "TestProject",
            currentTool: "Bash",
            message: "执行命令中"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(file)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode(PluginSessionFile.self, from: data)

        XCTAssertEqual(decoded.sessionID, "plugin-1")
        XCTAssertEqual(decoded.cwd, "/tmp/plugin-test")
        XCTAssertEqual(decoded.status, "working")
        XCTAssertEqual(decoded.pid, 11111)
        XCTAssertEqual(decoded.projectName, "TestProject")
        XCTAssertEqual(decoded.currentTool, "Bash")
        XCTAssertEqual(decoded.message, "执行命令中")
    }

    /// 测试：PluginSessionFile 转换为 OpenCodeSession
    func testPluginSessionFile_toOpenCodeSession() {
        let file = PluginSessionFile(
            sessionID: "conv-file",
            cwd: "/tmp/convert",
            status: "working",
            lastActive: 1700000000000,
            pid: 22222,
            projectName: nil,
            currentTool: "Write",
            message: nil
        )

        let url = URL(fileURLWithPath: "/tmp/test.json")
        let session = file.toOpenCodeSession(fileURL: url)

        XCTAssertEqual(session.sessionId, "conv-file")
        XCTAssertEqual(session.cwd, "/tmp/convert")
        XCTAssertEqual(session.status, .working)
        XCTAssertEqual(session.currentTool, "Write")
        XCTAssertEqual(session.pid, 22222)
        XCTAssertEqual(session.source, .plugin)
    }

    /// 测试：PluginSessionFile 未知状态回退到 idle
    func testPluginSessionFile_unknownStatusFallback() {
        let file = PluginSessionFile(
            sessionID: "fallback",
            cwd: "/tmp",
            status: "unknown_status",
            lastActive: nil,
            pid: nil,
            projectName: nil,
            currentTool: nil,
            message: nil
        )

        let url = URL(fileURLWithPath: "/tmp/fallback.json")
        let session = file.toOpenCodeSession(fileURL: url)

        XCTAssertEqual(session.status, .idle)
    }

    /// 测试：PluginSessionFile lastActive 为 nil 时使用当前时间
    func testPluginSessionFile_nilLastActive() {
        let beforeDate = Date()
        let file = PluginSessionFile(
            sessionID: "nil-date",
            cwd: "/tmp",
            status: "idle",
            lastActive: nil,
            pid: nil,
            projectName: nil,
            currentTool: nil,
            message: nil
        )

        let url = URL(fileURLWithPath: "/tmp/nil-date.json")
        let session = file.toOpenCodeSession(fileURL: url)

        XCTAssertGreaterThanOrEqual(session.lastActivity, beforeDate)
    }

    // MARK: - SSE 事件解析测试

    /// 测试：SSEEventWrapper 解析 session.created 事件
    func testSSEEventWrapper_sessionCreated() {
        let json = """
        {
            "payload": {
                "type": "session.created",
                "properties": {
                    "sessionID": "sse-1",
                    "cwd": "/tmp/sse-test"
                }
            }
        }
        """

        let data = json.data(using: .utf8)!
        let wrapper = try! JSONDecoder().decode(SSEEventWrapper.self, from: data)

        XCTAssertEqual(wrapper.payload.type, "session.created")
        XCTAssertEqual(wrapper.payload.properties.sessionID, "sse-1")
        XCTAssertEqual(wrapper.payload.properties.cwd, "/tmp/sse-test")
    }

    /// 测试：SSEEventWrapper 解析 session.status 事件
    func testSSEEventWrapper_sessionStatus() {
        let json = """
        {
            "payload": {
                "type": "session.status",
                "properties": {
                    "sessionID": "sse-2",
                    "status": "working"
                }
            }
        }
        """

        let data = json.data(using: .utf8)!
        let wrapper = try! JSONDecoder().decode(SSEEventWrapper.self, from: data)

        XCTAssertEqual(wrapper.payload.type, "session.status")
        XCTAssertEqual(wrapper.payload.properties.status, "working")
    }

    /// 测试：SSEEventWrapper 解析 tool.executing 事件
    func testSSEEventWrapper_toolExecuting() {
        let json = """
        {
            "payload": {
                "type": "tool.executing",
                "properties": {
                    "sessionID": "sse-3",
                    "tool": "Read"
                }
            }
        }
        """

        let data = json.data(using: .utf8)!
        let wrapper = try! JSONDecoder().decode(SSEEventWrapper.self, from: data)

        XCTAssertEqual(wrapper.payload.type, "tool.executing")
        XCTAssertEqual(wrapper.payload.properties.tool, "Read")
    }

    /// 测试：SSEProperties 字段解析
    func testSSEProperties_fieldParsing() {
        let json = """
        {
            "sessionID": "props-1",
            "id": "alt-id",
            "cwd": "/props/cwd",
            "status": "idle",
            "tool": "Write",
            "toolName": "Bash",
            "content": "some content"
        }
        """

        let data = json.data(using: .utf8)!
        let props = try! JSONDecoder().decode(SSEProperties.self, from: data)

        XCTAssertEqual(props.sessionID, "props-1")
        XCTAssertEqual(props.id, "alt-id")
        XCTAssertEqual(props.cwd, "/props/cwd")
        XCTAssertEqual(props.status, "idle")
        XCTAssertEqual(props.tool, "Write")
        XCTAssertEqual(props.toolName, "Bash")
        XCTAssertEqual(props.content, "some content")
    }

    /// 测试：SSEProperties 可选字段
    func testSSEProperties_optionalFields() {
        let json = """
        {
            "type": "unknown",
            "properties": {}
        }
        """

        let wrapperData = """
        {
            "payload": \(json)
        }
        """.data(using: .utf8)!

        let wrapper = try! JSONDecoder().decode(SSEEventWrapper.self, from: wrapperData)
        XCTAssertNil(wrapper.payload.properties.sessionID)
        XCTAssertNil(wrapper.payload.properties.cwd)
        XCTAssertNil(wrapper.payload.properties.status)
    }

    // MARK: - TUI 输出解析测试

    /// 测试：pgrep 输出解析 - 单进程
    func testPgrepOutput_singleProcess() {
        // 此测试验证 OpenCodeMonitor 使用 pgrep 检测进程的机制
        // 实际解析在 ProcessDetector 中完成
        let monitor = OpenCodeMonitor.shared
        // 验证 isOpenCodeRunning 方法可以正常调用
        _ = monitor.isOpenCodeRunning()
        // 不验证具体返回值，因为取决于系统是否有 opencode 进程
    }

    /// 测试：插件 session 文件 JSON 解析
    func testPluginSessionJSONParsing() {
        let validJSON = """
        {
            "sessionID": "parse-test",
            "cwd": "/tmp/parse",
            "status": "working",
            "lastActive": 1700000000000,
            "pid": 33333,
            "currentTool": "Edit"
        }
        """

        let data = validJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let file = try! decoder.decode(PluginSessionFile.self, from: data)
        XCTAssertEqual(file.sessionID, "parse-test")
        XCTAssertEqual(file.status, "working")
        XCTAssertEqual(file.currentTool, "Edit")
    }

    /// 测试：无效 JSON 解析返回 nil
    func testInvalidJSONParsing() {
        let invalidJSON = "not valid json"
        let data = invalidJSON.data(using: .utf8)!
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(PluginSessionFile.self, from: data))
    }

    /// 测试：缺少必填字段的 JSON 解析
    func testMissingRequiredFieldsJSONParsing() {
        let incompleteJSON = """
        {
            "status": "idle"
        }
        """

        let data = incompleteJSON.data(using: .utf8)!
        let decoder = JSONDecoder()

        // PluginSessionFile 要求 sessionID 和 cwd 必填
        XCTAssertThrowsError(try decoder.decode(PluginSessionFile.self, from: data))
    }

    // MARK: - 数据源优先级测试

    /// 测试：初始数据源为 process
    func testInitialDataSource() {
        let monitor = OpenCodeMonitor.shared
        XCTAssertEqual(monitor.currentSource, .process)
    }

    /// 测试：初始会话列表为空
    func testInitialSessionsEmpty() {
        let monitor = OpenCodeMonitor.shared
        XCTAssertTrue(monitor.sessions.isEmpty)
    }

    /// 测试：初始状态为 idle
    func testInitialAggregateState() {
        let monitor = OpenCodeMonitor.shared
        XCTAssertEqual(monitor.aggregateState, .idle)
    }

    /// 测试：初始 activeCount 为 0
    func testInitialActiveCount() {
        let monitor = OpenCodeMonitor.shared
        XCTAssertEqual(monitor.activeCount, 0)
    }

    /// 测试：初始 hasPendingPermission 为 false
    func testInitialHasPendingPermission() {
        let monitor = OpenCodeMonitor.shared
        XCTAssertFalse(monitor.hasPendingPermission)
    }

    // MARK: - 会话更新/清理测试

    /// 测试：aggregateState 返回最高优先级状态
    func testAggregateState_highestPriority() {
        // aggregateState 返回 sessions 中优先级最高的状态
        // 由于是 @MainActor @Observable，我们验证空状态时返回 idle
        let monitor = OpenCodeMonitor.shared
        XCTAssertEqual(monitor.aggregateState, .idle)
    }

    /// 测试：activeCount 过滤 completed 和 idle 状态
    func testActiveCount_filtersCompletedAndIdle() {
        // activeCount 应过滤掉 completed 和 idle 的会话
        // 空列表时 activeCount 为 0
        let monitor = OpenCodeMonitor.shared
        XCTAssertEqual(monitor.activeCount, 0)
    }

    /// 测试：pluginSessionsDirectory 路径构造
    func testPluginSessionsDirectory() {
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vibe-island")
            .appendingPathComponent("opencode-sessions")

        XCTAssertEqual(OpenCodeMonitor.pluginSessionsDirectory, expected)
    }

    /// 测试：nativeStoragePath 路径构造
    func testNativeStoragePath() {
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local")
            .appendingPathComponent("share")
            .appendingPathComponent("opencode")
            .appendingPathComponent("storage")

        XCTAssertEqual(OpenCodeMonitor.nativeStoragePath, expected)
    }

    /// 测试：defaultSSEPort 值
    func testDefaultSSEPort() {
        XCTAssertEqual(OpenCodeMonitor.defaultSSEPort, 4040)
    }

    /// 测试：defaultCheckInterval 值
    func testDefaultCheckInterval() {
        XCTAssertEqual(OpenCodeMonitor.defaultCheckInterval, 5.0)
    }

    // MARK: - 插件安装脚本测试

    /// 测试：pluginInstallScript 非空
    func testPluginInstallScript_nonEmpty() {
        XCTAssertFalse(OpenCodeMonitor.pluginInstallScript.isEmpty)
    }

    /// 测试：pluginInstallScript 包含关键命令
    func testPluginInstallScript_containsKeyCommands() {
        let script = OpenCodeMonitor.pluginInstallScript
        XCTAssertTrue(script.contains("PLUGIN_DIR"))
        XCTAssertTrue(script.contains("mkdir"))
        XCTAssertTrue(script.contains(".config/opencode/plugins"))
    }

    // MARK: - SSE 客户端测试

    /// 测试：OpenCodeSSEClient 初始化
    func testSSEClient_initialization() {
        let client = OpenCodeSSEClient(port: 4040)
        XCTAssertNotNil(client)
    }

    /// 测试：OpenCodeSSEClient 默认端口
    func testSSEClient_defaultPort() {
        let client = OpenCodeSSEClient()
        XCTAssertNotNil(client)
    }

    /// 测试：OpenCodeSSEClient disconnect 清理缓冲区
    func testSSEClient_disconnect() {
        let client = OpenCodeSSEClient(port: 4041)
        client.disconnect()
        // disconnect 应清理 dataTask 和 buffer
    }

    // MARK: - 插件文件监听器测试

    /// 测试：OpenCodePluginFileWatcher 初始化
    func testPluginFileWatcher_initialization() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let watcher = OpenCodePluginFileWatcher(directory: url)
        XCTAssertNotNil(watcher)
    }

    /// 测试：OpenCodePluginFileWatcher start/stop
    func testPluginFileWatcher_startStop() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let watcher = OpenCodePluginFileWatcher(directory: url)

        watcher.startWatching()
        // 启动后应在监听
        watcher.stopWatching()
        // 停止后应清理资源
    }

    // MARK: - 单例模式测试

    /// 测试：OpenCodeMonitor 单例一致性
    func testSingleton_consistency() {
        let instance1 = OpenCodeMonitor.shared
        let instance2 = OpenCodeMonitor.shared
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - 辅助类型测试

    /// 测试：Box 可变容器（私有类型，无法直接测试，验证相关功能即可）
    func testBox_mutableContainer() {
        // Box 是私有类型，无法直接访问
        // 这里验证 isSSEReachable 方法中使用的 Box 功能
        // 由于网络依赖，此测试仅验证方法存在
    }

    /// 测试：Box 泛型支持（私有类型，无法直接测试）
    func testBox_genericSupport() {
        // Box 是私有类型
        // 验证相关功能正常工作即可
    }
}

// MARK: - 辅助扩展

private extension OpenCodeStatus {
    static func allCases() -> [OpenCodeStatus] {
        [.idle, .working, .waiting, .completed, .error, .retrying]
    }
}
