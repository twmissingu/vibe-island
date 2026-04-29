#!/usr/bin/env swift

import Foundation

// MARK: - 测试配置

let testLogPrefix = "[HookInstallTest]"
let claudeDirPath = NSString("~/.claude").expandingTildeInPath
let settingsPath = claudeDirPath + "/settings.json"
let backupDirPath = claudeDirPath + "/vibe-island-backups"

// MARK: - 测试工具函数

func log(_ message: String) {
    print("\(testLogPrefix) \(message)")
}

func assert(_ condition: Bool, _ message: String) {
    if condition {
        log("✅ PASS: \(message)")
    } else {
        log("❌ FAIL: \(message)")
        exit(1)
    }
}

// MARK: - 测试用例

/// 测试 1: 检查 ~/.claude 目录是否存在
func testClaudeDirectoryExists() {
    log("测试 1: 检查 ~/.claude 目录是否存在")
    let fm = FileManager.default
    let exists = fm.fileExists(atPath: claudeDirPath)
    assert(exists, "~/.claude 目录应存在")
}

/// 测试 2: 检查目录权限
func testDirectoryPermissions() {
    log("测试 2: 检查目录权限")
    let fm = FileManager.default
    
    guard let attrs = try? fm.attributesOfItem(atPath: claudeDirPath) else {
        assert(false, "无法读取目录属性")
        return
    }
    
    let perms = attrs[.posixPermissions] as? Int ?? 0
    let owner = attrs[.ownerAccountID] as? uid_t ?? 0
    let currentUid = getuid()
    
    log("  目录权限: \(String(perms, radix: 8))")
    log("  所有者: \(owner), 当前用户: \(currentUid)")
    
    let hasWrite = (perms & 0o200) != 0
    let isOwner = owner == currentUid
    
    assert(hasWrite && isOwner, "目录应有写权限且所有者是当前用户")
}

/// 测试 3: 测试写入权限
func testWritePermission() {
    log("测试 3: 测试写入权限")
    let fm = FileManager.default
    let testFile = claudeDirPath + "/.vibetest_\(UUID().uuidString)"
    
    do {
        try "test".write(toFile: testFile, atomically: true, encoding: .utf8)
        try fm.removeItem(atPath: testFile)
        assert(true, "目录写入权限正常")
    } catch {
        assert(false, "目录写入权限失败: \(error.localizedDescription)")
    }
}

/// 测试 4: 测试配置文件读取
func testSettingsFileRead() {
    log("测试 4: 测试配置文件读取")
    let fm = FileManager.default
    
    if fm.fileExists(atPath: settingsPath) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            assert(json != nil, "settings.json 可读且格式正确")
        } catch {
            assert(false, "settings.json 读取失败: \(error.localizedDescription)")
        }
    } else {
        log("  ⚠️ settings.json 不存在（首次安装）")
        assert(true, "配置文件不存在，将创建新文件")
    }
}

/// 测试 5: 测试配置文件写入
func testSettingsFileWrite() {
    log("测试 5: 测试配置文件写入")
    let fm = FileManager.default
    
    // 创建测试配置
    let testConfig: [String: Any] = [
        "hooks": [
            "PreToolUse": [
                [
                    "matcher": "test",
                    "hooks": [
                        [
                            "type": "command",
                            "command": "/usr/bin/echo test"
                        ]
                    ]
                ]
            ]
        ]
    ]
    
    do {
        let data = try JSONSerialization.data(withJSONObject: testConfig, options: [.prettyPrinted, .sortedKeys])
        
        // 备份原文件（如果存在）
        var originalData: Data? = nil
        if fm.fileExists(atPath: settingsPath) {
            originalData = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
        }
        
        // 写入测试配置
        try data.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
        
        // 验证写入
        let readData = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
        let readJson = try JSONSerialization.jsonObject(with: readData) as? [String: Any]
        
        assert(readJson != nil, "配置文件写入成功")
        
        // 恢复原文件
        if let original = originalData {
            try original.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
            log("  已恢复原配置文件")
        } else {
            try fm.removeItem(atPath: settingsPath)
            log("  已删除测试配置文件")
        }
        
    } catch {
        assert(false, "配置文件写入失败: \(error.localizedDescription)")
    }
}

/// 测试 6: 测试备份目录创建
func testBackupDirectoryCreation() {
    log("测试 6: 测试备份目录创建")
    let fm = FileManager.default
    
    do {
        if !fm.fileExists(atPath: backupDirPath) {
            try fm.createDirectory(atPath: backupDirPath, withIntermediateDirectories: true)
            log("  创建备份目录成功")
        } else {
            log("  备份目录已存在")
        }
        assert(true, "备份目录可用")
    } catch {
        assert(false, "备份目录创建失败: \(error.localizedDescription)")
    }
}

// MARK: - 主测试流程

func runAllTests() {
    let separator = String(repeating: "=", count: 50)
    log(separator)
    log("Claude Code Hook 安装测试")
    log(separator)
    
    testClaudeDirectoryExists()
    testDirectoryPermissions()
    testWritePermission()
    testSettingsFileRead()
    testSettingsFileWrite()
    testBackupDirectoryCreation()
    
    log(separator)
    log("✅ 所有测试通过！")
    log(separator)
}

// 运行测试
runAllTests()
