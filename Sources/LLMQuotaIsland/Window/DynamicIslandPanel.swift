import AppKit
import SwiftUI

final class DynamicIslandPanel: NSPanel {
    private(set) var positionMode: IslandPositionMode

    init(contentView: some View) {
        positionMode = SharedDefaults.loadSettings().islandPositionMode

        let initialSize = NSSize(width: 420, height: 44)

        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar + 1
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
        applyPosition()
    }

    func setPositionMode(_ mode: IslandPositionMode) {
        guard mode != positionMode else { return }
        positionMode = mode
        applyPosition()
    }

    func resize(to size: NSSize, animated: Bool = true) {
        guard let screen = screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let newOrigin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height - 8
        )
        let newFrame = NSRect(origin: newOrigin, size: size)

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

    private func applyPosition() {
        guard let screen = screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let frame = self.frame
        let origin = NSPoint(
            x: screenFrame.midX - frame.width / 2,
            y: screenFrame.maxY - frame.height - 8
        )
        setFrameOrigin(origin)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
