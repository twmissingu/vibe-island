# Dynamic Island 交互增强实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (```- [ ]```) syntax for tracking.

**Goal:** 实现三个功能：1) 鼠标悬停 notch 展开/收起 2) 在 notch 直接 approve/deny 权限请求 3) AI 思考时 shimmer 动画（无像素宠物时）

**Architecture:** 基于现有 IslandView 架构，增加悬停检测和权限审批 UI，使用 TimelineView 实现 shimmer 效果

**Tech Stack:** SwiftUI, NSPanel, @Observable

---

## 文件结构

```
Sources/VibeIsland/
├── Views/
│   ├── IslandView.swift           # 主视图 - 增加悬停检测
│   ├── ExpandedIslandView.swift   # 展开视图 - 增加权限审批 UI
│   ├── PermissionApprovalView.swift  # 新建：权限审批组件
│   └── ShimmerModifier.swift      # 新建：shimmer 动画 Modifier
├── ViewModels/
│   └── StateManager.swift         # 状态管理 - 增加悬停状态
├── Services/
│   └── PermissionResponseService.swift  # 新建：权限响应服务
└── Models/
    └── PermissionDecision.swift   # 新建：权限决策模型
```

---

## Task 1: 鼠标悬停 notch 展开/收起

### Files:
- Modify: `Sources/VibeIsland/Views/IslandView.swift:46-72`
- Modify: `Sources/VibeIsland/ViewModels/StateManager.swift`
- Create: `Sources/VibeIsland/Views/HoverStateModifier.swift`

- [ ] **Step 1: 在 StateManager 中添加悬停状态**

```swift
// 修改 StateManager.swift
@Observable
final class StateManager {
    // 新增
    var isHovering = false
    
    var islandState: IslandState {
        get {
            // 现有逻辑：如果用户点击或悬停，展开
            if _isHovering { return .expanded }
            // ... 原有逻辑
        }
        set { _isHovering = newValue == .collapsed }
    }
}
```

- [ ] **Step 2: 创建 HoverStateModifier**

```swift
// Sources/VibeIsland/Views/HoverStateModifier.swift
import SwiftUI

struct HoverStateModifier: ViewModifier {
    @Environment(StateManager.self) private var stateManager
    let onHover: (Bool) -> Void
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                onHover(hovering)
            }
    }
}

extension View {
    func trackHover(onHover: @escaping (Bool) -> Void) -> some View {
        modifier(HoverStateModifier(onHover: onHover))
    }
}
```

- [ ] **Step 3: 修改 IslandView 添加悬停检测**

```swift
// 修改 IslandView.swift 第 46-72 行
struct IslandView: View {
    @Environment(StateManager.self) private var viewModel
    @Environment(\.isExpandedMode) private var isExpandedMode
    
    // 新增：悬停状态
    @State private var isHovering = false
    
    private var displayExpanded: Bool {
        if let forced = isExpandedMode {
            return forced
        }
        // 悬停时展开，或使用现有状态
        return isHovering || viewModel.islandState == .expanded
    }
    
    var body: some View {
        Group {
            if displayExpanded {
                ExpandedIslandView()
            } else {
                CompactIslandView()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            NotificationCenter.default.post(name: .toggleIslandState, object: nil)
        }
    }
}
```

- [ ] **Step 4: 运行测试验证**

Run: `xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests`
Expected: PASS（基础功能不受影响）

- [ ] **Step 5: Commit**

```bash
git add Sources/VibeIsland/Views/IslandView.swift Sources/VibeIsland/ViewModels/StateManager.swift
git commit -m "feat: add hover to expand notch"
```

---

## Task 2: 在 notch 直接 approve/deny 权限请求

### Files:
- Create: `Sources/VibeIsland/Models/PermissionRequest.swift`
- Create: `Sources/VibeIsland/Views/PermissionApprovalView.swift`
- Create: `Sources/VibeIsland/Services/PermissionResponseService.swift`
- Modify: `Sources/VibeIsland/Views/ExpandedIslandView.swift`
- Modify: `Sources/VibeIsland/Models/Session.swift`

- [ ] **Step 1: 创建权限请求模型**

