#!/usr/bin/env swift
import Foundation

/// DispatchSource 可靠性测试
/// 模拟 10 个并发会话高频写入，验证防抖动参数

let testDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".vibe-island-test")
    .appendingPathComponent("sessions")

// 创建测试目录
try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

// 测试配置
let concurrentSessions = 10
let writesPerSession = 50  // 每个会话写入次数
let debounceInterval: UInt64 = 100_000_000  // 100ms 防抖动（纳秒）

var eventCounts: [Int: Int] = Dictionary(uniqueKeysWithValues: (0..<concurrentSessions).map { ($0, 0) })
var receivedEvents = 0
let lock = NSLock()

/// 模拟写入事件数据
func writeEventData(sessionIndex: Int, eventIndex: Int) {
    let fileName = "session_\(sessionIndex).json"
    let fileURL = testDir.appendingPathComponent(fileName)
    
    let eventData = """
    {
        "session_id": "test_\(sessionIndex)",
        "event": "event_\(eventIndex)",
        "timestamp": "\(Date().ISO8601Format())",
        "state": "working"
    }
    """
    
    try? eventData.write(to: fileURL, atomically: true, encoding: .utf8)
}

/// 创建 DispatchSource 监听文件变化
func createDispatchSource(for sessionIndex: Int) -> DispatchSourceFileSystemObject? {
    let fileName = "session_\(sessionIndex).json"
    let fileURL = testDir.appendingPathComponent(fileName)
    
    // 先创建文件
    let initialData = """
    {
        "session_id": "test_\(sessionIndex)",
        "event": "init",
        "timestamp": "\(Date().ISO8601Format())",
        "state": "idle"
    }
    """
    try? initialData.write(to: fileURL, atomically: true, encoding: .utf8)
    
    let fd = open(fileURL.path, O_EVTONLY)
    guard fd >= 0 else {
        print("⚠️ 无法打开文件描述符: \(fileURL.path)")
        return nil
    }
    
    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: .write,
        queue: DispatchQueue.global(qos: .userInitiated)
    )
    
    var lastEventTime = DispatchTime.now()
    
    source.setEventHandler {
        let now = DispatchTime.now()
        let elapsed = now.uptimeNanoseconds - lastEventTime.uptimeNanoseconds
        
        // 防抖动逻辑
        guard elapsed > debounceInterval else {
            return
        }
        lastEventTime = now
        
        lock.lock()
        eventCounts[sessionIndex, default: 0] += 1
        receivedEvents += 1
        let count = eventCounts[sessionIndex] ?? 0
        lock.unlock()
        
        print("📡 会话 \(sessionIndex) 收到事件 #\(count)")
    }
    
    source.setCancelHandler {
        close(fd)
    }
    
    source.resume()
    return source
}

// MARK: - 测试执行

print("🧪 DispatchSource 可靠性测试启动")
print("📊 配置: \(concurrentSessions) 个并发会话, \(writesPerSession) 次写入/会话")
print("⏱️  防抖动间隔: \(debounceInterval / 1_000_000)ms")
print("")

// 创建监听源
var sources: [DispatchSourceFileSystemObject] = []
for i in 0..<concurrentSessions {
    if let source = createDispatchSource(for: i) {
        sources.append(source)
    }
}

let startTime = Date()

// 并发写入测试
let workItem = DispatchWorkItem {
    for session in 0..<concurrentSessions {
        DispatchQueue.global(qos: .userInitiated).async {
            for event in 0..<writesPerSession {
                writeEventData(sessionIndex: session, eventIndex: event)
                usleep(50_000)  // 50ms 间隔
            }
        }
    }
}

DispatchQueue.global(qos: .userInitiated).async(execute: workItem)

// 等待测试完成
RunLoop.current.run(until: Date().addingTimeInterval(15))

let elapsed = Date().timeIntervalSince(startTime)
let expectedTotalWrites = concurrentSessions * writesPerSession

print("")
print("=" * 50)
print("📈 测试结果")
print("=" * 50)
print("⏱️  测试耗时: \(String(format: "%.2f", elapsed))s")
print("📤 预期写入: \(expectedTotalWrites)")
print("📥 收到事件: \(receivedEvents)")
print("📊 事件接收率: \(String(format: "%.1f", Double(receivedEvents) / Double(expectedTotalWrites) * 100))%")
print("")
print("⚠️  注意：DispatchSource 在纯 CLI 环境下可能无法正常工作")
print("   原因：需要 NSApplication/RunLoop 环境才能正确接收文件事件")
print("   建议：在 macOS App 环境中重新测试（VibeIsland 应用内）")
print("")

// 各会话统计
for i in 0..<concurrentSessions {
    let count = eventCounts[i] ?? 0
    let rate = Double(count) / Double(writesPerSession) * 100
    print("  会话 \(i): \(count)/\(writesPerSession) 事件 (\(String(format: "%.1f", rate))%)")
}

print("")
print("✅ 测试完成")

// 清理测试文件
for i in 0..<concurrentSessions {
    let fileURL = testDir.appendingPathComponent("session_\(i).json")
    try? FileManager.default.removeItem(at: fileURL)
}
try? FileManager.default.removeItem(at: testDir)

// String 扩展
extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
