# Contributing to Vibe Island

感谢你对 Vibe Island 的兴趣！以下是参与贡献的指南。

## 开发环境

- macOS 14.0+ (Sonoma)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Claude Code 或 OpenCode（可选，用于测试 hook 功能）

## 快速开始

```bash
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island
./scripts/dev-setup.sh
```

## 项目约定

- **永远不要手动编辑 `.xcodeproj`** — 全部通过 `project.yml` 生成
- **Swift 6 严格并发** — 所有单例使用 `@MainActor`，避免从非 `@MainActor` 的 View struct 使用 `DispatchQueue.main.asyncAfter`
- **中文注释** — 代码注释使用中文，用 `MARK:` 分组
- **IPC 安全** — 所有 session 文件 I/O 必须使用 `flock` 锁；JSON 写入不要用 `.atomic`（会改 inode，破坏 DispatchSource）
- **不要添加未读的 `@Observable` 属性** — 使用 `@ObservationIgnored`
- **增量传递** — 向 `PetProgressManager.addCodingMinutes` 传递 delta 而非累计值
- **模型同步** — `Sources/CLI/SharedModels.swift` 和 `Sources/VibeIsland/Models/` 的模型是重复的，修改时必须同步两处（特别是 `SessionState.transition()` 和 `isBlinking`）

## 代码审查要求

**重大变更**（如状态机修改、公共 API 变更、并发模式变更）必须先请求 code review 再合并。

审查流程：
1. 完成开发后，使用 `git diff` 生成变更摘要
2. 通过 Task 工具 dispatch code-reviewer subagent
3. 修复 Critical/Important 问题后方可合并
4. 如果审阅者判断错误，提供技术理由反驳

## 提交规范

```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式（不影响功能）
refactor: 重构
test: 测试相关
chore: 构建/工具相关
```

## 测试

```bash
./scripts/run-tests.sh
```

新增功能必须包含单元测试。修改 `SessionState.transition()` 或 `isBlinking` 时，必须同步更新 `SessionStateTests.swift`。

## 提交 PR 前检查清单

- [ ] `xcodegen generate` 通过且 `.xcodeproj` 变化已 `.gitignore`
- [ ] `./scripts/run-tests.sh` 全部通过
- [ ] 没有 `try!` / `!` / `as!` force-unwrap（测试代码除外）
- [ ] 没有 `print()` 调试输出（测试和性能脚本除外）
- [ ] 没有未读的 `@Observable` 属性
- [ ] 没有硬编码的 API key 或 secret
- [ ] CLI 和 App 的重复模型（SessionState.transition, isBlinking 等）已同步
- [ ] 本地化和英文/中文 strings 同步更新
