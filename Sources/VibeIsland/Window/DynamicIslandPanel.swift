import AppKit
import SwiftUI
import LLMQuotaKit
import CoreGraphics

final class DynamicIslandPanel: NSPanel {
    private(set) var positionMode: IslandPositionMode

    init(contentView: some View) {
        positionMode = SharedDefaults.loadSettings().islandPositionMode

        let notchAwareWidth = calculateNotchAwareWidth()
        let initialSize = NSSize(width: notchAwareWidth, height: 44)

        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 关键：面板层级必须高于刘海层
        // .floating 确保在菜单栏和刘海上方
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        if #available(macOS 14.0, *) {
            hostingView.sceneBridgingOptions = []
        }

        let container = NSView(frame: NSRect(origin: .zero, size: initialSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = .clear
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        self.contentView = container

        // 关键修复：延迟定位，确保窗口服务器已初始化面板
        // 多显示器环境下，立即设置 frame 可能被忽略或偏移
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyPosition()
            self.orderFront(nil)
        }
    }

    func setPositionMode(_ mode: IslandPositionMode) {
        guard mode != positionMode else { return }
        positionMode = mode
        applyPosition()
    }

    func resize(to size: NSSize, animated: Bool = true) {
        guard let screen = getCurrentScreen() else { return }
        let newFrame = calculateIslandFrame(for: size, on: screen)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
    }

    /// 获取内建显示器（有刘海的那个）
    /// 在多显示器环境下，优先使用内建显示器
    private func getBuiltInScreen() -> NSScreen {
        // 查找有刘海的显示器（safeAreaInsets.top > 24）
        if let notchScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 24 }) {
            return notchScreen
        }
        // 否则返回主显示器
        return NSScreen.main ?? NSScreen.screens.first!
    }

    private func applyPosition() {
        let screen = getBuiltInScreen()
        let safeAreaTop = screen.safeAreaInsets.top
        let gap: CGFloat = 4
        let windowSize = frame.size

        #if DEBUG
        print("[IslandPosition] screen: \(screen.localizedName)")
        print("[IslandPosition] screen.frame: \(screen.frame)")
        print("[IslandPosition] safeAreaInsets.top: \(safeAreaTop)")
        print("[IslandPosition] windowSize: \(windowSize)")
        #endif

        // 水平居中：使用 screen.frame.midX 计算
        let xPosition = screen.frame.midX - windowSize.width / 2
        // 垂直位置：菜单栏下方，刘海安全区域内
        let yPosition = screen.frame.maxY - safeAreaTop + gap

        let newFrame = NSRect(x: xPosition, y: yPosition, width: windowSize.width, height: windowSize.height)

        #if DEBUG
        print("[IslandPosition] calculated frame: \(newFrame)")
        #endif

        setFrame(newFrame, display: true)

        #if DEBUG
        print("[IslandPosition] final frame: \(frame)")
        print("[IslandPosition] final screen: \(self.screen?.localizedName ?? "nil")")
        #endif
    }

    /// 计算灵动岛面板在屏幕上的位置
    ///
    /// 定位策略（适配所有 Mac 机型，包括刘海屏）：
    /// - 水平方向：使用 `screen.frame.midX` 居中
    /// - 垂直方向：菜单栏下方，刘海安全区域内
    ///   - 使用 `screen.safeAreaInsets.top` 获取刘海高度
    ///
    /// 参考：
    /// - NSScreen.safeAreaInsets - Apple 官方文档
    /// - Atoll / MacIsland 开源项目定位策略
    private func calculateIslandFrame(for size: NSSize, on screen: NSScreen) -> NSRect {
        let safeAreaTop = screen.safeAreaInsets.top
        let screenFrame = screen.frame

        // 调试输出（可在发布前移除）
        #if DEBUG
        print("[IslandPosition] screen.frame: \(screenFrame)")
        print("[IslandPosition] screen.frame.midX: \(screenFrame.midX)")
        print("[IslandPosition] visibleFrame: \(screen.visibleFrame)")
        print("[IslandPosition] safeAreaInsets.top: \(safeAreaTop)")
        print("[IslandPosition] hasNotch: \(safeAreaTop > 24)")
        print("[IslandPosition] calculating x: \(screenFrame.midX - size.width / 2)")
        print("[IslandPosition] calculating y: \(screenFrame.maxY - safeAreaTop + 4)")
        #endif

        // 灵动岛位置：
        // - 水平居中：screen.frame.midX - size.width/2
        // - 垂直：刘海安全区域下方 4pt
        let gap: CGFloat = 4
        let yPosition = screenFrame.maxY - safeAreaTop + gap
        let xPosition = screenFrame.midX - size.width / 2

        return NSRect(
            x: xPosition,
            y: yPosition,
            width: size.width,
            height: size.height
        )
    }

    /// 获取当前鼠标所在的显示器（用于多显示器场景）
    private func getCurrentScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }
        
        #if DEBUG
        print("[IslandPosition] mouseLocation: \(mouseLocation)")
        print("[IslandPosition] selected screen: \(screen?.localizedName ?? "nil")")
        print("[IslandPosition] NSScreen.main: \(NSScreen.main?.localizedName ?? "nil")")
        print("[IslandPosition] all screens: \(NSScreen.screens.map { $0.localizedName })")
        #endif
        
        return screen ?? NSScreen.main
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

    /// 计算适配刘海的灵动岛宽度
    ///
    /// 返回值:
    /// - 500pt: 14" MacBook Pro (notch ~200pt, ~150pt visible each side)
    /// - 580pt: 16" MacBook Pro (notch ~238pt, ~171pt visible each side)
    /// - 420pt: 非刘海 Mac 或未知屏幕
    func calculateNotchAwareWidth() -> CGFloat {
        guard let screen = getBuiltInScreen() else { return 420 }
        
        let screenFrame = screen.frame
        let screenWidth = screenFrame.width
        
        // 14" MacBook Pro 屏幕宽度 ~3024pt (2x scale)
        // 16" MacBook Pro 屏幕宽度 ~3456pt (2x scale)
        // 使用 3100pt 作为分界值
        
        let hasNotch = screen.safeAreaInsets.top > 24
        guard hasNotch else { return 420 }
        
        return screenWidth >= 3100 ? 580 : 500
    }

