import SwiftUI
import LLMQuotaKit

struct SettingsView: View {
    @Environment(StateManager.self) private var viewModel
    @State private var showAddKey = false
    @State private var newKeyType: ProviderType = .mimo
    @State private var newKeyValue = ""
    @State private var keyValidation: String?

    var body: some View {
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

                Toggle("像素宠物", isOn: Binding(
                    get: { viewModel.settings.petEnabled },
                    set: { viewModel.settings.petEnabled = $0; saveSettings() }
                ))
            }

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

            Section("API Keys") {
                ForEach(ProviderType.allCases, id: \.self) { type in
                    providerRow(type)
                }

                Button("添加 Key") {
                    showAddKey = true
                }
            }

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
        .frame(width: 400, height: 500)
        .sheet(isPresented: $showAddKey) {
            addKeySheet
        }
    }

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
