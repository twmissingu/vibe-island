import Foundation
import OSLog

// MARK: - Codex 会话状态

/// Codex CLI 运行状态
enum CodexStatus: String, Codable, Equatable, Sendable {
    case idle               // 空闲
    case running            // 运行中
    case completed          // 已完成
    case error              // 错误

    /// 映射到 SessionState
    var toSessionState: SessionState {
        switch self {
        case .idle: return .idle
        case .running: return .coding
        case .completed: return .completed
        case .error: return .error
        }
    }
}

// MARK: - Codex 会话模型

/// Codex 进程快照
struct CodexSession: Equatable, Sendable {
    /// 从 PID 衍生的会话 ID
    let sessionId: String
    /// 进程 ID
    let pid: Int
    /// 工作目录
    let cwd: String?
    /// 运行状态
    var status: CodexStatus
    /// 完整命令行
    let command: String
    /// 最后检测时间
    let lastCheck: Date

    /// 转换为 Session 模型
    func toSession() -> Session {
        let displayCwd = cwd ?? "unknown"
        return Session(
            sessionId: "codex_\(sessionId)",
            cwd: displayCwd,
            status: status.toSessionState,
            lastActivity: lastCheck,
            source: "codex",
            sessionName: "Codex: \(displayCwd.split(separator: "/").last?.description ?? displayCwd)"
        )
    }
}

// MARK: - Codex 监控服务

/// Codex 监控服务
///
/// 使用 pgrep 检测 Codex 进程，获取工作目录和基础运行状态。
/// Codex CLI 不提供类似 Claude Code 的 hook 机制或 SSE 接口，
/// 因此本服务仅支持进程级别的检测。
@MainActor
@Observable
final class CodexMonitor {

    // MARK: 常量

    /// Codex 进程名称
    static let codexProcessNames = ["codex", "codex-cli"]

    /// 检测间隔（秒）
    static let defaultCheckInterval: TimeInterval = 5.0

    // MARK: 单例

    static let shared = CodexMonitor()

    // MARK: 公开状态

    /// 当前检测到的 Codex 进程
    private(set) var sessions: [CodexSession] = []

    /// 监控是否已启动
    private(set) var isRunning = false

    /// 最高优先级会话状态
    var aggregateState: SessionState {
        sessions
            .map(\.status)
            .map { $0.toSessionState }
            .min(by: { $0.priority < $1.priority })
            ?? .idle
    }

    /// 活跃进程数量
    var activeCount: Int {
        sessions.filter { $0.status == .running }.count
    }

    // MARK: 内部依赖

    private let processDetector = ProcessDetector()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "CodexMonitor"
    )

    // MARK: 内部状态

    private var checkTimer: Timer?
    private var hasSetup = false

    // MARK: 初始化

    private init() {}

    // MARK: 生命周期

    /// 启动监控
    func start() {
        guard !hasSetup else { return }
        hasSetup = true
        isRunning = true

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: Self.defaultCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkProcesses()
            }
        }

        // 立即执行一次
        checkProcesses()

        Self.logger.info("CodexMonitor 已启动")
    }

    /// 停止监控
    func stop() {
        hasSetup = false
        isRunning = false

        checkTimer?.invalidate()
        checkTimer = nil

        sessions.removeAll()

        Self.logger.info("CodexMonitor 已停止")
    }

    /// 手动刷新
    func refresh() {
        checkProcesses()
    }

    // MARK: 进程检测

    /// 检测所有 Codex 进程
    private func checkProcesses() {
        let codexSessions = detectCodexProcesses()

        // 仅在内容变化时更新
        let hasChanged = codexSessions.count != sessions.count ||
            !zip(codexSessions, sessions).allSatisfy { $0.sessionId == $1.sessionId && $0.status == $1.status }

        if hasChanged {
            sessions = codexSessions
        }
    }

    /// 使用 pgrep 检测 Codex 进程
    private func detectCodexProcesses() -> [CodexSession] {
        var results: [CodexSession] = []

        for processName in Self.codexProcessNames {
            if let processes = runPgrep(processName: processName) {
                for process in processes {
                    let session = CodexSession(
                        sessionId: String(process.pid),
                        pid: process.pid,
                        cwd: process.cwd,
                        status: .running,
                        command: process.command,
                        lastCheck: Date()
                    )
                    results.append(session)
                }
            }
        }

        return results
    }

    /// 运行 pgrep 命令
    private func runPgrep(processName: String) -> [ProcessInfo]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-lf", processName]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            guard let output = String(data: data, encoding: .utf8) else { return nil }

            return parsePgrepOutput(output, processName: processName)
        } catch {
            Self.logger.error("pgrep 执行失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 解析 pgrep 输出
    private func parsePgrepOutput(_ output: String, processName: String) -> [ProcessInfo] {
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return lines.compactMap { line -> ProcessInfo? in
            let components = line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard components.count >= 2,
                  let pid = Int(components[0]) else {
                return nil
            }

            let command = components.dropFirst().joined(separator: " ")
            let cwd = processDetector.getProcessCWD(pid: pid)

            return ProcessInfo(
                pid: pid,
                name: processName,
                command: command,
                cwd: cwd
            )
        }
    }

    // MARK: 查询方法

    /// 检查 Codex 是否在指定目录下运行
    func isRunningInDirectory(_ cwd: String) -> Bool {
        sessions.contains { session in
            session.cwd?.contains(cwd) == true
        }
    }

    /// 获取指定目录下的 Codex 会话
    func sessions(in cwd: String) -> [CodexSession] {
        sessions.filter { $0.cwd?.contains(cwd) == true }
    }

    /// 检测 Codex 是否安装
    static func isCodexInstalled() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["codex"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
