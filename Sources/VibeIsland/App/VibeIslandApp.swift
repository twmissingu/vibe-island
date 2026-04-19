import SwiftUI

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
        // 检查启动参数
        let arguments = ProcessInfo.processInfo.arguments

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

