[![English](https://img.shields.io/badge/English-blue.svg)](README.md)
[![中文](https://img.shields.io/badge/中文-red.svg)](README_zh.md)

---

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue?logo=apple" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License" />
  <img src="https://img.shields.io/badge/Platform-x86_64%20%7C%20arm64-lightgrey" alt="Platform" />
</p>

<h1 align="center">VibeIsland</h1>
<p align="center"><em>为你的 LLM 编码会话打造的灵动岛——在菜单栏实时监控 Claude Code 和 OpenCode。</em></p>

<p align="center">
  <img src="https://img.shields.io/badge/Claude%20Code-F9A03C?logo=claude&logoColor=white" />
  <img src="https://img.shields.io/badge/OpenCode-000000?logo=openai&logoColor=white" />
  <img src="https://img.shields.io/badge/Status-Active-success" />
</p>

---

## 为什么选择 VibeIsland？

用 AI agent 写代码很强大，但你是在盲飞。还剩多少上下文？Claude 在等你批准吗？工具调用失败了吗？VibeIsland 把这些信息带到你的菜单栏——无需来回切换窗口，无需凑近终端。

VibeIsland 把你的 macOS 菜单栏变成 LLM 编码会话的实时仪表盘，再加上一个可爱的像素宠物，打造有趣的灵动岛体验。

## 功能特性

- **实时会话监控** — 实时跟踪 Claude Code 和 OpenCode 的会话状态：思考中、编码中、等待中、权限请求、错误、上下文压缩
- **上下文使用量追踪** — 进度条显示 200K 上下文的消耗情况，含输入/输出/推理 token 明细
- **多会话管理** — 自动模式显示最高优先级会话；手动模式固定追踪某个会话
- **像素宠物伙伴** — 8 种宠物 × 5 阶进化 × 8 种动画，随你的编码状态实时反应
- **双主题** — 像素暗色（复古游戏风）和玻璃透明（现代毛玻璃）
- **CLI Hook 集成** — `vibe-island` CLI 工具处理 Claude Code 钩子事件，通过 flock 锁安全写入 session 文件
- **上下文压缩提醒** — Claude Code 压缩上下文时给出视觉提示
- **声音通知** — 可选的状态变化提示音

## 快速开始

### 环境要求

- macOS 14.0+ (Sonoma)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Claude Code 和/或 OpenCode（可选，用于会话追踪）

### 安装

```bash
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island
./scripts/dev-setup.sh     # 检查依赖、生成项目、类型检查 CLI
xcodegen generate           # 从 project.yml 生成 .xcodeproj
```

然后在 Xcode 中打开 `VibeIsland.xcodeproj`，构建 `VibeIsland` scheme。

### 使用

1. **启动应用** — VibeIsland 以菜单栏代理（LSUIElement）运行。菜单栏会出现一个灵动岛图标。
2. **开始编码** — 正常使用 Claude Code 或 OpenCode，会话状态实时显示。
3. **点击灵动岛** — 展开查看详情：上下文使用量、token 数量、工具调用统计和像素宠物。
4. **安装 Hook（Claude Code）**：
   ```bash
   ./scripts/dev-setup.sh
   # 或手动安装：
   vibe-island hook install
   ```

## AI Agent 使用指南

VibeIsland 专为 AI agent 无缝集成而设计：

1. **克隆并安装依赖**
   ```bash
   git clone https://github.com/twzhan/vibe-island.git
   cd vibe-island
   brew install xcodegen
   xcodegen generate
   ```

2. **构建**
   ```bash
   xcodebuild build -scheme VibeIsland -destination 'platform=macOS'
   # 或只构建 CLI
   cd Sources/CLI && swiftc -typecheck -target arm64-apple-macosx14.0 *.swift
   ```

3. **运行测试**
   ```bash
   ./scripts/run-tests.sh
   ```

4. **项目结构**
   - `Sources/VibeIsland/` — macOS 应用（SwiftUI, MVVM, @Observable）
   - `Sources/CLI/` — Hook 集成 CLI 工具
   - `Packages/LLMQuotaKit/` — 本地 SPM 框架，LLM 配额管理
   - `Tests/` — 单元测试（XCTest）+ 独立脚本测试
   - `project.yml` — XcodeGen 项目配置文件（不要手动编辑 .xcodeproj）

5. **关键约定**
   - 修改 `project.yml` 后必须执行 `xcodegen generate`
   - Session 文件 I/O 必须使用 `flock` 锁（不要用 `.atomic` 写入）
   - CLI 和 App 在 `Sources/CLI/SharedModels.swift` 和 `Sources/VibeIsland/Models/` 中有重复模型类型——必须同步修改
   - `SessionState.transition()` 和 `isBlinking` 在两处必须完全一致

## 架构

```
┌─────────────────────────────────────────────────┐
│                菜单栏代理应用                      │
│  ┌───────────────────────────────────────────┐  │
│  │         DynamicIslandPanel                 │  │
│  │  [紧凑视图] ◄─点击► [展开视图]              │  │
│  │         SessionManager                     │  │
│  └───────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────┘
                       │ IPC: flock 锁保护的 JSON 文件
┌──────────────────────▼──────────────────────────┐
│  ~/.vibe-island/sessions/<pid>.json              │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│  CLI (Sources/CLI/)    │  OpenCode 监控           │
│  HookHandler.swift     │  ContextMonitor.swift   │
│  (读取 stdin 事件)      │  (读取 SQLite 数据库)   │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│  Claude Code           │  OpenCode               │
│  (通过 hook 事件 +     │  (通过 SQLite 数据库     │
│   transcript JSONL)    │   轮询)                  │
└─────────────────────────────────────────────────┘
```

## 贡献指南

参见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

MIT — 参见 [LICENSE](LICENSE)。
