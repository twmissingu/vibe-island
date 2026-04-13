import SwiftUI

@main
struct VibeIslandApp: App {
    @State private var stateManager = StateManager()
    @State private var panel: DynamicIslandPanel?

    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .onAppear {
                    setupPanel()
                    stateManager.startMonitoring()
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
}
