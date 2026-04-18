# VibeIsland SwiftUI 视图层

**作用**: 包含所有 Dynamic Island 和设置界面的 SwiftUI 视图

## 结构

主要视图：
- `IslandView` - 灵动岛主视图（显示状态和宠物）
- `SettingsView` - 设置主界面（最大，608 行）
- `QuotaListView` - API 配额列表
- `OnboardingView` - 首次启动引导
- `ContextUsageView` - 上下文使用率显示

## 在哪里找

| 任务 | 位置 |
|------|------|
| 修改灵动岛外观 | `IslandView.swift` |
| 修改设置界面 | `SettingsView.swift` |
| 修改配额显示 | `QuotaListView.swift` |

## 约定

- 所有视图使用 `@Observable` 视图模型（MVVM）
- 颜色使用 `Color` + `ColorAsset` 适配深色模式
- 动态岛布局根据 notch 位置和大小自适应
- 闪烁效果使用 `TimelineView` 实现

## 反模式

- ❌ 不要把业务逻辑放在视图中，必须放到视图模型
- ❌ 不要硬编码颜色和尺寸，应该支持动态适配
- ❌ 不要忽略 Dark Mode 适配
