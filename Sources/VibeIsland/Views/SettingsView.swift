import SwiftUI
import LLMQuotaKit

// MARK: - 工具来源

enum ToolSource: String, CaseIterable {
    case claudeCode = "claude"
    case openCode = "opencode"
    case codex = "codex"

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .openCode: return "OpenCode"
        case .codex: return "Codex"
        }
    }

    var sourceString: String { rawValue }
}

struct SettingsView: View {
    @Environment(StateManager.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddKey = false
    @State private var newKeyType: ProviderType = .mimo
    @State private var newKeyValue = ""
    @State private var keyValidation: String?

    // Hook 状态
    @State private var hookStatus: HookStatus = .unknown
    @State private var claudeRunning = false
    @State private var hookMessage: String?

    // OpenCode 插件状态
    @State private var openCodePluginStatus: OpenCodePluginHookStatus = .unknown
    @State private var openCodeRunning = false
    @State private var openCodePluginMessage: String?

    // 声音设置
    @State private var soundEnabled = true
    @State private var soundVolume: Float = 0.7

    // 多工具监控
    @State private var detectedTools: [ToolSource] = []
    
    // 宠物设置 - 仅展示已解锁宠物
    private var unlockedPets: [PetCatalog.PetInfo] {
        let allPetIds = PetType.allCases.map { $0.rawValue }
        let progress = PetProgressManager.shared
        return allPetIds.compactMap { id in
            guard let pet = PetType(rawValue: id),
                  progress.unlockedPets.contains(pet) else { return nil }
            return PetCatalog.PetInfo(id: id, name: pet.displayName, systemImage: pet.systemImage)
        }
    }

    // 已解锁的皮肤等级
    private var unlockedLevels: [PetLevel] {
        let progress = PetProgressManager.shared
        let currentLevel = progress.level(for: progress.selectedPet)
        return PetLevel.allCases.filter { level in level <= currentLevel }
    }

    // 上下文感知
    @State private var contextWarningThreshold: Double = 80.0

    var body: some View {
        NavigationStack {
            Form {
            Section(NSLocalizedString("settings.appearance", comment: "Appearance")) {
                Picker(NSLocalizedString("settings.hudStyle", comment: "HUD Style"), selection: Binding(
                    get: { viewModel.settings.theme },
                    set: { viewModel.settings.theme = $0; saveSettings() }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            // MARK: - Hook 管理
            Section(NSLocalizedString("settings.section.claudeHook", comment: "Claude Code Hook")) {
                hookStatusRow

                Button(hookActionTitle) {
                    Task { await performHookAction() }
                }
                .disabled(hookButtonDisabled)

                if let msg = hookMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(hookMessageIsError ? .red : .green)
                }

                // 安装帮助提示
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 \(NSLocalizedString("settings.hookInstallationGuide", comment: "Installation Guide"))：")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("1. \(NSLocalizedString("settings.hook.install.claude.required", comment: "Ensure Claude Code is installed"))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("2. \(NSLocalizedString("settings.hook.install.disk.access", comment: "Enable full disk access"))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("3. \(NSLocalizedString("settings.hook.install.restart.app", comment: "Restart app and try again"))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                HStack {
                    Text(NSLocalizedString("settings.claudeStatus", comment: "Claude Code Status"))
                    Spacer()
                    Text(claudeRunning ? NSLocalizedString("settings.claude.running", comment: "Running") : NSLocalizedString("settings.claude.notRunning", comment: "Not Running"))
                        .font(.system(size: 12))
                        .foregroundStyle(claudeRunning ? .green : .secondary)
                }
            }

            // MARK: - OpenCode 插件管理
            Section(NSLocalizedString("settings.section.opencodePlugin", comment: "OpenCode Plugin")) {
                openCodePluginStatusRow

                Button(openCodePluginActionTitle) {
                    Task { await performOpenCodePluginAction() }
                }
                .disabled(openCodePluginButtonDisabled)

                if let msg = openCodePluginMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(openCodePluginMessageIsError ? .red : .green)
                }

                HStack {
                    Text(NSLocalizedString("settings.opencodeStatus", comment: "OpenCode Status"))
                    Spacer()
                    Text(openCodeRunning ? NSLocalizedString("settings.claude.running", comment: "Running") : NSLocalizedString("settings.claude.notRunning", comment: "Not Running"))
                        .font(.system(size: 12))
                        .foregroundStyle(openCodeRunning ? .green : .secondary)
                }

                // 安装帮助提示
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 \(NSLocalizedString("settings.restartRequired", comment: "Restart required"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("settings.pluginInstallationGuide", comment: "Plugin Installation Guide"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            // MARK: - 声音设置
            Section(NSLocalizedString("settings.section.sound", comment: "Sound")) {
                Toggle(NSLocalizedString("settings.sound.enable", comment: "Enable Sound Effects"), isOn: Binding(
                    get: { soundEnabled },
                    set: {
                        soundEnabled = $0
                        viewModel.soundManager.setEnabled($0)
                    }
                ))

                HStack {
                    Text(NSLocalizedString("settings.sound.volume", comment: "Volume"))
                    Slider(value: $soundVolume, in: 0...1) { editing in
                        if !editing {
                            viewModel.soundManager.setVolume(soundVolume)
                        }
                    }
                    Text("\(Int(soundVolume * 100))%")
                        .font(.system(size: 12))
                        .frame(width: 40)
                }

                testSoundButtons
            }

    // MARK: - 宠物设置（增强版：含皮肤选择）
    Section(NSLocalizedString("settings.section.pet", comment: "Pixel Pet")) {
        Toggle(NSLocalizedString("settings.pet.enable", comment: "Enable Pixel Pet"), isOn: Binding(
            get: { viewModel.settings.petEnabled },
            set: { viewModel.settings.petEnabled = $0; saveSettings() }
        ))

        if viewModel.settings.petEnabled {
            petSkinSelectorView
        }
    }

            // MARK: - 多工具监控
            Section(NSLocalizedString("settings.section.multiTool", comment: "Multi-Tool Monitoring")) {
                Toggle(NSLocalizedString("settings.claudeMonitor", comment: "Claude Code Monitor"), isOn: Binding(
                    get: { isToolEnabled(.claudeCode) },
                    set: { setToolEnabled(.claudeCode, $0) }
                ))

                Toggle(NSLocalizedString("settings.openCodeMonitor", comment: "OpenCode Monitor"), isOn: Binding(
                    get: { isToolEnabled(.openCode) },
                    set: { setToolEnabled(.openCode, $0) }
                ))
                .disabled(openCodePluginStatus != .installed)

                if openCodePluginStatus != .installed {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.orange)
                            .font(.system(size: 11))
                        Text("需先安装插件")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                if !detectedTools.isEmpty {
                    HStack {
                        Text(NSLocalizedString("settings.detectedTools", comment: "Detected Tools"))
                        Spacer()
                        ForEach(detectedTools, id: \.self) { tool in
                            Label(tool.displayName, systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    HStack {
                        Text(NSLocalizedString("settings.detectedTools", comment: "Detected Tools"))
                        Spacer()
                        Text(NSLocalizedString("settings.none", comment: "None"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - 上下文感知
            Section(NSLocalizedString("settings.section.context", comment: "Context Awareness")) {
                Toggle(NSLocalizedString("settings.context.enable", comment: "Enable Context Monitoring"), isOn: Binding(
                    get: { viewModel.settings.contextMonitorEnabled },
                    set: { viewModel.settings.contextMonitorEnabled = $0; saveSettings() }
                ))

                if viewModel.settings.contextMonitorEnabled {
                    HStack {
                        Text(NSLocalizedString("settings.context.warningThreshold", comment: "Warning Threshold"))
                        Slider(value: $contextWarningThreshold, in: 50...95, step: 5) { editing in
                            if !editing {
                                viewModel.settings.contextWarningThreshold = contextWarningThreshold
                                saveSettings()
                            }
                        }
                        Text("\(Int(contextWarningThreshold))%")
                            .font(.system(size: 12))
                            .frame(width: 50)
                    }
                }
            }

            // MARK: - 刷新
            Section(NSLocalizedString("settings.section.refresh", comment: "Refresh")) {
                Picker(NSLocalizedString("settings.pollingInterval", comment: "Polling Interval"), selection: Binding(
                    get: { viewModel.settings.pollingIntervalMinutes },
                    set: { viewModel.settings.pollingIntervalMinutes = $0; saveSettings(); viewModel.startPolling() }
                )) {
                    Text("1 \(NSLocalizedString("settings.interval.1min", comment: "1 minute"))").tag(1)
                    Text("3 \(NSLocalizedString("settings.interval.3min", comment: "3 minutes"))").tag(3)
                    Text("5 \(NSLocalizedString("settings.interval.5min", comment: "5 minutes"))").tag(5)
                    Text("10 \(NSLocalizedString("settings.interval.10min", comment: "10 minutes"))").tag(10)
                    Text("15 \(NSLocalizedString("settings.interval.15min", comment: "15 minutes"))").tag(15)
                    Text("30 \(NSLocalizedString("settings.interval.30min", comment: "30 minutes"))").tag(30)
                }
            }

            // MARK: - API Keys
            Section("API Keys") {
                ForEach(ProviderType.allCases, id: \.self) { type in
                    providerRow(type)
                }

                Button(NSLocalizedString("settings.addKey", comment: "Add Key")) {
                    showAddKey = true
                }
            }

            // MARK: - 系统
            Section(NSLocalizedString("settings.section.system", comment: "System")) {
                Toggle(NSLocalizedString("settings.launchAtLogin", comment: "Launch at Login"), isOn: Binding(
                    get: { viewModel.settings.launchAtLogin },
                    set: { viewModel.settings.launchAtLogin = $0; saveSettings() }
                ))

                Button(NSLocalizedString("settings.refreshNow", comment: "Refresh Now")) {
                    Task { await viewModel.refresh() }
                }
            }
        }
            .formStyle(.grouped)
            .frame(width: 450, height: 680)
            .navigationTitle(NSLocalizedString("settings.title", comment: "Settings"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.ok", comment: "OK")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddKey) {
                addKeySheet
            }
        .task {
            await refreshHookStatus()
            await refreshOpenCodePluginStatus()
            loadSoundSettings()
            loadContextSettings()
            detectRunningTools()
        }
        }
    }

    // MARK: - Hook 管理

    private var hookStatusRow: some View {
        HStack {
            Text(NSLocalizedString("settings.hookStatus", comment: "Hook Status"))
            Spacer()
            Group {
                switch hookStatus {
                case .installed:
                    Label(NSLocalizedString("settings.hook.installed", comment: "Installed"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notInstalled:
                    Label(NSLocalizedString("settings.hook.notInstalled", comment: "Not Installed"), systemImage: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                case .unknown:
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .font(.system(size: 12))
        }
    }

    private var hookActionTitle: String {
        switch hookStatus {
        case .installed: NSLocalizedString("settings.uninstallHook", comment: "Uninstall Hook")
        case .notInstalled, .unknown: NSLocalizedString("settings.installHook", comment: "Install Hook")
        }
    }

    private var hookButtonDisabled: Bool {
        hookStatus == .unknown
    }

    private var hookMessageIsError: Bool {
        hookMessage?.hasPrefix("失败") == true || hookMessage?.hasPrefix("错误") == true
    }

    private func performHookAction() async {
        hookMessage = nil
        let result: Result<String, Error>

        switch hookStatus {
        case .installed:
            result = await viewModel.uninstallHooks()
        case .notInstalled, .unknown:
            result = await viewModel.installHooks()
        }

        switch result {
        case .success(let msg):
            hookMessage = msg
            await refreshHookStatus()
        case .failure(let error):
            hookMessage = NSLocalizedString("settings.saveFailed", comment: "Save failed: %@")
            await refreshHookStatus()
        }
    }

    private func refreshHookStatus() async {
        hookStatus = viewModel.hookInstaller.isHookInstalled ? .installed : .notInstalled
        claudeRunning = viewModel.isClaudeCodeRunning()
    }

    enum HookStatus {
        case installed, notInstalled, unknown
    }

    // MARK: - OpenCode 插件管理

    enum OpenCodePluginHookStatus {
        case installed, notInstalled, unknown
    }

    private var openCodePluginStatusRow: some View {
        HStack {
            Text(NSLocalizedString("settings.hookStatus", comment: "Hook Status"))
            Spacer()
            Group {
                switch openCodePluginStatus {
                case .installed:
                    Label(NSLocalizedString("settings.hook.installed", comment: "Installed"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notInstalled:
                    Label(NSLocalizedString("settings.hook.notInstalled", comment: "Not Installed"), systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                case .unknown:
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .font(.system(size: 12))
        }
    }

    private var openCodePluginActionTitle: String {
        switch openCodePluginStatus {
        case .installed: NSLocalizedString("settings.uninstallPlugin", comment: "Uninstall Plugin")
        case .notInstalled, .unknown: NSLocalizedString("settings.installPlugin", comment: "Install Plugin")
        }
    }

    private var openCodePluginButtonDisabled: Bool {
        openCodePluginStatus == .unknown
    }

    private var openCodePluginMessageIsError: Bool {
        openCodePluginMessage?.hasPrefix("失败") == true || openCodePluginMessage?.hasPrefix("错误") == true
    }

    private func performOpenCodePluginAction() async {
        openCodePluginMessage = nil
        let result: Result<String, Error>

        switch openCodePluginStatus {
        case .installed:
            result = await viewModel.uninstallOpenCodePlugin()
        case .notInstalled, .unknown:
            result = await viewModel.installOpenCodePlugin()
        }

        switch result {
        case .success(let msg):
            openCodePluginMessage = msg
            await refreshOpenCodePluginStatus()
        case .failure(let error):
            openCodePluginMessage = NSLocalizedString("settings.saveFailed", comment: "Save failed: %@")
            await refreshOpenCodePluginStatus()
        }
    }

    private func refreshOpenCodePluginStatus() async {
        openCodePluginStatus = viewModel.isOpenCodePluginInstalled() ? .installed : .notInstalled
        openCodeRunning = viewModel.isOpenCodeRunning()
    }

    // MARK: - 声音设置

    private var testSoundButtons: some View {
        HStack {
            Text(NSLocalizedString("settings.soundTest", comment: "Test Sound"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                testSoundButton(NSLocalizedString("settings.soundTestPermission", comment: "Permission"), type: .permissionRequest)
                testSoundButton(NSLocalizedString("settings.soundTestCompleted", comment: "Completed"), type: .completed)
                testSoundButton(NSLocalizedString("settings.soundTestError", comment: "Error"), type: .error)
                testSoundButton(NSLocalizedString("settings.soundTestCompacting", comment: "Compacting"), type: .compacting)
            }
        }
    }

    private func testSoundButton(_ title: String, type: SoundType) -> some View {
        Button(title) {
            Task {
                await viewModel.soundManager.play(type)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func loadSoundSettings() {
        soundEnabled = viewModel.soundManager.isEnabled
        soundVolume = viewModel.soundManager.volume
    }

    // 已移除宠物大小设置功能

    // MARK: - 多工具监控

    private func isToolEnabled(_ tool: ToolSource) -> Bool {
        switch tool {
        case .claudeCode: return viewModel.settings.claudeMonitorEnabled
        case .openCode, .codex: return viewModel.settings.openCodeMonitorEnabled
        }
    }

    private func setToolEnabled(_ tool: ToolSource, _ enabled: Bool) {
        switch tool {
        case .claudeCode: viewModel.settings.claudeMonitorEnabled = enabled
        case .openCode, .codex: viewModel.settings.openCodeMonitorEnabled = enabled
        }
        saveSettings()
    }

    private func detectRunningTools() {
        var detected: [ToolSource] = []
        let sm = SessionManager.shared

        // Claude Code 会话 source 为 nil（CLI 不设置该字段）
        if sm.hasClaudeCodeSessions {
            detected.append(.claudeCode)
        }
        for source: ToolSource in [.openCode, .codex] {
            let sessions = sm.sessions(from: source.sourceString)
            if !sessions.isEmpty {
                detected.append(source)
            }
        }
        detectedTools = detected
    }

    // MARK: - 上下文感知

    private func loadContextSettings() {
        contextWarningThreshold = viewModel.settings.contextWarningThreshold
    }

    // MARK: - Provider Row

    @ViewBuilder
    private func providerRow(_ type: ProviderType) -> some View {
        let enrolled = SharedDefaults.loadEnrolled()
        let isEnrolled = enrolled.contains(type)

        HStack {
            Text(type.displayName)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            if isEnrolled {
                Text(NSLocalizedString("settings.configured", comment: "Configured"))
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Button(NSLocalizedString("settings.delete", comment: "Delete"), role: .destructive) {
                    viewModel.keychain.delete(for: type.rawValue)
                    var updated = enrolled
                    updated.remove(type)
                    SharedDefaults.saveEnrolled(updated)
                }
                .font(.system(size: 11))
            } else {
                Text(NSLocalizedString("settings.notConfigured", comment: "Not Configured"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var addKeySheet: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("settings.addKeyTitle", comment: "Add API Key"))
                .font(.headline)

            Picker(NSLocalizedString("settings.platform", comment: "Platform"), selection: $newKeyType) {
                ForEach(ProviderType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            SecureField(NSLocalizedString("settings.pasteApiKey", comment: "Paste API Key"), text: $newKeyValue)
                .textFieldStyle(.roundedBorder)

            if let msg = keyValidation {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Button(NSLocalizedString("settings.cancel", comment: "Cancel")) { showAddKey = false }
                Spacer()
                Button(NSLocalizedString("settings.save", comment: "Save")) {
                    saveNewKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newKeyValue.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
    }

    private func saveNewKey() {
        do {
            try viewModel.keychain.save(key: newKeyValue, for: newKeyType.rawValue)
            var enrolled = SharedDefaults.loadEnrolled()
            enrolled.insert(newKeyType)
            SharedDefaults.saveEnrolled(enrolled)
            newKeyValue = ""
            keyValidation = nil
            showAddKey = false
        } catch {
            keyValidation = NSLocalizedString("settings.saveFailed", comment: "Save failed: %@")
        }
    }

    private func saveSettings() {
        SharedDefaults.saveSettings(viewModel.settings)
    }

    // MARK: - 宠物皮肤选择器视图
    @ViewBuilder
    private var petSkinSelectorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 宠物选择
            Picker(NSLocalizedString("settings.petImage", comment: "Pet Image"), selection: Binding(
                get: { viewModel.settings.selectedPetID },
                set: {
                    viewModel.settings.selectedPetID = $0
                    savePetLevel()
                    saveSettings()
                }
            )) {
                ForEach(unlockedPets, id: \.id) { pet in
                    HStack {
                        Image(systemName: pet.systemImage)
                        Text(pet.name)
                    }.tag(pet.id)
                }
            }

            // 皮肤等级选择
            VStack(alignment: .leading, spacing: 6) {
                Text("皮肤等级")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                // 皮肤等级网格
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                    ForEach(unlockedLevels, id: \.self) { level in
                        skinLevelButton(level)
                    }
                }
            }

            // 等级进度条
            levelProgressView
        }
    }

    @ViewBuilder
    private func skinLevelButton(_ level: PetLevel) -> some View {
        let isSelected = viewModel.settings.selectedPetLevel == level.rawValue
        let canUnlock = canUnlockLevel(level)

        Button {
            selectLevel(level)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(height: 50)

                    // 预览宠物
                    PetView(
                        petId: viewModel.settings.selectedPetID,
                        level: level,
                        scale: 2.0
                    )
                    .allowsHitTesting(false)
                }

                Text(level.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canUnlock)
        .opacity(canUnlock ? 1 : 0.5)
    }

    @ViewBuilder
    private var levelProgressView: some View {
        let progress = PetProgressManager.shared
        let selectedPet = PetType(rawValue: viewModel.settings.selectedPetID) ?? .cat
        let level = progress.level(for: selectedPet)
        let progressValue = progress.levelProgress(for: selectedPet)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(level.displayName) 进度")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progressValue * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progressValue)
                .tint(.accentColor)

            if let remaining = progress.minutesToNextLevel(for: selectedPet), remaining > 0 {
                Text("还需 \(remaining) ��钟升级")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func selectLevel(_ level: PetLevel) {
        guard canUnlockLevel(level) else { return }
        let selectedPet = PetType(rawValue: viewModel.settings.selectedPetID) ?? .cat
        let progress = PetProgressManager.shared
        progress.setSelectedSkinLevel(level, for: selectedPet)
        viewModel.settings.selectedPetLevel = level.rawValue
        saveSettings()
    }

    private func canUnlockLevel(_ level: PetLevel) -> Bool {
        let progress = PetProgressManager.shared
        let selectedPet = PetType(rawValue: viewModel.settings.selectedPetID) ?? .cat
        let actualLevel = progress.level(for: selectedPet)
        return actualLevel >= level
    }

    private func savePetLevel() {
        PetProgressManager.shared.selectedPet = PetType(rawValue: viewModel.settings.selectedPetID) ?? .cat
    }
}

// MARK: - 宠物目录

struct PetCatalog {
    struct PetInfo: Identifiable {
        let id: String
        let name: String
        let systemImage: String
    }

    static let allPets: [PetInfo] = [
        PetInfo(id: "cat", name: NSLocalizedString("pet.cat", comment: "Cat"), systemImage: "cat"),
        PetInfo(id: "dog", name: NSLocalizedString("pet.dog", comment: "Dog"), systemImage: "dog"),
        PetInfo(id: "rabbit", name: NSLocalizedString("pet.rabbit", comment: "Rabbit"), systemImage: "hare"),
        PetInfo(id: "hamster", name: NSLocalizedString("pet.hamster", comment: "Hamster"), systemImage: "pawprint"),
        PetInfo(id: "fox", name: NSLocalizedString("pet.fox", comment: "Fox"), systemImage: "leaf"),
        PetInfo(id: "penguin", name: NSLocalizedString("pet.penguin", comment: "Penguin"), systemImage: "cloud"),
        PetInfo(id: "owl", name: NSLocalizedString("pet.owl", comment: "Owl"), systemImage: "moon"),
        PetInfo(id: "robot", name: NSLocalizedString("pet.robot", comment: "Robot"), systemImage: "robot"),
    ]
}
