import Foundation
import OSLog

// MARK: - 进程检测服务

/// 检测和监控 Claude Code 进程状态
///
/// 功能：
/// - 使用 pgrep 检测 Claude Code 进程
/// - 获取进程 cwd 和工作目录
/// - 验证 Claude Code 是否正在运行
struct ProcessDetector {

    // MARK: - 单例

    static let shared = ProcessDetector()

    // MARK: - 常量
    
    /// Claude Code 进程名称
    static let claudeProcessNames = ["claude", "node"]
    
    /// 检测间隔（秒）
    static let defaultCheckInterval: TimeInterval = 5.0
    
    // MARK: - 日志
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "ProcessDetector"
    )
    
    // MARK: - 公开方法
    
    /// 检测 Claude Code 是否正在运行
    /// - Returns: 运行中的 Claude Code 进程信息列表
    func detectClaudeCodeProcesses() -> [ProcessInfo] {
        var results: [ProcessInfo] = []
        
        for processName in Self.claudeProcessNames {
            if let processes = runPgrep(processName: processName) {
                results.append(contentsOf: processes)
            }
        }
        
        return results
    }
    
    /// 检查是否有 Claude Code 进程运行在指定目录下
    /// - Parameter cwd: 工作目录路径
    /// - Returns: 匹配的进程信息
    func detectClaudeCodeInDirectory(_ cwd: String) -> [ProcessInfo] {
        let allProcesses = detectClaudeCodeProcesses()
        return allProcesses.filter { process in
            process.cwd?.contains(cwd) == true
        }
    }
    
    /// 获取指定进程的 cwd
    /// - Parameter pid: 进程 ID
    /// - Returns: 工作目录路径
    func getProcessCWD(pid: Int) -> String? {
        // macOS 上通过 /proc 不可用，使用 lsof 获取 cwd
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else { return nil }
            
            if let output = String(data: data, encoding: .utf8) {
                // 解析 lsof 输出，cwd 路径在 n 标记后
                let lines = output.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    if line.hasPrefix("n") && index > 0 {
                        return String(line.dropFirst())
                    }
                }
            }
        } catch {
            Self.logger.error("获取进程 cwd 失败: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// 检查 Claude Code 是否在指定目录下运行
    /// - Parameter cwd: 工作目录
    /// - Returns: 是否正在运行
    func isClaudeCodeRunningInDirectory(_ cwd: String) -> Bool {
        !detectClaudeCodeInDirectory(cwd).isEmpty
    }
    
    /// 获取所有 Claude Code 进程的工作目录
    /// - Returns: 工作目录集合
    func getAllWorkingDirectories() -> Set<String> {
        let processes = detectClaudeCodeProcesses()
        return Set(processes.compactMap(\.cwd))
    }
    
    // MARK: - 内部实现
    
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
            // pgrep -lf 输出格式: PID COMMAND
            let components = line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            guard components.count >= 2,
                  let pid = Int(components[0]) else {
                return nil
            }
            
            let command = components.dropFirst().joined(separator: " ")
            let cwd = getProcessCWD(pid: pid)
            
            return ProcessInfo(
                pid: pid,
                name: processName,
                command: command,
                cwd: cwd
            )
        }
    }
}

// MARK: - 进程信息

/// 进程信息结构
struct ProcessInfo: Identifiable, Equatable {
    /// 进程 ID
    let pid: Int
    /// 进程名称
    let name: String
    /// 完整命令行
    let command: String
    /// 工作目录
    let cwd: String?
    
    var id: Int { pid }
    
    /// 是否为 Claude Code 主进程
    var isClaudeMainProcess: Bool {
        command.contains("claude") && !command.contains("node_modules")
    }
    
    /// 简化的显示名称
    var displayName: String {
        if isClaudeMainProcess {
            return "Claude Code"
        }
        return name
    }
}

// MARK: - 进程监控器

/// 持续监控 Claude Code 进程状态的辅助类
@MainActor
final class ProcessMonitor {
    
    // MARK: - 属性
    
    /// 检测器实例
    private let detector = ProcessDetector()
    
    /// 检测定时器
    private var timer: Timer?
    
    /// 检测间隔
    private let interval: TimeInterval
    
    /// 进程变化回调
    private var onProcessChanged: (([ProcessInfo]) -> Void)?
    
    /// 上次检测到的进程列表
    private var lastProcesses: [ProcessInfo] = []
    
    // MARK: - 初始化
    
    /// 创建进程监控器
    /// - Parameter interval: 检测间隔（秒）
    init(interval: TimeInterval = ProcessDetector.defaultCheckInterval) {
        self.interval = interval
    }
    
    // MARK: - 公开方法
    
    /// 开始监控
    /// - Parameter callback: 进程变化时的回调
    func startWatching(onChanged: @escaping ([ProcessInfo]) -> Void) {
        stopWatching()
        onProcessChanged = onChanged
        
        // 立即执行一次检测
        detectAndNotify()
        
        // 设置定时器
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.detectAndNotify()
            }
        }
    }
    
    /// 停止监控
    func stopWatching() {
        timer?.invalidate()
        timer = nil
        onProcessChanged = nil
    }
    
    /// 获取当前 Claude Code 进程列表
    func currentProcesses() -> [ProcessInfo] {
        detector.detectClaudeCodeProcesses()
    }
    
    /// 检查指定目录是否有 Claude Code 运行
    func isRunningInDirectory(_ cwd: String) -> Bool {
        detector.isClaudeCodeRunningInDirectory(cwd)
    }
    
    // MARK: - 内部实现
    
    private func detectAndNotify() {
        let currentProcesses = detector.detectClaudeCodeProcesses()
        
        // 检测进程变化
        let hasChanged = currentProcesses.count != lastProcesses.count ||
            !zip(currentProcesses, lastProcesses).allSatisfy { $0 == $1 }
        
        if hasChanged {
            lastProcesses = currentProcesses
            onProcessChanged?(currentProcesses)
        }
    }
}
