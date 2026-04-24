import SwiftUI

// 通知名称：灵动岛状态变化
extension Notification.Name {
    static let islandStateDidChange = Notification.Name("islandStateDidChange")
    static let toggleIslandState = Notification.Name("toggleIslandState")
}

@main
struct VibeIslandApp: App {
    @State private var stateManager = StateManager()
    @State private var panel: DynamicIslandPanel?
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .onAppear {
                    setupPanel()
                    stateManager.startMonitoring()
                    checkOnboardingStatus()
                    
                    // 监听点击切换
                    NotificationCenter.default.addObserver(
                        forName: .toggleIslandState,
                        object: nil,
                        queue: .main
                    ) { _ in
                        // toggleIslandState() 内部会 post .islandStateDidChange，
                        // 由下方 observer 统一处理 updateContentFrame，避免双重调用
                        stateManager.toggleIslandState()
                    }
                    
                    // 监听状态变化，更新panel大小
                    NotificationCenter.default.addObserver(
                        forName: .islandStateDidChange,
                        object: nil,
                        queue: .main
                    ) { notification in
                        let isExpanded = notification.userInfo?["isExpanded"] as? Bool ?? false
                        panel?.updateContentFrame(isExpanded: isExpanded)
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .environment(stateManager)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(stateManager)
        }
    }

    private func setupPanel() {
        let islandView = IslandView()
            .environment(stateManager)

        let newPanel = DynamicIslandPanel(contentView: islandView)
        newPanel.orderFront(nil)
        self.panel = newPanel
    }

    private func checkOnboardingStatus() {
        // 检查启动参数 (使用 CommandLine)
        let arguments = CommandLine.arguments

        if arguments.contains("--onboarding") {
            // 强制显示引导
            showOnboarding = true
            return
        }

        if arguments.contains("--skip-onboarding") {
            // 强制跳过引导
            showOnboarding = false
            return
        }

        // 默认逻辑：首次启动显示引导
        let hasShownOnboarding = UserDefaults.standard.bool(forKey: "hasShownOnboarding")
        if !hasShownOnboarding {
            showOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasShownOnboarding")
        }
    }
}