```swift
// Sources/VibeIsland/Models/PermissionRequest.swift
import Foundation

public struct PermissionRequest: Identifiable, Codable, Sendable {
    public let id: UUID
    public let sessionId: String
    public let toolName: String
    public let toolInput: [String: String]?
    public let title: String?
    public let filePath: String?
    public let command: String?
    public let receivedAt: Date
    
    public init(
        id: UUID = UUID(),
        sessionId: String,
        toolName: String,
        toolInput: [String: String]? = nil,
        title: String? = nil,
        filePath: String? = nil,
        command: String? = nil,
        receivedAt: Date = .now
    ) {
        self.id = id
        self.sessionId = sessionId
        self.toolName = toolName
        self.toolInput = toolInput
        self.title = title
        self.filePath = filePath
        self.command = command
        self.receivedAt = receivedAt
    }
}

public enum PermissionDecision: String, Codable, Sendable {
    case allow
    case deny
    case block
}
```

- [ ] **Step 2: 创建权限响应服务**

```swift
// Sources/VibeIsland/Services/PermissionResponseService.swift
import Foundation

@MainActor
final class PermissionResponseService {
    static let shared = PermissionResponseService()
    
    private var pendingPermissions: [String: PermissionRequest] = [:]
    
    private init() {}
    
    func addPermissionRequest(_ request: PermissionRequest) {
        pendingPermissions[request.sessionId] = request
    }
    
    func getPermissionRequest(for sessionId: String) -> PermissionRequest? {
        pendingPermissions[sessionId]
    }
    
    func clearPermissionRequest(for sessionId: String) {
        pendingPermissions.removeValue(forKey: sessionId)
    }
    
    func sendDecision(_ decision: PermissionDecision, for sessionId: String) async -> Bool {
        guard let request = pendingPermissions[sessionId] else { return false }
        
        // 构建响应格式（与 Claude Code Hook 协议一致）
        let response: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": [
                    "behavior": decision == .allow ? "allow" : "deny"
                ]
            ]
        ]
        
        // 写入临时响应文件，hook 会读取
        let responsePath = NSString("~/").expandingTildeInPath + "/.vibe-island/permissions/\(sessionId).json"
        
        do {
            let data = try JSONSerialization.data(withJSONObject: response)
            try data.write(to: URL(fileURLWithPath: responsePath))
            pendingPermissions.removeValue(forKey: sessionId)
            return true
        } catch {
            return false
        }
    }
}
```

- [ ] **Step 3: 创建权限审批 UI 组件**

```swift
// Sources/VibeIsland/Views/PermissionApprovalView.swift
import SwiftUI

struct PermissionApprovalView: View {
    let request: PermissionRequest
    let onAllow: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.yellow)
                Text("权限请求")
                    .font(.headline)
            }
            
            // 工具信息
            HStack {
                Text(request.toolName)
                    .font(.subheadline.bold())
                if let title = request.title {
                    Text("- \(title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 文件路径或命令
            if let path = request.filePath {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.orange)
                    Text(path)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            if let cmd = request.command {
                HStack {
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(.blue)
                    Text(cmd)
                        .font(.caption)
                        .lineLimit(2)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // 按钮
            HStack(spacing: 12) {
                Button(action: onDeny) {
                    Label("拒绝", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Button(action: onAllow) {
                    Label("允许", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 4: 修改 ExpandedIslandView 集成权限审批**

```swift
// 修改 ExpandedIslandView.swift - 在权限请求时显示审批 UI
struct ExpandedIslandView: View {
    @Environment(StateManager.self) private var viewModel
    @State private var selectedTab: ExpandedTab = .sessions
    private var permissionService: PermissionResponseService { .shared }
    
