import SwiftUI
import LLMQuotaKit

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
        // 解锁逻辑：默认解锁前3个宠物，后续可根据使用时长、成就等条件解锁更多
        let defaultUnlockedIds: Set<String> = ["cat", "dog", "rabbit"]
        return PetCatalog.allPets.filter { defaultUnlockedIds.contains($0.id) }
        // 后续扩展：使用 .filter { viewModel.unlockedPetIds.contains($0.id) }
    }

    // 上下文感知
    @State private var contextWarningThreshold: Double = 80.0

    var body: some View {
        NavigationStack {
            Form {
            Section("外观") {
                Picker("HUD 风格", selection: Binding(
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
            Section("Claude Code Hook") {
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
                    Text("💡 安装失败？按以下步骤解决：")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("1. 确保已安装Claude Code且能在终端执行`claude`命令")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("2. 开启完全磁盘访问权限：系统设置→隐私与安全性→完全磁盘访问→添加Vibe Island")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("3. 重启App后重新尝试安装即可")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                HStack {
                    Text("Claude Code 状态")
                    Spacer()
                    Text(claudeRunning ? "运行中" : "未运行")
                        .font(.system(size: 12))
                        .foregroundStyle(claudeRunning ? .green : .secondary)
                }
            }

            // MARK: - OpenCode 插件管理
            Section("OpenCode 插件") {
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
                    Text("OpenCode 状态")
                    Spacer()
                    Text(openCodeRunning ? "运行中" : "未运行")
                        .font(.system(size: 12))
                        .foregroundStyle(openCodeRunning ? .green : .secondary)
                }

                // 安装帮助提示
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 安装后需要重启 OpenCode 才能生效")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("插件会调用 vibe-island CLI，CLI 需要从 App 中自动安装")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            // MARK: - 声音设置
            Section("声音") {
                Toggle("启用提示音", isOn: Binding(
                    get: { soundEnabled },
                    set: {
                        soundEnabled = $0
                        viewModel.soundManager.setEnabled($0)
                    }
                ))

                HStack {
                    Text("音量")
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

    // MARK: - 宠物设置
    Section("像素宠物") {
        Toggle("启用像素宠物", isOn: Binding(
            get: { viewModel.settings.petEnabled },
            set: { viewModel.settings.petEnabled = $0; saveSettings() }
        ))

        if viewModel.settings.petEnabled {
            Picker("宠物形象", selection: Binding(
                get: { viewModel.settings.selectedPetID },
                set: { viewModel.settings.selectedPetID = $0; saveSettings() }
            )) {
                ForEach(unlockedPets, id: \.id) { pet in
                    Text(pet.name).tag(pet.id)
                }
            }
        }
    }

            // MARK: - 多工具监控
            Section("多工具监控") {
                Toggle("Claude Code 监控", isOn: Binding(
                    get: { isToolEnabled(.claudeCode) },
                    set: { setToolEnabled(.claudeCode, $0) }
                ))

                Toggle("OpenCode 监控", isOn: Binding(
                    get: { isToolEnabled(.openCode) },
                    set: { setToolEnabled(.openCode, $0) }
                ))

                if !detectedTools.isEmpty {
                    HStack {
                        Text("检测到的工具")
                        Spacer()
                        ForEach(detectedTools, id: \.self) { tool in
                            Label(tool.displayName, systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    HStack {
                        Text("检测到的工具")
                        Spacer()
                        Text("无")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - 上下文感知
            Section("上下文感知") {
                Toggle("启用上下文监控", isOn: Binding(
                    get: { viewModel.settings.contextMonitorEnabled },
                    set: { viewModel.settings.contextMonitorEnabled = $0; saveSettings() }
                ))

                if viewModel.settings.contextMonitorEnabled {
                    HStack {
                        Text("警告阈值")
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
            Section("刷新") {
                Picker("轮询间隔", selection: Binding(
                    get: { viewModel.settings.pollingIntervalMinutes },
                    set: { viewModel.settings.pollingIntervalMinutes = $0; saveSettings(); viewModel.startPolling() }
                )) {
                    Text("1 分钟").tag(1)
                    Text("3 分钟").tag(3)
                    Text("5 分钟").tag(5)
                    Text("10 分钟").tag(10)
                    Text("15 分钟").tag(15)
                    Text("30 分钟").tag(30)
                }
            }

            // MARK: - API Keys
            Section("API Keys") {
                ForEach(ProviderType.allCases, id: \.self) { type in
                    providerRow(type)
                }

                Button("添加 Key") {
                    showAddKey = true
                }
            }

            // MARK: - 系统
            Section("系统") {
                Toggle("开机自启", isOn: Binding(
                    get: { viewModel.settings.launchAtLogin },
                    set: { viewModel.settings.launchAtLogin = $0; saveSettings() }
                ))

                Button("立即刷新所有") {
                    Task { await viewModel.refresh() }
                }
            }
        }
            .formStyle(.grouped)
            .frame(width: 450, height: 680)
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
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
            Text("Hook 状态")
            Spacer()
            Group {
                switch hookStatus {
                case .installed:
                    Label("已安装", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notInstalled:
                    Label("未安装", systemImage: "xmark.circle.fill")
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
        case .installed: "卸载 Hook"
        case .notInstalled, .unknown: "安装 Hook"
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
            hookMessage = "失败: \(error.localizedDescription)"
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
            Text("插件状态")
            Spacer()
            Group {
                switch openCodePluginStatus {
                case .installed:
                    Label("已安装", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notInstalled:
                    Label("未安装", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
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
        case .installed: "卸载插件"
        case .notInstalled, .unknown: "安装插件"
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
            Text("测试提示音")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                testSoundButton("审批", type: .permissionRequest)
                testSoundButton("完成", type: .completed)
                testSoundButton("错误", type: .error)
                testSoundButton("压缩", type: .compacting)
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
        case .openCode: return viewModel.settings.openCodeMonitorEnabled
        }
    }

    private func setToolEnabled(_ tool: ToolSource, _ enabled: Bool) {
        switch tool {
        case .claudeCode: viewModel.settings.claudeMonitorEnabled = enabled
        case .openCode: viewModel.settings.openCodeMonitorEnabled = enabled
        }
        saveSettings()
    }

    private func detectRunningTools() {
        var detected: [ToolSource] = []
        let aggregator = MultiToolAggregator.shared

        // 检测各工具是否有活跃会话
        for source in ToolSource.allCases {
            let sessions = aggregator.sessions(from: source)
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
                Text("已配置 ✅")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Button("删除", role: .destructive) {
                    viewModel.keychain.delete(for: type.rawValue)
                    var updated = enrolled
                    updated.remove(type)
                    SharedDefaults.saveEnrolled(updated)
                }
                .font(.system(size: 11))
            } else {
                Text("未配置")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var addKeySheet: some View {
        VStack(spacing: 16) {
            Text("添加 API Key")
                .font(.headline)

            Picker("平台", selection: $newKeyType) {
                ForEach(ProviderType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            SecureField("粘贴 API Key", text: $newKeyValue)
                .textFieldStyle(.roundedBorder)

            if let msg = keyValidation {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Button("取消") { showAddKey = false }
                Spacer()
                Button("保存") {
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
            keyValidation = "保存失败: \(error.localizedDescription)"
        }
    }

    private func saveSettings() {
        SharedDefaults.saveSettings(viewModel.settings)
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
        PetInfo(id: "cat", name: "猫咪", systemImage: "cat"),
        PetInfo(id: "dog", name: "小狗", systemImage: "dog"),
        PetInfo(id: "rabbit", name: "兔子", systemImage: "hare"),
        PetInfo(id: "hamster", name: "仓鼠", systemImage: "pawprint"),
        PetInfo(id: "fox", name: "狐狸", systemImage: "leaf"),
        PetInfo(id: "penguin", name: "企鹅", systemImage: "cloud"),
        PetInfo(id: "owl", name: "猫头鹰", systemImage: "moon"),
        PetInfo(id: "robot", name: "机器人", systemImage: "robot"),
    ]
}
