import SwiftUI

@main
struct LLMQuotaIslandApp: App {
    @State private var viewModel = QuotaViewModel()
    @State private var panel: DynamicIslandPanel?

    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .onAppear {
                    setupPanel()
                    viewModel.startPolling()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(viewModel)
        }
    }

    private func setupPanel() {
        let islandView = IslandView()
            .environment(viewModel)

        let newPanel = DynamicIslandPanel(contentView: islandView)
        newPanel.orderFront(nil)
        self.panel = newPanel
    }
}
