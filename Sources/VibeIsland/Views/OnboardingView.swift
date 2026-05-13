import SwiftUI

// MARK: - 首次启动引导视图

/// 新用户首次启动时的引导流程
/// 包含：插件配置、偏好设置、完成
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StateManager.self) private var stateManager

    @State private var currentStep = 0
    let totalSteps = 4

    // 插件安装状态
    @State private var claudeHookInstalled = false
    @State private var openCodePluginInstalled = false
    @State private var openCodeDetected = false

    // 偏好设置状态
    @State private var soundEnabled = true
    @State private var petEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            // 进度指示器
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .accessibilityIdentifier("progressDot")
                }
            }
            .padding(.top, 20)
            .accessibilityIdentifier("progressIndicator")

            // 内容区域
            Group {
                switch currentStep {
                case 0: WelcomeStep()
                case 1: PluginSetupStep(
                    claudeInstalled: $claudeHookInstalled,
                    openCodeInstalled: $openCodePluginInstalled,
                    openCodeDetected: openCodeDetected,
                    stateManager: stateManager
                )
                case 2: PreferencesStep(
                    soundEnabled: $soundEnabled,
                    petEnabled: $petEnabled,
                    stateManager: stateManager
                )
                case 3: CompletionStep(
                    claudeHookInstalled: claudeHookInstalled,
                    openCodePluginInstalled: openCodePluginInstalled,
                    soundEnabled: soundEnabled,
                    petEnabled: petEnabled
                )
                default: EmptyView()
                }
            }

            // 底部按钮
            HStack {
                if currentStep > 0 {
                    Button {
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Text(NSLocalizedString("onboarding.button.previous", comment: "Previous button"))
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentStep < totalSteps - 1 {
                    Button {
                        withAnimation { currentStep += 1 }
                    } label: {
                        Text(NSLocalizedString("onboarding.button.next", comment: "Next button"))
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("onboarding.button.getStarted", comment: "Get Started button"))
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("onboarding.button.skip", comment: "Skip"))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(width: 500, height: 420)
        .onAppear {
            loadInitialState()
        }
    }

    private func loadInitialState() {
        soundEnabled = stateManager.soundManager.isEnabled
        petEnabled = stateManager.settings.petEnabled
        openCodeDetected = stateManager.isOpenCodeInstalled()
        claudeHookInstalled = stateManager.hookInstaller.isHookInstalled
        openCodePluginInstalled = stateManager.isOpenCodePluginInstalled()
    }
}

// MARK: - Step 1: 欢迎

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "island.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(NSLocalizedString("onboarding.welcome.title", comment: "Welcome to Vibe Island"))
                .font(.title)
                .fontWeight(.bold)

            Text(NSLocalizedString("onboarding.welcome.subtitle", comment: "Subtitle"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Label(NSLocalizedString("onboarding.feature.realTime", comment: "Real-time Status Awareness"), systemImage: "bolt.fill")
                Label(NSLocalizedString("onboarding.feature.sound", comment: "Sound Alerts"), systemImage: "speaker.wave.2.fill")
                Label(NSLocalizedString("onboarding.feature.pet", comment: "Pixel Pet"), systemImage: "cat.fill")
                Label(NSLocalizedString("onboarding.feature.multiTool", comment: "Multi-Tool Monitoring"), systemImage: "rectangle.stack.fill")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(40)
    }
}

// MARK: - Step 2: 插件配置

struct PluginSetupStep: View {
    @Binding var claudeInstalled: Bool
    @Binding var openCodeInstalled: Bool
    let openCodeDetected: Bool
    let stateManager: StateManager

    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("onboarding.step.plugins", comment: "Configure Plugins"))
                .font(.title2)
                .fontWeight(.bold)

            // Claude Code Hook
            pluginCard(
                title: NSLocalizedString("onboarding.plugin.claude", comment: "Claude Code Hook"),
                description: NSLocalizedString("onboarding.plugin.claude.desc", comment: "Claude desc"),
                icon: "hammer.fill",
                isInstalled: claudeInstalled,
                installAction: {
                    Task {
                        let result = await stateManager.installHooks()
                        if case .success = result {
                            claudeInstalled = true
                        }
                    }
                }
            )

            // OpenCode Plugin
            if openCodeDetected {
                pluginCard(
                    title: NSLocalizedString("onboarding.plugin.opencode", comment: "OpenCode Plugin"),
                    description: NSLocalizedString("onboarding.plugin.opencode.desc", comment: "OpenCode desc"),
                    icon: "puzzlepiece.fill",
                    isInstalled: openCodeInstalled,
                    installAction: {
                        Task {
                            let result = await stateManager.installOpenCodePlugin()
                            if case .success = result {
                                openCodeInstalled = true
                            }
                        }
                    }
                )
            } else {
                HStack {
                    Image(systemName: "puzzlepiece.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("onboarding.plugin.opencode", comment: "OpenCode Plugin"))
                            .font(.islandHeading.weight(.medium))
                        Text(NSLocalizedString("onboarding.plugin.notDetected", comment: "Not detected"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .padding(40)
    }

    private func pluginCard(
        title: String,
        description: String,
        icon: String,
        isInstalled: Bool,
        installAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(isInstalled ? .green : .blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.islandHeading.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isInstalled {
                Label(
                    NSLocalizedString("onboarding.plugin.installed", comment: "Installed"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.islandBody)
                .foregroundStyle(.green)
            } else {
                Button(action: installAction) {
                    Text(NSLocalizedString("onboarding.plugin.install", comment: "Install"))
                        .font(.islandBody)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - Step 3: 偏好设置

struct PreferencesStep: View {
    @Binding var soundEnabled: Bool
    @Binding var petEnabled: Bool
    let stateManager: StateManager

    var body: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("onboarding.step.preferences", comment: "Preferences"))
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                Toggle(NSLocalizedString("onboarding.pref.launchAtLogin", comment: "Launch at Login"), isOn: Binding(
                    get: { stateManager.settings.launchAtLogin },
                    set: {
                        stateManager.settings.launchAtLogin = $0
                        saveSettings()
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                Toggle(NSLocalizedString("onboarding.pref.sound", comment: "Sound Alerts"), isOn: Binding(
                    get: { soundEnabled },
                    set: {
                        soundEnabled = $0
                        stateManager.soundManager.setEnabled($0)
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                Toggle(NSLocalizedString("onboarding.pref.pet", comment: "Show Pixel Pet"), isOn: Binding(
                    get: { petEnabled },
                    set: {
                        petEnabled = $0
                        stateManager.settings.petEnabled = $0
                        saveSettings()
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
        }
        .padding(40)
    }

    private func saveSettings() {
        SharedDefaults.saveSettings(stateManager.settings)
    }
}

// MARK: - Step 4: 完成

struct CompletionStep: View {
    let claudeHookInstalled: Bool
    let openCodePluginInstalled: Bool
    let soundEnabled: Bool
    let petEnabled: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text(NSLocalizedString("onboarding.completion.title", comment: "Setup Complete"))
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    claudeHookInstalled
                        ? NSLocalizedString("onboarding.completion.hookInstalled", comment: "Hook installed")
                        : NSLocalizedString("onboarding.completion.hookNotInstalled", comment: "Hook not installed"),
                    systemImage: claudeHookInstalled ? "checkmark" : "info.circle"
                )
                Label(
                    NSLocalizedString("onboarding.completion.petEnabled", comment: "Pixel pet enabled"),
                    systemImage: petEnabled ? "checkmark" : "xmark"
                )
                .foregroundStyle(petEnabled ? .primary : .secondary)
                Label(
                    NSLocalizedString("onboarding.completion.soundEnabled", comment: "Sound alerts enabled"),
                    systemImage: soundEnabled ? "checkmark" : "xmark"
                )
                .foregroundStyle(soundEnabled ? .primary : .secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Text(NSLocalizedString("onboarding.completion.instruction", comment: "Get Started instruction"))
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}
