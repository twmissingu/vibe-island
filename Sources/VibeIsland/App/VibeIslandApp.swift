import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.twmissingu.VibeIsland", category: "CLIInstaller")
private let firstLaunchKey = "VibeIslandFirstLaunchComplete"

extension Notification.Name {
    static let islandStateDidChange = Notification.Name("islandStateDidChange")
    static let toggleIslandState = Notification.Name("toggleIslandState")
    static let openFullSettings = Notification.Name("openFullSettings")
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
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .environment(stateManager)
                }
                .onAppear {
                    setupPanel()
                    stateManager.startMonitoring()
                    runFirstLaunchSetup()

                    // 监听点击切换
                    NotificationCenter.default.addObserver(
                        forName: .toggleIslandState,
                        object: nil,
                        queue: .main
                    ) { _ in
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

                    // 从 MiniSettingsView 打开完整设置
                    NotificationCenter.default.addObserver(
                        forName: .openFullSettings,
                        object: nil,
                        queue: .main
                    ) { _ in
                        stateManager.openFullSettings()
                    }
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

    // MARK: - 首次启动自动配置（拖拽安装即完成）

    /// 首次启动时自动执行：创建运行时目录、安装 CLI、安装 hook/插件
    /// 用户只需将 .app 拖入 Applications 即可，无需手动配置
    private func runFirstLaunchSetup() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: firstLaunchKey)

        // 1. 创建运行时目录
        createRuntimeDirectories()

        // 2. 安装 CLI
        installCLI()

        // 3. 首次启动：自动安装 hooks 和插件（静默、最佳尝试）
        if isFirstLaunch {
            logger.info("首次启动 — 开始自动配置...")
            autoInstallHooks()

            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            logger.info("首次启动配置完成")

            // 显示偏好设置引导（已跳过 hooks 安装步骤）
            showOnboarding = true
        }
    }

    /// 创建 ~/.vibe-island/ 运行时目录
    private func createRuntimeDirectories() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dirs = [
            home.appendingPathComponent(".vibe-island/sessions"),
            home.appendingPathComponent(".vibe-island/bin"),
        ]
        for dir in dirs {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// 从 app bundle 安装 CLI 到 PATH
    private func installCLI() {
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

    /// 静默安装 Claude Code hooks 和 OpenCode 插件
    /// 最佳尝试：安装失败不影响 app 正常使用，用户稍后可通过 UI 手动安装
    private func autoInstallHooks() {
        let installer = HookAutoInstaller.shared

        // 安装 Claude Code hook（无 UI 反馈，仅日志）
        Task {
            let claudeResult = await installer.install()
            switch claudeResult {
            case .success:
                logger.info("Claude Code hooks auto-installed")
            case .failure(let error):
                logger.warning("Claude Code hooks auto-install skipped: \(error.localizedDescription)")
            }

            // 安装 OpenCode 插件（如果检测到 OpenCode）
            if installer.isOpenCodeInstalled {
                let ocResult = await installer.installOpenCodePlugin()
                switch ocResult {
                case .success:
                    logger.info("OpenCode plugin auto-installed")
                case .failure(let error):
                    logger.warning("OpenCode plugin auto-install skipped: \(error.localizedDescription)")
                }
            }
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

