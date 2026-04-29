import SwiftUI

struct SettingsView: View {
    @Environment(StateManager.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

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
    @State private var soundVolume: Float = 1.0
    @State private var showPluginInfo = false

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

    

    var body: some View {
        NavigationStack {
            Form {
            // MARK: - 外观
            Section(NSLocalizedString("settings.appearance", comment: "Appearance")) {
                Picker(NSLocalizedString("settings.hud.style", comment: "Style"), selection: Binding(
                    get: { viewModel.settings.theme },
                    set: { viewModel.settings.theme = $0; saveSettings() }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .tint(.white)
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
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                HStack {
                    Text(NSLocalizedString("settings.sound.volume", comment: "Volume"))
                    Slider(value: $soundVolume, in: 0...1) { editing in
                        if !editing {
                            viewModel.soundManager.setVolume(soundVolume)
                        }
                    }
                    .tint(.blue)
                    Text("\(Int(soundVolume * 100))%")
                        .font(.system(size: 12))
                        .frame(width: 40)
                }

                testSoundButtons
            }

            // MARK: - 宠物设置
            Section(NSLocalizedString("settings.section.pet", comment: "Pet")) {
                Toggle(NSLocalizedString("settings.pet.enable", comment: "Enable Pet"), isOn: Binding(
                    get: { viewModel.settings.petEnabled },
                    set: { viewModel.settings.petEnabled = $0; saveSettings() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                if viewModel.settings.petEnabled {
                    petSkinSelectorView
                }
            }

            // MARK: - 监控
            Section(NSLocalizedString("settings.section.monitor", comment: "Monitor")) {
                Toggle(NSLocalizedString("settings.claudeMonitor", comment: "Claude Code"), isOn: Binding(
                    get: { isToolEnabled(.claudeCode) },
                    set: { setToolEnabled(.claudeCode, $0) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                Toggle(NSLocalizedString("settings.openCodeMonitor", comment: "OpenCode"), isOn: Binding(
                    get: { isToolEnabled(.openCode) },
                    set: { setToolEnabled(.openCode, $0) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .disabled(openCodePluginStatus != .installed)

                if openCodePluginStatus != .installed {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.orange)
                            .font(.system(size: 11))
                        Text("需安装插件")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - 插件
            Section {
                HStack {
                    Text("Claude Code")
                    Spacer()
                    pluginButton(isInstalled: hookStatus == .installed, action: {
                        Task { await performHookAction() }
                    })
                }
                if let msg = hookMessage {
                    HStack {
                        Text(msg)
                            .font(.system(size: 10))
                            .foregroundStyle(msg.hasPrefix("失败") || msg.hasPrefix("错误") ? .red : .green)
                        Spacer()
                    }
                }
                HStack {
                    Text("OpenCode")
                    Spacer()
                    pluginButton(isInstalled: openCodePluginStatus == .installed, action: {
                        Task { await performOpenCodePluginAction() }
                    })
                }
                if let msg = openCodePluginMessage {
                    HStack {
                        Text(msg)
                            .font(.system(size: 10))
                            .foregroundStyle(openCodePluginMessageIsError ? .red : .green)
                        Spacer()
                    }
                }
            } header: {
                HStack {
                    Text(NSLocalizedString("settings.section.plugin", comment: "Plugin"))
                    pluginInfoButton
                }
            }

            // MARK: - 系统
            Section(NSLocalizedString("settings.section.system", comment: "System")) {
                Toggle(NSLocalizedString("settings.launchAtLogin", comment: "Launch at Login"), isOn: Binding(
                    get: { viewModel.settings.launchAtLogin },
                    set: { viewModel.settings.launchAtLogin = $0; saveSettings() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
        }
            .formStyle(.grouped)
            .frame(width: 450, height: 400)
            .background(Color(white: 0.08))
            .scrollContentBackground(.hidden)
            .preferredColorScheme(.dark)
            .tint(.blue)
            .onAppear {
                // Force state refresh on appear
                loadSoundSettings()
                detectRunningTools()
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: "Settings"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.ok", comment: "OK")) {
                        dismiss()
                    }
                }

            }
            .task {
                await refreshHookStatus()
                await refreshOpenCodePluginStatus()
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
            hookMessage = "保存失败: \(error.localizedDescription)"
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
            openCodePluginMessage = "失败: \(error.localizedDescription)"
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

    private func pluginButton(isInstalled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isInstalled ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isInstalled ? .red : .blue)
                Text(isInstalled ? NSLocalizedString("settings.plugin.uninstall", comment: "Uninstall") : NSLocalizedString("settings.plugin.install", comment: "Install"))
                    .font(.system(size: 11))
                    .foregroundStyle(isInstalled ? .red : .blue)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pluginInfoButton: some View {
        Button {
            showPluginInfo = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPluginInfo, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("settings.plugin.purpose", comment: "Purpose"))
                    .font(.system(size: 12, weight: .semibold))
                Text(NSLocalizedString("settings.plugin.purpose.desc", comment: "Monitor AI coding tool status"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Divider()
                Text(NSLocalizedString("settings.plugin.security", comment: "Data Security"))
                    .font(.system(size: 12, weight: .semibold))
                Text(NSLocalizedString("settings.plugin.security.desc", comment: "Security description"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 180)
        }
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
                    Text(pet.name).tag(pet.id)
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
                Text("还需 \(remaining) 分钟升级")
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
