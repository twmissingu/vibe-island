import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.twmissingu.VibeIsland", category: "CLIInstaller")

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
                    installCLIIfNeeded()
                    
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
            showOnboarding = true
            return
        }

        if arguments.contains("--skip-onboarding") {
            showOnboarding = false
            return
        }

        let hasShownOnboarding = UserDefaults.standard.bool(forKey: "hasShownOnboarding")
        if !hasShownOnboarding {
            showOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasShownOnboarding")
        }
    }

    private func installCLIIfNeeded() {
        guard let bundlePath = Bundle.main.path(forResource: "vibe-island", ofType: nil) else {
            logger.warning("CLI not found in app bundle")
            return
        }

        let cliDestination: URL
        let binDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin")

        if FileManager.default.fileExists(atPath: "/usr/local/bin/vibe-island") {
            cliDestination = URL(fileURLWithPath: "/usr/local/bin/vibe-island")
        } else if FileManager.default.fileExists(atPath: "\(binDir.path)/vibe-island") {
            cliDestination = binDir.appendingPathComponent("vibe-island")
        } else {
            do {
                try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
                cliDestination = binDir.appendingPathComponent("vibe-island")
            } catch {
                logger.error("Failed to create bin directory: \(error.localizedDescription)")
                return
            }
        }

        let currentVersion = getInstalledCLIVersion()
        let newVersion = getCLIVersion(from: bundlePath)

        if currentVersion == nil || currentVersion != newVersion {
            logger.info("Installing CLI to: \(cliDestination.path)")
            do {
                let cliURL = URL(fileURLWithPath: bundlePath)
                let destURL = cliDestination

                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: cliURL, to: destURL)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destURL.path)

                logger.info("CLI installed successfully")
            } catch {
                logger.error("Failed to install CLI: \(error.localizedDescription)")
            }
        } else {
            logger.info("CLI up to date, skipping install")
        }
    }

    private func getInstalledCLIVersion() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["vibe-island", "--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func getCLIVersion(from path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["\(path)", "--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