    // 新增：获取当前等待权限的请求
    private var pendingPermission: PermissionRequest? {
        guard let session = sessionManager.sortedSessions.first(where: { $0.status == .waitingPermission }) else {
            return nil
        }
        return permissionService.getPermissionRequest(for: session.sessionId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 如果有待审批权限，显示审批 UI（优先于标签页）
            if let permission = pendingPermission {
                PermissionApprovalView(
                    request: permission,
                    onAllow: {
                        Task {
                            await permissionService.sendDecision(.allow, for: permission.sessionId)
                        }
                    },
                    onDeny: {
                        Task {
                            await permissionService.sendDecision(.deny, for: permission.sessionId)
                        }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                // 正常标签页
                tabBar
                Divider().opacity(0.2)
                tabContent.frame(height: 280)
            }
        }
        .animation(.spring(response: 0.3), value: pendingPermission != nil)
    }
}
```

- [ ] **Step 5: 修改 Session 处理权限事件**

```swift
// 修改 Sources/VibeIsland/Models/Session.swift - 在 handleEvent 中处理 PermissionRequest
// 在 HookHandler.swift 处理 PermissionRequest 事件时：
case .permissionRequest:
    let request = PermissionRequest(
        sessionId: event.sessionId,
        toolName: event.toolName ?? "Unknown",
        toolInput: event.toolInput,
        title: event.title,
        filePath: event.toolInput?["file_path"],
        command: event.toolInput?["command"]
    )
    PermissionResponseService.shared.addPermissionRequest(request)
```

- [ ] **Step 6: Commit**

```bash
git add Sources/VibeIsland/Models/PermissionRequest.swift Sources/VibeIsland/Views/PermissionApprovalView.swift Sources/VibeIsland/Services/PermissionResponseService.swift
git commit -m "feat: add permission approval UI in notch"
```

---

## Task 3: AI 思考时 shimmer 动画（无像素宠物时）

### Files:
- Create: `Sources/VibeIsland/Views/ShimmerModifier.swift`
- Modify: `Sources/VibeIsland/Views/IslandView.swift`
- Modify: `Sources/VibeIsland/Views/CompactIslandView.swift`

- [ ] **Step 1: 创建 ShimmerModifier**

```swift
// Sources/VibeIsland/Views/ShimmerModifier.swift
import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.4),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + phase)
                    }
                    .mask(content)
                }
            }
            .onAppear {
                if isActive {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 400
                    }
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 400
                    }
                } else {
                    phase = 0
                }
            }
    }
}

extension View {
    func shimmer(when isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}
```

- [ ] **Step 2: 创建 ThinkingIndicatorView（带 shimmer 的思考指示器）**

```swift
// Sources/VibeIsland/Views/ThinkingIndicatorView.swift
import SwiftUI

struct ThinkingIndicatorView: View {
    let showShimmer: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            // 三个点动画
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animate
                    )
            }
            
            Text("Thinking")
                .font(.caption)
                .foregroundStyle(.cyan)
        }
        .shimmer(when: showShimmer)
        .onAppear { animate = true }
    }
    
    @State private var animate = false
}
```

- [ ] **Step 3: 修改 CompactIslandView 集成 shimmer**

```swift
// 修改 IslandView.swift 中 CompactIslandView 部分
// 找到 thinking 状态显示的位置（约第 250-270 行）

// 修改后的代码
private var statusIndicator: some View {
    Group {
        switch aggregateState {
        case .thinking:
            // 有像素宠物时显示宠物，无宠物时显示 shimmer
            if showPet {
                petView
            } else {
                ThinkingIndicatorView(showShimmer: true)
            }
        case .coding:
            // ... 现有代码
        default:
            // ... 现有代码
        }
    }
}
```

- [ ] **Step 4: 运行测试验证**

Run: `xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/VibeIsland/Views/ShimmerModifier.swift Sources/VibeIsland/Views/ThinkingIndicatorView.swift Sources/VibeIsland/Views/IslandView.swift
git commit -m "feat: add shimmer animation for thinking state"
```

---

## 验收标准

- [ ] Task 1: 鼠标悬停 notch 区域时面板展开，移开后收起
- [ ] Task 2: 权限请求时显示 Allow/Deny 按钮，点击后发送决策
- [ ] Task 3: 无像素宠物时，thinking 状态显示 shimmer 闪烁动画
- [ ] 所有现有测试通过

---

## 自测检查清单

1. 悬停功能：
   - [ ] 鼠标进入 notch 区域时面板展开
   - [ ] 鼠标移开后面板收起
   - [ ] 动画平滑（无卡顿）

2. 权限审批：
   - [ ] 权限请求时显示审批 UI
   - [ ] 点击 Allow 按钮发送允许决策
   - [ ] 点击 Deny 按钮发送拒绝决策
   - [ ] 权限处理完成后 UI 自动隐藏

3. Shimmer 动画：
   - [ ] thinking 状态显示 shimmer 效果
   - [ ] 动画流畅，无性能问题
   - [ ] 有像素宠物时仍显示宠物（不显示 shimmer）
