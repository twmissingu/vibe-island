import SwiftUI

/// 紧凑设置视图 — 嵌入 ExpandedIslandView 内容区 (280pt)
/// 只展示核心开关，"打开完整设置…"跳转 macOS Settings scene
struct MiniSettingsView: View {
    @Environment(StateManager.self) private var viewModel
    let onDismiss: (() -> Void)?

    private var themeManager: ThemeManager {
        viewModel.settings.theme.manager
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("设置")
                    .font(.islandHeading.weight(.semibold))
                    .foregroundStyle(themeManager.primaryText)
                Spacer()
                Button { onDismiss?() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.islandBody)
                        .foregroundStyle(themeManager.iconColor)
                }
                .buttonStyle(.plain)
                .help("关闭设置")
            }
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 14) {
                    themeSection
                    Divider().opacity(0.2)
                    soundSection
                    Divider().opacity(0.2)
                    petSection
                    Divider().opacity(0.2)
                    monitorSection
                }
            }

            Spacer()

            Button("完整设置") {
                NotificationCenter.default.post(name: .openFullSettings, object: nil)
                onDismiss?()
            }
            .font(.islandBody)
            .foregroundStyle(.blue)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Theme

    private var themeSection: some View {
        HStack {
            Text("外观")
                .font(.islandBody)
                .foregroundStyle(themeManager.primaryText)
            Spacer()
            HStack(spacing: 8) {
                themeChip("极客", icon: "square.grid.3x3.fill", isSelected: viewModel.settings.theme == .pixel) {
                    viewModel.settings.theme = .pixel
                }
                themeChip("透明", icon: "circle.hexagongrid.fill", isSelected: viewModel.settings.theme == .glass) {
                    viewModel.settings.theme = .glass
                }
            }
        }
    }

    private func themeChip(_ title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.islandCompact)
                Text(title)
                    .font(.islandCompact)
            }
            .foregroundStyle(isSelected ? .white : .gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sound

    private var soundSection: some View {
        HStack {
            Text("音效")
                .font(.islandBody)
                .foregroundStyle(themeManager.primaryText)
            Spacer()
            Toggle(isOn: Binding(
                get: { viewModel.soundManager.isEnabled },
                set: { viewModel.soundManager.setEnabled($0) }
            )) { EmptyView() }
            .toggleStyle(.switch)
            .scaleEffect(0.7)
            .labelsHidden()
        }
    }

    // MARK: - Pet

    private var petSection: some View {
        HStack {
            Text("宠物")
                .font(.islandBody)
                .foregroundStyle(themeManager.primaryText)
            Spacer()
            Toggle(isOn: Binding(
                get: { viewModel.settings.petEnabled },
                set: { viewModel.settings.petEnabled = $0 }
            )) { EmptyView() }
            .toggleStyle(.switch)
            .scaleEffect(0.7)
            .labelsHidden()
        }
    }

    // MARK: - Monitor

    private var monitorSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("监控")
                    .font(.islandBody)
                    .foregroundStyle(themeManager.primaryText)
                Spacer()
            }
            Toggle(isOn: Binding(
                get: { viewModel.settings.claudeMonitorEnabled },
                set: { viewModel.settings.claudeMonitorEnabled = $0 }
            )) {
                Text("Claude Code")
                    .font(.islandBody)
                    .foregroundStyle(themeManager.secondaryText)
            }
            .toggleStyle(.switch)
            .scaleEffect(0.7)

            Toggle(isOn: Binding(
                get: { viewModel.settings.openCodeMonitorEnabled },
                set: { viewModel.settings.openCodeMonitorEnabled = $0 }
            )) {
                Text("OpenCode")
                    .font(.islandBody)
                    .foregroundStyle(themeManager.secondaryText)
            }
            .toggleStyle(.switch)
            .scaleEffect(0.7)
        }
    }
}
