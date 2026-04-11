# LLM Quota Island — 设计文档

## 1. 项目概述

macOS 桌面浮动 HUD 应用，以 Dynamic Island 风格实时展示国产大模型 API 额度使用情况。支持像素复古 / 毛玻璃现代双主题切换，内置 8 款像素宠物动画。

**目标用户**：同时使用多家国产大模型 API 的开发者
**支持平台**：小米 MIMO、Kimi（Moonshot）、MiniMax、智谱（Z.AI）、火山方舟（Volcengine Ark）
**目标系统**：macOS 14+ (Sonoma)

---

## 2. 开源资产复用

| 模块 | 参考项目 | 许可证 | 复用方式 |
|------|----------|--------|----------|
| Dynamic Island 窗口 | [EurFelux/Lyrisland](https://github.com/EurFelux/Lyrisland) | MIT | 参考 `DynamicIslandPanel.swift` 的 NSPanel 实现：无边框、statusBar 级别、透明背景、多桌面常驻 |
| 像素宠物精灵 | [handsome-rich/claude-buddy](https://github.com/handsome-rich/claude-buddy) | MIT | 直接复用 `pets.js` 的 hex 编码帧格式和 14 款宠物的 sprite 数据，移植为 Swift 渲染 |
| 像素宠物状态机 | [cs17/claudePet](https://github.com/cs17/claudePet) | — | 参考其 5 阶进化 / XP 系统的交互设计理念 |
| 菜单栏原生方案 | [victorfu/buddy-bar](https://github.com/victorfu/buddy-bar) | — | 参考 Swift/SwiftUI 原生菜单栏集成方式（作为备选 UI 模式） |
| 像素字体 | Press Start 2P (Google Fonts) | OFL | 像素风格主题的数字/文字渲染 |

**核心原则**：架构自己写，但像素帧数据、窗口参考实现、字体等直接复用开源资产，不重复造轮子。

---

## 3. 技术架构

```
┌─────────────────────────────────────────────────────────────┐
│                      LLM Quota Island                       │
├──────────────┬──────────────┬───────────────┬───────────────┤
│   HUD 窗口层  │   主题引擎    │   宠物引擎     │   数据层      │
│              │              │               │               │
│ DynamicIsland│ ThemeManager │ PetEngine     │ ProviderManager│
│ Panel (NSPanel)             │               │               │
│              │ PixelTheme   │ SpriteRenderer│ QuotaProvider │
│ IslandView   │ GlassTheme   │ PetStateMachine│  (Protocol)  │
│              │              │               │               │
│ Compact /    │ 用户切换      │ idle/worried/ │ MiMoProvider  │
│ Expanded 状态│ 毛玻璃/像素   │ happy/alarm   │ KimiProvider  │
│ 弹性动画      │              │ celebrate     │ MiniMaxProv.  │
│              │              │ 8款宠物可选    │ ZaiProvider   │
│              │              │               │ ArkProvider   │
├──────────────┴──────────────┴───────────────┼───────────────┤
│              SwiftUI 渲染层                  │  基础设施层     │
│                                             │               │
│                                             │ KeychainStorage│
│                                             │ PollingScheduler│
│                                             │ SettingsStore  │
│                                             │ NetworkClient  │
└─────────────────────────────────────────────┴───────────────┘
```

### 3.1 模块职责

| 模块 | 职责 | 文件 |
|------|------|------|
| `DynamicIslandPanel` | 无边框浮动窗口，Always-on-top，透明背景 | `Window/DynamicIslandPanel.swift` |
| `IslandState` | 窗口状态枚举：compact / expanded | `Window/IslandState.swift` |
| `ThemeManager` | 当前主题切换，持久化偏好 | `Theme/ThemeManager.swift` |
| `Theme` 协议 | 统一主题渲染接口 | `Theme/Theme.swift` |
| `PixelTheme` | 像素复古风格渲染 | `Theme/PixelTheme.swift` |
| `GlassTheme` | 毛玻璃现代风格渲染 | `Theme/GlassTheme.swift` |
| `PetEngine` | 宠物状态机 + 帧动画调度 | `Pet/PetEngine.swift` |
| `SpriteRenderer` | hex 帧数据 → SwiftUI Canvas 渲染 | `Pet/SpriteRenderer.swift` |
| `PetData` | 宠物定义（精灵帧、调色板、名称） | `Pet/PetData.swift` |
| `ProviderManager` | 多 Provider / 多 Key 管理，并发调度 | `Provider/ProviderManager.swift` |
| `QuotaProvider` 协议 | 统一余额查询接口 | `Provider/QuotaProvider.swift` |
| 各 Provider | 平台 API 适配 | `Provider/Providers/*.swift` |
| `KeychainStorage` | API Key 安全存储 | `Storage/KeychainStorage.swift` |
| `PollingScheduler` | 可配置间隔轮询 + 手动刷新 | `Service/PollingScheduler.swift` |
| `SettingsStore` | 用户配置持久化（UserDefaults） | `Storage/SettingsStore.swift` |
| `SettingsView` | 设置面板 UI | `Views/SettingsView.swift` |

---

## 4. 数据模型

### 4.1 QuotaInfo — 单个 Key 的余额信息

```swift
struct QuotaInfo {
    let provider: ProviderType       // 平台类型
    let keyIdentifier: String        // Key 的掩码标识（sk-abc***xyz）
    let totalQuota: Double?          // 总额度（元/tokens，各平台不同）
    let usedQuota: Double?           // 已使用
    let remainingQuota: Double?      // 剩余额度
    let unit: QuotaUnit              // .yuan / .tokens / .requests
    let usageRatio: Double           // 已用占比 0.0~1.0
    let fetchedAt: Date              // 获取时间
    let error: QuotaError?           // 查询失败时的错误信息
}

enum QuotaUnit {
    case yuan, tokens, requests
}

enum QuotaError {
    case invalidKey, networkError, rateLimited, unknown(String)
}
```

### 4.2 ProviderConfig — 单个平台配置

```swift
struct ProviderConfig: Identifiable, Codable {
    let id: UUID
    let type: ProviderType
    var name: String                 // 用户自定义名称，如 "MIMO-生产"
    var apiKeyRef: String            // Keychain 中的 key 引用
    var baseURL: String?             // 可选，覆盖默认地址
    var enabled: Bool
}
```

### 4.3 AppSettings — 全局设置

```swift
struct AppSettings: Codable {
    var theme: AppTheme              // .pixel / .glass
    var petEnabled: Bool
    var selectedPetID: String        // 宠物标识
    var pollingInterval: Int         // 分钟，最小 1，最大 60
    var launchAtLogin: Bool
    var windowPosition: CGPoint?     // 自定义窗口位置
}
```

### 4.4 ProviderType — 支持的平台

```swift
enum ProviderType: String, Codable, CaseIterable {
    case mimo       // 小米 MIMO
    case kimi       // Kimi / Moonshot
    case minimax    // MiniMax
    case zai        // 智谱 Z.AI
    case ark        // 火山方舟
}
```

---

## 5. QuotaProvider 协议

```swift
protocol QuotaProvider {
    var type: ProviderType { get }
    var displayName: String { get }
    var defaultBaseURL: String { get }

    /// 验证 API Key 是否有效
    func validateKey(_ key: String, baseURL: String?) async throws -> Bool

    /// 查询余额/用量
    func fetchQuota(key: String, baseURL: String?) async throws -> QuotaInfo

    /// 该平台余额的单位
    var quotaUnit: QuotaUnit { get }
}
```

---

## 6. UI 设计

### 6.1 窗口状态

```
┌─── Compact（收起态）──────────────────────────┐
│                                              │
│  [▰▰▰▰▰▰▱▱▱▱] MIMO 62% · ¥189    🐱         │
│                                              │
└──────────────────────────────────────────────┘

┌─── Expanded（展开态）─────────────────────────┐
│                                              │
│  ┌─ MIMO ──────────────────────────────┐     │
│  │  [▰▰▰▰▰▰▱▱▱▱] 62%                  │     │
│  │  剩余: ¥189 / ¥500                  │     │
│  │  今日消耗: ¥23                       │     │
│  │  预计剩余: 8.2 天                    │     │
│  │  Key: sk-abc***xyz  ✅              │     │
│  └─────────────────────────────────────┘     │
│                                              │
│  ┌─ Kimi ──────────────────────────────┐     │
│  │  [▰▰▰▰▰▰▰▰▱▱] 81%                  │     │
│  │  剩余: 1.2M tokens / 5M             │     │
│  │  ...                                 │     │
│  └─────────────────────────────────────┘     │
│                                              │
└──────────────────────────────────────────────┘
```

### 6.2 双主题渲染差异

| 元素 | 像素复古 | 毛玻璃现代 |
|------|----------|-----------|
| 背景 | 纯黑/深灰 + 2px 像素边框 | NSVisualEffectView 毛玻璃 |
| 进度条 | 方块填充 ████░░░░ | 圆角渐变条 ▰▰▰▰▱▱▱▱ |
| 字体 | Press Start 2P (像素) | SF Pro (系统) |
| 数字 | 像素点阵 | 常规数字 |
| 宠物 | 像素精灵渲染 | 同样像素精灵（风格冲突感反而有趣） |
| 颜色 | NES 调色板（绿/黄/红） | 系统 accent color |

### 6.3 像素宠物系统

**复用 claude-buddy 的 14 款宠物，v1 选 8 款**：

| 编号 | 宠物 | 稀有度 | 选用理由 |
|------|------|--------|----------|
| 1 | Cat (猫) | R | 经典，辨识度高 |
| 2 | Capybara (水豚) | SR | 近年网红，萌系代表 |
| 3 | Fox (狐狸) | R | 像素表现力强 |
| 4 | Hamster (仓鼠) | N | 可爱，动作丰富 |
| 5 | Bunny (兔子) | R | 经典萌宠 |
| 6 | Penguin (企鹅) | R | 辨识度高 |
| 7 | Chick (小鸡) | N | 简洁像素适合小尺寸 |
| 8 | Dragon (龙) | UR | 国风元素，差异化 |

**宠物状态动画**：

```
状态           触发条件              动画表现
─────────────────────────────────────────────────
idle          正常轮询间隔中         2帧呼吸循环（上下微动）
happy         quota > 50%           跳跃动画（Y轴位移）
worried       20% ≤ quota ≤ 50%     左右摇晃 + 眉毛下垂
alarm         quota < 20%           红色闪烁 + 惊慌抖动
celebrate     数据刷新成功           旋转/翻跟头 + 闪光
error         API 调用失败           灰色 + 倒地 + 红色叹号
```

**渲染方案**：复用 claude-buddy 的 hex 编码帧格式，Swift Canvas 绘制：
- 每帧：14 宽 x 14 高，hex 字符串，0=透明，1-7=调色板索引
- 2 帧循环 = 呼吸动画
- 4 帧 = 完整动作序列（跳跃/惊慌等）

---

## 7. Provider API 对接方案

### 7.1 统一策略

- 用户只需填 API Key，App 用内置默认 Base URL
- 高级设置可覆盖 Base URL（私有化部署场景）
- 每个 Provider 独立实现 `QuotaProvider` 协议

### 7.2 各平台接口预研

| 平台 | 预期接口 | 备注 |
|------|----------|------|
| 小米 MIMO | `/v1/dashboard/billing/credit_grants` 或自定义 | 需验证是否兼容 OpenAI 格式 |
| Kimi | `/v1/chat/models` 或 Moonshot billing | Moonshot API 兼容 OpenAI |
| MiniMax | `/v1/user/info` 或 Group API | 可能需要 Group ID |
| 智谱 | `/api/v4/users/balance` | 智谱开放平台标准接口 |
| 火山方舟 | `/api/v1/endpoint` + 账户余额接口 | 火山云 API v4 |

**实际实现前需用真实 Key 逐个验证**。

---

## 8. 设置页面

```
┌─ 设置 ─────────────────────────────────────────┐
│                                                │
│  外观                                         │
│  ├─ HUD 风格:  [●像素复古] [○毛玻璃现代]        │
│  ├─ 像素宠物:  [●开启]  [○关闭]                 │
│  └─ 宠物选择:  🐱 猫  ▸ [切换]                  │
│                                                │
│  刷新                                         │
│  └─ 轮询间隔:  [━━●━━━━━] 5 分钟               │
│                                                │
│  API Keys                                      │
│  ├─ 小米 MIMO                                  │
│  │   sk-abc***xyz  ✅ 有效   [编辑] [删除]      │
│  │   [+ 添加 Key]                              │
│  ├─ Kimi                                      │
│  │   sk-def***uvw  ❌ 失效   [编辑] [删除]      │
│  │   [+ 添加 Key]                              │
│  ├─ MiniMax                                   │
│  ├─ 智谱                                      │
│  └─ 火山方舟                                   │
│                                                │
│  系统                                          │
│  ├─ 开机自启:  [●开启] [○关闭]                  │
│  └─ [立即刷新所有]  [重置设置]                   │
│                                                │
└────────────────────────────────────────────────┘
```

---

## 9. 错误处理

| 场景 | HUD 表现 | 宠物表现 |
|------|----------|----------|
| Key 无效/过期 | 该平台显示 ❌ + "Key 失效" | 灰色倒地 + 叹号 |
| 网络超时 | 保留上次数据 + ⚠️ 标记 | 困惑表情 |
| 限频 | "Rate Limited" + 倒计时 | 耸肩动画 |
| 全部正常 | 正常进度条 | 对应 quota 状态动画 |
| 首次未配置 | "请添加 API Key" 引导 | idle 待机动画 |

---

## 10. 项目文件结构

```
llm-quota-island/
├── LLMQuotaIsland.xcodeproj
├── Sources/
│   ├── App/
│   │   ├── LLMQuotaIslandApp.swift
│   │   └── AppDelegate.swift
│   ├── Window/
│   │   ├── DynamicIslandPanel.swift    ← 复用 Lyrisland 参考
│   │   ├── IslandState.swift
│   │   └── IslandPositionMode.swift
│   ├── Theme/
│   │   ├── Theme.swift                 ← 协议
│   │   ├── ThemeManager.swift
│   │   ├── PixelTheme.swift
│   │   └── GlassTheme.swift
│   ├── Pet/
│   │   ├── PetEngine.swift             ← 状态机动画调度
│   │   ├── PetData.swift               ← 复用 claude-buddy 帧数据
│   │   ├── SpriteRenderer.swift        ← hex → Canvas 渲染
│   │   └── PetState.swift
│   ├── Provider/
│   │   ├── QuotaProvider.swift         ← 协议
│   │   ├── ProviderManager.swift
│   │   ├── ProviderType.swift
│   │   └── Providers/
│   │       ├── MiMoProvider.swift
│   │       ├── KimiProvider.swift
│   │       ├── MiniMaxProvider.swift
│   │       ├── ZaiProvider.swift
│   │       └── ArkProvider.swift
│   ├── Storage/
│   │   ├── KeychainStorage.swift
│   │   └── SettingsStore.swift
│   ├── Service/
│   │   └── PollingScheduler.swift
│   ├── Views/
│   │   ├── IslandView.swift            ← 主 HUD 视图
│   │   ├── CompactIslandView.swift
│   │   ├── ExpandedIslandView.swift
│   │   ├── QuotaCardView.swift
│   │   ├── PetView.swift
│   │   ├── ProgressBarView.swift
│   │   └── SettingsView.swift
│   ├── Model/
│   │   ├── QuotaInfo.swift
│   │   ├── ProviderConfig.swift
│   │   └── AppSettings.swift
│   └── Resources/
│       ├── Fonts/
│       │   └── PressStart2P.ttf
│       └── Sprites/                     ← claude-buddy 帧数据 JSON
├── Tests/
│   ├── ProviderTests/
│   ├── PetEngineTests/
│   └── SettingsTests/
├── docs/
│   └── superpowers/specs/
│       └── 2026-04-11-llm-quota-island-design.md  ← 本文档
├── LICENSE                              ← MIT
└── README.md
```

---

## 11. 开发阶段划分

### Phase 1：骨架 + 首个 Provider（Day 1-2）
- Xcode 项目创建，SwiftUI App 骨架
- `QuotaProvider` 协议 + `MiMoProvider` 首个实现
- `KeychainStorage` + `SettingsStore`
- `DynamicIslandPanel` 浮动窗口（参考 Lyrisland）
- Compact 态基础 UI（纯数据，无宠物）
- **里程碑**：能看到浮动窗口展示 MIMO 余额

### Phase 2：全平台 Provider + 设置页（Day 3-4）
- 剩余 4 个 Provider 实现
- `ProviderManager` 多 Key 并发调度
- `PollingScheduler` 可配置轮询
- `SettingsView` 完整设置页
- Key 添加/验证/删除流程
- **里程碑**：5 个平台全部可查，设置页可用

### Phase 3：双主题 + 像素宠物（Day 4-5）
- `Theme` 协议 + `PixelTheme` / `GlassTheme`
- `SpriteRenderer` 复用 claude-buddy 帧数据
- `PetEngine` 状态机（idle/happy/worried/alarm/celebrate/error）
- 8 款宠物数据移植 + 切换 UI
- Expanded 态详情卡片
- **里程碑**：双主题切换 + 宠物动画完整可用

### Phase 4：打磨 + 开源发布（Day 5-6）
- 开机自启（SMAppService）
- App Icon
- 真实 Key 全平台联调
- 错误处理完善
- README + MIT LICENSE
- GitHub 仓库 + Release 打包
- **里程碑**：v1.0 开源发布

---

## 12. 技术选型总结

| 维度 | 选型 |
|------|------|
| 语言 | Swift 5.9+ |
| UI 框架 | SwiftUI + AppKit (NSPanel) |
| 最低系统 | macOS 14 (Sonoma) |
| 网络 | URLSession（原生） |
| Key 存储 | Security.framework Keychain |
| 配置存储 | UserDefaults |
| 字体 | Press Start 2P (OFL) |
| 像素帧格式 | hex 编码（兼容 claude-buddy） |
| 构建 | Xcode + SPM |
| 许可证 | MIT |
