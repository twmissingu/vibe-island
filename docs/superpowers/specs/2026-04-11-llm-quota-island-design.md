# LLM Quota Island — 设计文档 v2

## 1. 项目概述

macOS 桌面浮动 HUD 应用，以 Dynamic Island 风格实时展示国产大模型 API 额度使用情况。支持像素复古 / 毛玻璃现代双主题切换，内置 8 款像素宠物动画，配套桌面 Widget。

**目标用户**：同时使用多家国产大模型 API 的开发者
**支持平台**：小米 MIMO、Kimi（Moonshot）、MiniMax、智谱（Z.AI）、火山方舟（Volcengine Ark）
**目标系统**：macOS 14+ (Sonoma)

---

## 2. 开源资产复用

| 模块 | 参考项目 | 许可证 | 复用方式 |
|------|----------|--------|----------|
| Dynamic Island 窗口 | [EurFelux/Lyrisland](https://github.com/EurFelux/Lyrisland) | MIT | 参考 `DynamicIslandPanel.swift`：NSPanel 无边框、statusBar+1 级别、透明背景、多桌面常驻、`attached/detached` 双模式 |
| SPM 共享包架构 | [niederme/ai-quota](https://github.com/niederme/ai-quota) | — | 参考 `AIQuotaKit` 的分层：Models / Networking / Storage / Widgets 放 SPM 包，主 App + Widget Extension 共享 |
| 双弧仪表盘 | [niederme/ai-quota](https://github.com/niederme/ai-quota) | — | 参考 `CircularGaugeView`：270° 双环嵌套（外环=主维度，内环=副维度），颜色由最危急值驱动，loading 脉冲 |
| Widget 时间线调度 | [niederme/ai-quota](https://github.com/niederme/ai-quota) | — | 参考 `WidgetRefreshPolicy`：关键节点驱动刷新（重置时间/heartbeat），避免无意义轮询 |
| Widget 数据共享 | [niederme/ai-quota](https://github.com/niederme/ai-quota) | — | 参考 `SharedDefaults`：App Group UserDefaults 传递缓存数据，Widget 读取上次缓存 + 按策略决定是否请求网络 |
| 像素宠物精灵 | [handsome-rich/claude-buddy](https://github.com/handsome-rich/claude-buddy) | MIT | 直接复用 `pets.js` 的 hex 编码帧格式和 14 款宠物的 sprite 数据，移植为 Swift 渲染 |
| 像素宠物状态机 | [cs17/claudePet](https://github.com/cs17/claudePet) | — | 参考其 5 阶进化 / XP 系统的交互设计理念 |
| 像素字体 | Press Start 2P (Google Fonts) | OFL | 像素风格主题的数字/文字渲染 |

**核心原则**：架构自己写，但像素帧数据、窗口参考实现、仪表盘设计、Widget 架构等直接复用开源资产，不重复造轮子。

---

## 3. 技术架构

### 3.1 整体架构（SPM 共享包模式）

```
LLMQuotaKit (SPM 本地包)        ← 数据层，主 App + Widget 共享
├── Models/                      ← QuotaInfo, ProviderConfig, AppSettings
├── Provider/                    ← QuotaProvider 协议 + 各平台实现
├── Networking/                  ← URLSession Client
├── Storage/                     ← KeychainStore + SharedDefaults (App Group)
├── Widgets/                     ← WidgetRefreshService + WidgetRefreshPolicy
└── Drawing/                     ← GaugeImageMaker (可选：菜单栏图标)

LLMQuotaIsland (主 App)          ← UI 层
├── Window/                      ← DynamicIslandPanel + IslandState
├── Theme/                       ← ThemeManager + PixelTheme + GlassTheme
├── Pet/                         ← PetEngine + SpriteRenderer + PetData
├── Views/                       ← IslandView + SettingsView + 各子视图
├── ViewModel/                   ← QuotaViewModel (数据绑定)
└── Resources/                   ← 字体 + 精灵数据

LLMQuotaWidget (Widget Extension)← 桌面小组件
├── Provider/                    ← QuotaTimelineProvider
├── Views/                       ← WidgetSmallView + WidgetMediumView + WidgetLargeView
└── WidgetEntry + Bundle
```

**数据流**：
```
Provider API  →  URLSession  →  QuotaInfo  →  QuotaViewModel  →  IslandView (HUD)
                               ↓ (缓存)
                          SharedDefaults ←→ WidgetRefreshService → Widget (桌面)
                               ↓ (安全存储)
                          KeychainStore (API Keys)
```

### 3.2 模块职责

| 模块 | 职责 | 文件 |
|------|------|------|
| `DynamicIslandPanel` | 无边框浮动窗口，Always-on-top，透明背景，attached/detached 双模式 | `Window/DynamicIslandPanel.swift` |
| `IslandState` | 窗口状态枚举：compact / expanded | `Window/IslandState.swift` |
| `QuotaViewModel` | 数据获取调度、状态管理、UI 绑定 | `ViewModel/QuotaViewModel.swift` |
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
| `SharedDefaults` | App Group 数据共享（App ↔ Widget） | `Storage/SharedDefaults.swift` |
| `PollingScheduler` | 可配置间隔轮询 + 手动刷新 | `Service/PollingScheduler.swift` |
| `WidgetRefreshPolicy` | 关键节点驱动的 Widget 刷新策略 | `Widgets/WidgetRefreshPolicy.swift` |
| `WidgetRefreshService` | Widget 数据获取 + 缓存决策 | `Widgets/WidgetRefreshService.swift` |
| `SettingsView` | 设置面板 UI | `Views/SettingsView.swift` |

---

## 4. 数据模型

### 4.1 QuotaInfo — 单个 Key 的余额信息

```swift
struct QuotaInfo: Codable, Sendable, Equatable {
    let provider: ProviderType       // 平台类型
    let keyIdentifier: String        // Key 的掩码标识（sk-abc***xyz）
    let totalQuota: Double?          // 总额度（元/tokens，各平台不同）
    let usedQuota: Double?           // 已使用
    let remainingQuota: Double?      // 剩余额度
    let unit: QuotaUnit              // .yuan / .tokens / .requests
    let usageRatio: Double           // 已用占比 0.0~1.0
    let fetchedAt: Date              // 获取时间
    let error: QuotaError?           // 查询失败时的错误信息

    // Computed — 仪表盘直接使用
    var usedPercent: Int { Int(usageRatio * 100) }
    var remainingPercent: Int { 100 - usedPercent }
    var isLowQuota: Bool { usageRatio >= 0.8 }     // < 20% 剩余
    var isCritical: Bool { usageRatio >= 0.95 }     // < 5% 剩余
}

enum QuotaUnit: String, Codable {
    case yuan, tokens, requests
}

enum QuotaError: Codable {
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
    var windowPosition: CGPoint?     // 自定义窗口位置（detached 模式）
    var islandPositionMode: IslandPositionMode  // .attached / .detached
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
    var iconName: String { get }           // 平台 Logo（xcassets）
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

#### Compact（收起态）
```
┌──────────────────────────────────────────────────────────┐
│  [▰▰▰▰▰▰▱▱▱▱] MIMO 62% · ¥189    🐱                     │
└──────────────────────────────────────────────────────────┘
```
- 进度条 + 百分比 + 绝对剩余额度
- 多平台时横向排列或显示最危急的平台
- 右侧像素宠物（如开启）

#### Expanded（展开态）— 借鉴 ai-quota Popover 布局
```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ┌─ MIMO ─────────────────────────────────────────────┐          │
│  │                                                    │          │
│  │       ╭─────╮                                      │          │
│  │      ╱ 剩余  ╲   ← 外环：剩余额度占比              │          │
│  │     ╱  ╭───╮  ╲                                    │          │
│  │    │  │今日│   │  ← 内环：今日消耗占比             │          │
│  │     ╲ ╰───╯  ╱                                     │          │
│  │      ╲ 38%  ╱                                      │          │
│  │       ╰────╯                                       │          │
│  │                                                    │          │
│  │  剩余: ¥189 / ¥500       今日消耗: ¥23             │          │
│  │  预计剩余: 8.2 天         Key: sk-abc***xyz ✅     │          │
│  │                                                    │          │
│  └────────────────────────────────────────────────────┘          │
│                                                                  │
│  ┌─ Kimi ─────────────────────────────────────────────┐          │
│  │       ╭─────╮                                      │          │
│  │      ╱ 剩余  ╲                                     │          │
│  │     ╱  ╭───╮  ╲                                    │          │
│  │    │  │今日│   │                                   │          │
│  │     ╲ ╰───╯  ╱                                     │          │
│  │      ╲ 81%  ╱                                      │          │
│  │       ╰────╯                                       │          │
│  │  剩余: 1.2M tokens / 5M    今日消耗: 120K tokens   │          │
│  └────────────────────────────────────────────────────┘          │
│                                                                  │
│  🐱 [⌘R Refresh]                            v1.0.0               │
└──────────────────────────────────────────────────────────────────┘
```

### 6.2 双弧仪表盘设计（借鉴 ai-quota CircularGaugeView）

**核心参数**：
- 270° 弧线（135° → 405°），非完整圆，起止点平齐
- 外环 = 剩余额度占比（主维度），线宽 8pt
- 内环 = 今日消耗占比（副维度），线宽 8pt，内缩 8pt 与外环相切
- 颜色由两个维度中**更危急**的那个统一驱动：
  - 剩余 > 50% → 绿色
  - 剩余 20-50% → 琥珀色
  - 剩余 < 20% → 红色
- `loading` 状态：弧线停在 50% 做 pulse 动画
- `lineCap: .butt`（平头端点，避免圆头端点在弧线起止处产生气泡）

**适配说明**：国产平台无 5h/7d 窗口概念，改为"剩余额度"和"今日消耗"双维度，视觉语言统一。

### 6.3 双主题渲染差异

| 元素 | 像素复古 | 毛玻璃现代 |
|------|----------|-----------|
| 背景 | 纯黑/深灰 + 2px 像素边框 | NSVisualEffectView 毛玻璃 |
| 仪表盘 | 像素方块弧线 | 圆滑渐变弧线（借鉴 ai-quota） |
| 进度条 | 方块填充 ████░░░░ | 圆角渐变条 ▰▰▰▰▱▱▱▱ |
| 字体 | Press Start 2P (像素) | SF Pro (系统) |
| 宠物 | 像素精灵渲染 | 同样像素精灵 |
| 颜色 | NES 调色板（绿/黄/红） | 系统 accent + 渐变 |

### 6.4 像素宠物系统

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

## 7. Widget 桌面小组件

### 7.1 架构（借鉴 ai-quota）

```
LLMQuotaKit (SPM 共享包)
├── SharedDefaults    ← App Group UserDefaults 读写缓存
├── WidgetRefreshService  ← Widget 独立的数据获取逻辑
└── WidgetRefreshPolicy   ← 刷新时间策略

主 App 写入缓存 → SharedDefaults → Widget Extension 读取展示
```

### 7.2 Widget 刷新策略（借鉴 ai-quota WidgetRefreshPolicy）

```swift
// 核心逻辑：关键节点驱动，避免无意义轮询
func nextTimelineDate(quotas: [QuotaInfo], now: Date) -> Date {
    let heartbeat = now + pollingInterval  // 用户配置的轮询间隔
    let floor = now + 60s                  // 最小间隔 1 分钟

    // 如果有重置时间点（如日重置），在重置前精确刷新
    let resetBoundaries = quotas
        .compactMap { $0.nextResetAt }
        .filter { $0 > floor }

    return min(resetBoundaries.min() ?? heartbeat, heartbeat)
}

func shouldFetchFromNetwork(quotas: [QuotaInfo], now: Date) -> Bool {
    guard let lastFetch = quotas.map(\.fetchedAt).max() else { return true }
    return now.timeIntervalSince(lastFetch) >= staleCacheInterval  // 5分钟
}
```

### 7.3 Widget 尺寸

| 尺寸 | 内容 | 参考 |
|------|------|------|
| Small | 单平台双弧仪表盘 + 剩余额度 | ai-quota `WidgetSmallView` |
| Medium | 双平台并排仪表盘 + 详情行 | ai-quota `WidgetMediumView` |
| Large | 全平台仪表盘网格 + 详细数据 | ai-quota `WidgetLargeView` |

### 7.4 Widget 数据共享

```
主 App:
  PollingScheduler 拉取数据
  → 更新 QuotaViewModel
  → 写入 SharedDefaults (App Group)

Widget Extension:
  QuotaTimelineProvider
  → 读取 SharedDefaults 缓存
  → WidgetRefreshPolicy.shouldFetchFromNetwork()?
     → 是：调用 WidgetRefreshService 刷新
     → 否：使用缓存数据
  → 返回 Timeline<QuotaEntry>
```

---

## 8. Provider API 对接方案

### 8.1 统一策略

- 用户只需填 API Key，App 用内置默认 Base URL
- 高级设置可覆盖 Base URL（私有化部署场景）
- 每个 Provider 独立实现 `QuotaProvider` 协议

### 8.2 各平台接口预研

| 平台 | 预期接口 | 备注 |
|------|----------|------|
| 小米 MIMO | `/v1/dashboard/billing/credit_grants` 或自定义 | 需验证是否兼容 OpenAI 格式 |
| Kimi | `/v1/chat/models` 或 Moonshot billing | Moonshot API 兼容 OpenAI |
| MiniMax | `/v1/user/info` 或 Group API | 可能需要 Group ID |
| 智谱 | `/api/v4/users/balance` | 智谱开放平台标准接口 |
| 火山方舟 | `/api/v1/endpoint` + 账户余额接口 | 火山云 API v4 |

**实际实现前需用真实 Key 逐个验证**。

---

## 9. 设置页面

```
┌─ 设置 ─────────────────────────────────────────┐
│                                                │
│  外观                                         │
│  ├─ HUD 风格:  [●像素复古] [○毛玻璃现代]        │
│  ├─ 窗口模式:  [●贴附菜单栏] [○自由拖拽]        │
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
│  Widget                                        │
│  └─ 桌面小组件已安装 ✅                         │
│                                                │
│  系统                                          │
│  ├─ 开机自启:  [●开启] [○关闭]                  │
│  └─ [立即刷新所有]  [重置设置]                   │
│                                                │
└────────────────────────────────────────────────┘
```

---

## 10. 错误处理

| 场景 | HUD 表现 | 宠物表现 |
|------|----------|----------|
| Key 无效/过期 | 该平台显示 ❌ + "Key 失效" + 重新登录引导 | 灰色倒地 + 叹号 |
| 网络超时 | 保留上次数据 + ⚠️ 标记 + "上次更新: 5分钟前" | 困惑表情 |
| 限频 | "Rate Limited" + 倒计时 | 耸肩动画 |
| 全部正常 | 正常仪表盘 | 对应 quota 状态动画 |
| 首次未配置 | "请添加 API Key" 引导 | idle 待机动画 |
| 部分平台失败 | 成功的正常显示，失败的显示错误 banner | 单个平台对应的宠物变灰 |

---

## 11. 项目文件结构

```
llm-quota-island/
├── LLMQuotaIsland.xcodeproj
├── project.yml                          ← XcodeGen 配置（借鉴 ai-quota）
│
├── Packages/
│   └── LLMQuotaKit/                     ← SPM 共享包（借鉴 ai-quota AIQuotaKit）
│       ├── Package.swift
│       └── Sources/LLMQuotaKit/
│           ├── Models/
│           │   ├── QuotaInfo.swift
│           │   ├── ProviderConfig.swift
│           │   └── AppSettings.swift
│           ├── Provider/
│           │   ├── QuotaProvider.swift        ← 协议
│           │   ├── ProviderType.swift
│           │   └── Providers/
│           │       ├── MiMoProvider.swift
│           │       ├── KimiProvider.swift
│           │       ├── MiniMaxProvider.swift
│           │       ├── ZaiProvider.swift
│           │       └── ArkProvider.swift
│           ├── Networking/
│           │   └── NetworkClient.swift
│           ├── Storage/
│           │   ├── KeychainStorage.swift
│           │   └── SharedDefaults.swift       ← App Group 数据共享
│           ├── Widgets/
│           │   ├── WidgetRefreshPolicy.swift  ← 借鉴 ai-quota
│           │   └── WidgetRefreshService.swift
│           └── Drawing/
│               └── GaugeImageMaker.swift      ← 可选
│
├── Sources/
│   └── LLMQuotaIsland/
│       ├── App/
│       │   ├── LLMQuotaIslandApp.swift
│       │   └── AppDelegate.swift
│       ├── Window/
│       │   ├── DynamicIslandPanel.swift       ← 借鉴 Lyrisland
│       │   ├── IslandState.swift
│       │   └── IslandPositionMode.swift
│       ├── ViewModel/
│       │   └── QuotaViewModel.swift
│       ├── Theme/
│       │   ├── Theme.swift                    ← 协议
│       │   ├── ThemeManager.swift
│       │   ├── PixelTheme.swift
│       │   └── GlassTheme.swift
│       ├── Pet/
│       │   ├── PetEngine.swift                ← 状态机动画调度
│       │   ├── PetData.swift                  ← 复用 claude-buddy 帧数据
│       │   ├── SpriteRenderer.swift           ← hex → Canvas 渲染
│       │   └── PetState.swift
│       ├── Views/
│       │   ├── IslandView.swift               ← 主 HUD 视图
│       │   ├── CompactIslandView.swift
│       │   ├── ExpandedIslandView.swift
│       │   ├── CircularGaugeView.swift        ← 借鉴 ai-quota 双弧仪表盘
│       │   ├── QuotaCardView.swift
│       │   ├── PetView.swift
│       │   ├── CountdownView.swift            ← 借鉴 ai-quota 重置倒计时
│       │   └── SettingsView.swift
│       └── Resources/
│           ├── Fonts/
│           │   └── PressStart2P.ttf
│           └── Sprites/                       ← claude-buddy 帧数据 JSON
│
├── Widget/
│   ├── LLMQuotaWidget.swift
│   ├── LLMQuotaWidgetBundle.swift
│   ├── WidgetIntent.swift                     ← AppIntent 配置
│   ├── Provider/
│   │   └── QuotaTimelineProvider.swift
│   └── Views/
│       ├── WidgetGaugeView.swift              ← 借鉴 ai-quota
│       ├── WidgetSmallView.swift
│       ├── WidgetMediumView.swift
│       └── WidgetLargeView.swift
│
├── Tests/
│   ├── ProviderTests/
│   ├── PetEngineTests/
│   ├── WidgetRefreshTests/
│   └── SettingsTests/
│
├── docs/
│   └── superpowers/specs/
│       └── 2026-04-11-llm-quota-island-design.md  ← 本文档
│
├── LLMQuotaIsland.entitlements               ← App Group 权限
├── LICENSE                                   ← MIT
└── README.md
```

---

## 12. 开发阶段划分

### Phase 1：SPM 包 + 项目骨架（Day 1）
- Xcode 项目 + XcodeGen `project.yml`（借鉴 ai-quota）
- `LLMQuotaKit` SPM 共享包创建：Models + QuotaProvider 协议 + KeychainStorage + SharedDefaults
- `DynamicIslandPanel` 浮动窗口（参考 Lyrisland）
- `QuotaViewModel` 基础框架
- Demo 模式（假数据，不需要真实 Key 即可跑 UI）
- **里程碑**：浮动窗口展示 mock 数据

### Phase 2：首个 Provider + 仪表盘（Day 2）
- `MiMoProvider` 首个实现（用真实 Key 验证接口）
- `CircularGaugeView` 双弧仪表盘（参考 ai-quota，适配为剩余/今日消耗双维度）
- Compact 态 UI：进度条 + 百分比 + 绝对值
- Expanded 态 UI：双弧仪表盘 + 详情卡片
- `PollingScheduler` 可配置轮询
- **里程碑**：真实数据驱动的浮动 HUD 完整可用

### Phase 3：全平台 Provider + 设置页（Day 3-4）
- 剩余 4 个 Provider 实现（逐个用真实 Key 验证接口）
- `ProviderManager` 多 Key 并发调度
- `SettingsView` 完整设置页：主题/宠物/轮询/Key 管理/窗口模式
- 错误状态处理（Key 失效 banner、网络超时提示）
- `CountdownView` 重置倒计时（借鉴 ai-quota）
- **里程碑**：5 个平台全部可查，设置页完整可用

### Phase 4：双主题 + 像素宠物（Day 4-5）
- `Theme` 协议 + `PixelTheme` / `GlassTheme` 双主题
- `SpriteRenderer` 复用 claude-buddy 帧数据
- `PetEngine` 状态机（idle/happy/worried/alarm/celebrate/error）
- 8 款宠物数据移植 + 切换 UI
- **里程碑**：双主题切换 + 宠物动画完整可用

### Phase 5：Widget + 打磨 + 开源发布（Day 5-6）
- `LLMQuotaWidget` Widget Extension
- `QuotaTimelineProvider` + Widget 时间线调度（借鉴 ai-quota `WidgetRefreshPolicy`）
- Widget Small / Medium / Large 三种尺寸
- App Group 配置 + 数据共享联调
- 开机自启（SMAppService）
- App Icon
- 真实 Key 全平台联调
- README + MIT LICENSE + 中英文
- GitHub 仓库 + Release 打包
- **里程碑**：v1.0 开源发布

---

## 13. 技术选型总结

| 维度 | 选型 |
|------|------|
| 语言 | Swift 6.0 |
| UI 框架 | SwiftUI + AppKit (NSPanel) |
| 最低系统 | macOS 14 (Sonoma) |
| 网络 | URLSession（原生） |
| Key 存储 | Security.framework Keychain |
| 配置存储 | UserDefaults + App Group |
| 共享数据层 | SPM 本地包 LLMQuotaKit（借鉴 ai-quota AIQuotaKit） |
| Widget | WidgetKit + AppIntents |
| 字体 | Press Start 2P (OFL) |
| 像素帧格式 | hex 编码（兼容 claude-buddy） |
| 项目管理 | XcodeGen project.yml（借鉴 ai-quota） |
| 自动更新 | Sparkle v2.9（v2 可选） |
| 构建 | Xcode + SPM |
| 许可证 | MIT |
