# Vibe Island — 宠物解锁机制说明

> 文档日期：2026-04-14
> 基于代码实现：`PetProgressManager.swift` + `CodingTimeTracker.swift`

---

## 一、概述

Vibe Island 的宠物系统采用 **XP 解锁机制**，用户必须累计足够的 **vibe coding 时长**才能解锁新宠物。这种设计鼓励用户持续使用 AI 编码工具，同时通过解锁新宠物提供持续的激励感。

---

## 二、宠物解锁阈值

| 宠物 | 解锁所需时长 | 说明 |
|------|------------|------|
| 🐱 猫咪 | 0 分钟 | 初始可用 |
| 🐶 小狗 | 30 分钟 | 累计编码 30 分钟解锁 |
| 🐰 兔子 | 60 分钟 | 累计编码 1 小时解锁 |
| 🦊 狐狸 | 120 分钟 | 累计编码 2 小时解锁 |
| 🐧 企鹅 | 240 分钟 | 累计编码 4 小时解锁 |
| 🤖 机器人 | 480 分钟 | 累计编码 8 小时解锁 |
| 👻 幽灵 | 960 分钟 | 累计编码 16 小时解锁 |
| 🐉 小龙 | 1920 分钟 | 累计编码 32 小时解锁 |

---

## 三、编码时长追踪

### 3.1 工作原理

**CodingTimeTracker.swift** 负责记录用户的真实 vibe coding 时长：

1. **监听会话状态变化**
   - 通过 `SessionManager.updateSession()` 获取会话状态
   - 调用 `handleSessionStateChange(sessionId:state:)` 记录状态变化

2. **仅累计"活跃编码"状态**
   - ✅ `thinking` — 正在处理用户提示
   - ✅ `coding` — 正在调用工具
   - ✅ `waitingPermission` — 等待权限审批
   - ❌ `idle` — 空闲（不计入）
   - ❌ `waiting` — 等待输入（不计入）
   - ❌ `completed` — 已完成（不计入）
   - ❌ `error` — 错误（不计入）
   - ❌ `compacting` — 上下文压缩（不计入）

3. **定时更新（每 30 秒）**
   - 计算上次检查以来的时间间隔
   - 如果有活跃编码会话，累加到今日/本周/总时长

4. **跨天/跨周自动重置**
   - 今日时长每天 00:00 重置
   - 本周时长每周一重置
   - 总时长永久累计（用于宠物解锁）

5. **持久化存储**
   - 每 30 秒写入 UserDefaults
   - 防止应用崩溃丢失数据

### 3.2 统计维度

| 维度 | 属性 | 说明 |
|------|------|------|
| 今日 | `todayCodingMinutes` | 今天累计的编码时长 |
| 本周 | `weekCodingMinutes` | 本周一至今的编码时长 |
| 总计 | `totalCodingMinutes` | 历史累计编码时长（用于宠物解锁） |

### 3.3 持久化键值

| 键名 | 类型 | 说明 |
|------|------|------|
| `vibe-island.today-coding-seconds` | Int | 今日编码时长（秒） |
| `vibe-island.week-coding-seconds` | Int | 本周编码时长（秒） |
| `vibe-island.total-coding-seconds` | Int | 总编码时长（秒） |
| `vibe-island.today-marker` | TimeInterval | 今日标记日期（用于跨天检测） |
| `vibe-island.week-marker` | TimeInterval | 本周标记日期（用于跨周检测） |

---

## 四、宠物进度管理

### 4.1 PetProgressManager

**PetProgressManager.swift** 负责管理宠物解锁进度和已解锁状态：

| 属性 | 类型 | 说明 |
|------|------|------|
| `totalCodingMinutes` | Int | 累计 vibe coding 时长（分钟） |
| `unlockedPets` | Set<PetType> | 已解锁的宠物列表 |
| `selectedPet` | PetType | 当前选中的宠物（必须已解锁） |
| `isEnabled` | Bool | 宠物是否启用 |

### 4.2 解锁检查

当添加编码时长时，`addCodingMinutes()` 方法会：

1. 累加总时长
2. 保存到 UserDefaults
3. 调用 `checkNewUnlocks()` 检查是否有新宠物解锁
4. 如果解锁了新宠物，日志输出：`🎉 新宠物解锁: XXX`

### 4.3 持久化键值

| 键名 | 类型 | 说明 |
|------|------|------|
| `vibe-island.coding-minutes` | Int | 累计总时长（分钟） |
| `vibe-island.selected-pet` | String | 当前选中的宠物（rawValue） |
| `vibe-island.pet-enabled` | Bool | 宠物是否启用 |

---

## 五、数据流

```
Claude Code / OpenCode 触发事件
    ↓
HookHandler 写入 session 文件
    ↓
SessionFileWatcher 检测文件变化
    ↓
SessionManager.updateSession() 更新会话状态
    ↓
CodingTimeTracker.handleSessionStateChange() 记录状态变化
    ↓
每 30 秒 tick() 累计时长
    ↓
PetProgressManager.addCodingMinutes() 检查宠物解锁
    ↓
持久化到 UserDefaults
```

---

## 六、代码实现

### 6.1 核心文件

| 文件 | 路径 | 说明 |
|------|------|------|
| CodingTimeTracker.swift | `Sources/VibeIsland/Services/` | 编码时长追踪器 |
| PetProgressManager.swift | `Sources/VibeIsland/Pet/` | 宠物解锁进度管理 |
| SessionManager.swift | `Sources/VibeIsland/Services/` | 集成点（updateSession） |

### 6.2 SessionManager 集成

```swift
// SessionManager.swift - updateSession()
private func updateSession(_ sessionId: String, _ session: Session) {
    sessions[sessionId] = session
    
    // 同步到上下文监控
    contextMonitor.handleSessionUpdate(session)
    
    // 同步到编码时长追踪器
    CodingTimeTracker.shared.handleSessionStateChange(
        sessionId: sessionId, 
        state: session.status
    )
    
    // 同步到宠物进度管理器
    Task { @MainActor in
        PetProgressManager.shared.addCodingMinutes(
            CodingTimeTracker.shared.todayCodingMinutes
        )
    }
}
```

### 6.3 定时更新

```swift
// SessionManager.swift - startCodingTimeTicker()
private func startCodingTimeTicker() {
    codingTimeTicker?.cancel()
    codingTimeTicker = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { break }
            await MainActor.run {
                CodingTimeTracker.shared.tick()
                let totalMinutes = CodingTimeTracker.shared.totalCodingMinutes
                PetProgressManager.shared.addCodingMinutes(totalMinutes)
            }
        }
    }
}
```

---

## 七、用户体验

### 7.1 首次启动

- 只有猫咪可用
- 其他宠物显示"还需 X 分钟"

### 7.2 开始编码

- 当 Claude Code/OpenCode 处于活跃编码状态时，时长开始累计
- 用户可在设置中查看编码时长统计

### 7.3 解锁通知

- 当达到新宠物解锁阈值时，日志输出解锁通知
- 用户可在设置中切换已解锁的宠物

### 7.4 持久化

- 时长和解锁状态自动保存
- 下次启动恢复

---

## 八、测试

### 8.1 单元测试

- `PetEngineTests` — 宠物引擎测试
- `PetAnimationsTests` — 宠物动画测试

### 8.2 集成测试

- `SessionTrackingModeIntegrationTests` — 跟踪模式集成测试

---

## 九、未来优化

- [ ] 解锁动画/通知
- [ ] 宠物等级/进化系统
- [ ] 编码时长统计面板
- [ ] 每日/每周编码目标

---

**文档完成。宠物解锁机制已完整实现并记录。**
