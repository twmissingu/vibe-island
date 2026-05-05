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
- **Swift 6 严格并发** — 所有单例使用 `@MainActor`
- **中文注释** — 代码注释使用中文
- **IPC 安全** — 所有 session 文件 I/O 必须使用 `flock` 锁
- **不要添加未读的 `@Observable` 属性** — 使用 `@ObservationIgnored`

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

新增功能必须包含单元测试。

## 提交 PR 前检查清单

- [ ] `xcodegen generate && xcodebuild test` 通过
- [ ] 没有手动修改 `.xcodeproj`
- [ ] 新功能有对应测试
- [ ] 本地化和英文/中文 strings 同步更新
