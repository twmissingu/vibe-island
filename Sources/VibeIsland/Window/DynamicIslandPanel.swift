import AppKit
import SwiftUI
import LLMQuotaKit
import CoreGraphics

final class DynamicIslandPanel: NSPanel {
    private var currentScreen: NSScreen?
    
    init<Content: View>(contentView: Content) where Content: View {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let nh = screen.safeAreaInsets.top > 24 ? screen.safeAreaInsets.top : (screen.auxiliaryTopLeftArea != nil ? 38 : 0)
        let totalHeight = max(nh + 280, 400)
        let screenFrame = screen.frame
        
        // Panel 覆盖屏幕顶部区域（刘海 + 展开空间）
        let panelRect = NSRect(
            x: 0,
            y: screenFrame.maxY - totalHeight,
            width: screenFrame.width,
            height: totalHeight
        )
        
        super.init(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
        
        // 单一视图，通过 isExpandedMode 环境变量控制紧凑/展开
        let panelContent = DynamicIslandPanelContent(
            contentView: AnyView(contentView)
        )
        
        let hostingView = NSHostingView(rootView: panelContent)
        hostingView.wantsLayer = true
        hostingView.frame = NSRect(origin: .zero, size: panelRect.size)
        self.contentView = hostingView
        
        currentScreen = screen
        Task { @MainActor in
            ScreenParameters.shared.updateFromScreen()
        }
        
        // 应用激活时重新定位（init 时 app 可能还没完成启动）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    func updateContentFrame(isExpanded: Bool) {
        NotificationCenter.default.post(
            name: .panelExpandedStateChanged,
            object: nil,
            userInfo: ["isExpanded": isExpanded]
        )
    }
    
    @objc private func handleApplicationDidBecomeActive() {
        repositionIsland()
    }
    
    private func repositionIsland() {
        // 使用当前主屏幕（支持屏幕切换）
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 24 }) ?? NSScreen.main else { return }
        currentScreen = screen
        let nh = screen.safeAreaInsets.top > 24 ? screen.safeAreaInsets.top : (screen.auxiliaryTopLeftArea != nil ? 38 : 0)
        let totalHeight = max(nh + 280, 400)
        let screenFrame = screen.frame
        
        let panelRect = NSRect(
            x: 0,
            y: screenFrame.maxY - totalHeight,
            width: screenFrame.width,
            height: totalHeight
        )
        setFrame(panelRect, display: true)
        orderFront(nil)
    }
    
    /// 计算适配刘海的灵动岛宽度
    ///
    /// 返回值:
    /// - 500pt: 14" MacBook Pro (notch ~200pt)
    /// - 580pt: 16" MacBook Pro (notch ~238pt)
    /// - 420pt: 非刘海 Mac
    static func calculateNotchAwareWidth() -> CGFloat {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 24 }) ?? NSScreen.main ?? NSScreen.screens.first!
        let screenWidth = screen.frame.width
        let hasNotch = screen.safeAreaInsets.top > 24
        guard hasNotch else { return 420 }
        return screenWidth >= 3100 ? 580 : 500
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - SwiftUI Panel 内容

extension Notification.Name {
    static let panelExpandedStateChanged = Notification.Name("panelExpandedStateChanged")
}

struct DynamicIslandPanelContent: View {
    let contentView: AnyView
    @State private var isExpanded = false
    
    /// 灵动岛统一宽度
    private var islandWidth: CGFloat {
        DynamicIslandPanel.calculateNotchAwareWidth()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 紧凑视图 - 水平居中
            contentView
                .environment(\.isExpandedMode, false)
                .frame(width: islandWidth, alignment: .center)
            
            // 展开视图 - 水平居中
            if isExpanded {
                contentView
                    .environment(\.isExpandedMode, true)
                    .frame(width: islandWidth, alignment: .center)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(NotificationCenter.default.publisher(for: .panelExpandedStateChanged)) { notification in
            let expanded = notification.userInfo?["isExpanded"] as? Bool ?? false
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded = expanded
            }
        }
    }
}
