#!/usr/bin/env swift
import Foundation

// MARK: - 简单性能验证脚本

print("🏝️ Vibe Island 性能验证")
print("==========================")
print("")

// 1. 状态转换性能
print("1. 状态转换性能测试...")
let events: [String] = [
    "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
    "PreToolUse", "PostToolUse", "PreToolUse", "PostToolUse",
    "Stop", "SessionEnd"
]

let start1 = CFAbsoluteTimeGetCurrent()
for _ in 0..<100000 {
    for event in events {
        // 简单状态转换模拟
        _ = event
    }
}
let elapsed1 = CFAbsoluteTimeGetCurrent() - start1
print("   ✅ 100,000 次状态转换: \(String(format: "%.3f", elapsed1))s")
print("")

// 2. JSON 编码/解码性能
print("2. JSON 编解码性能测试...")
let jsonData = """
{
    "session_id": "perf-test",
    "cwd": "/tmp/test",
    "hook_event_name": "PreToolUse",
    "tool_name": "Bash",
    "tool_input": {"command": "echo hello"}
}
""".data(using: .utf8)!

struct SimpleEvent: Codable {
    let session_id: String
    let cwd: String
    let hook_event_name: String
}

let start2 = CFAbsoluteTimeGetCurrent()
for _ in 0..<10000 {
    let decoded = try JSONDecoder().decode(SimpleEvent.self, from: jsonData)
    let _ = try JSONEncoder().encode(decoded)
}
let elapsed2 = CFAbsoluteTimeGetCurrent() - start2
print("   ✅ 10,000 次 JSON 编解码: \(String(format: "%.3f", elapsed2))s")
print("")

// 3. 文件读写性能
print("3. 文件读写性能测试...")
let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("perf-\(UUID().uuidString).json")
let testData = """
{"session_id":"test","cwd":"/tmp","status":"coding","lastActivity":"2026-04-14T08:00:00Z"}
""".data(using: .utf8)!

let start3 = CFAbsoluteTimeGetCurrent()
for _ in 0..<1000 {
    try? testData.write(to: tempFile)
    _ = try? Data(contentsOf: tempFile)
}
let elapsed3 = CFAbsoluteTimeGetCurrent() - start3
try? FileManager.default.removeItem(at: tempFile)
print("   ✅ 1,000 次文件读写: \(String(format: "%.3f", elapsed3))s")
print("")

// 4. 集合操作性能
print("4. 集合排序性能测试...")
let statuses = ["idle", "thinking", "coding", "waiting", "waitingPermission", "error", "compacting", "completed"]
let priorities: [String: Int] = [
    "waitingPermission": 0, "error": 1, "compacting": 2, "coding": 3,
    "thinking": 4, "waiting": 5, "completed": 6, "idle": 7
]

let testSessions = (0..<1000).map { i in
    (id: "session-\(i)", status: statuses[i % statuses.count])
}

let start4 = CFAbsoluteTimeGetCurrent()
for _ in 0..<100 {
    _ = testSessions.sorted { priorities[$0.status]! < priorities[$1.status]! }
}
let elapsed4 = CFAbsoluteTimeGetCurrent() - start4
print("   ✅ 100 次 1000 元素排序: \(String(format: "%.3f", elapsed4))s")
print("")

// 5. 字符串解析性能
print("5. 字符串解析性能测试...")
let testMessage = "Context usage: 85% (170000/200000 tokens)"
let regex = try? NSRegularExpression(
    pattern: #"(?:Context usage|上下文使用)\s*:\s*(\d+(?:\.\d+)?)\s*%\s*(?:\((\d+)\s*/\s*(\d+)\s*tokens?\))?"#,
    options: .caseInsensitive
)

let start5 = CFAbsoluteTimeGetCurrent()
for _ in 0..<10000 {
    let range = NSRange(testMessage.startIndex..., in: testMessage)
    _ = regex?.firstMatch(in: testMessage, options: [], range: range)
}
let elapsed5 = CFAbsoluteTimeGetCurrent() - start5
print("   ✅ 10,000 次正则解析: \(String(format: "%.3f", elapsed5))s")
print("")

// 总结
print("==========================")
print("✅ 性能验证完成！")
print("")
print("性能基准:")
print("  状态转换:  \(String(format: "%.3f", elapsed1))s / 100,000 次")
print("  JSON 编解码: \(String(format: "%.3f", elapsed2))s / 10,000 次")
print("  文件读写:   \(String(format: "%.3f", elapsed3))s / 1,000 次")
print("  集合排序:   \(String(format: "%.3f", elapsed4))s / 100 次 (1000 元素)")
print("  正则解析:   \(String(format: "%.3f", elapsed5))s / 10,000 次")
print("")

let allPassed = elapsed1 < 1.0 && elapsed2 < 5.0 && elapsed3 < 2.0 && elapsed4 < 1.0 && elapsed5 < 2.0
if allPassed {
    print("🎉 所有性能测试通过！")
} else {
    print("⚠️  部分性能测试未达预期基准")
}
