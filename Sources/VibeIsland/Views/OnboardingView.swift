import SwiftUI
import LLMQuotaKit

// MARK: - 首次启动引导视图

/// 新用户首次启动时的引导流程
/// 包含：Hook 配置、平台选择、声音测试、宠物选择
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StateManager.self) private var stateManager
    
    @State private var currentStep = 0
    @State private var selectedPlatforms: Set<ProviderType> = []
    @State private var hookInstalled = false
    @State private var soundTested = false
    @State private var petSelected = false
    
    let totalSteps = 4
    
    var body: some View {
        VStack(spacing: 0) {
            // 进度指示器
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            
            // 内容区域
            Group {
                switch currentStep {
                case 0: WelcomeStep()
                case 1: PlatformSelectionStep(selectedPlatforms: $selectedPlatforms)
                case 2: HookSetupStep(installed: $hookInstalled, stateManager: stateManager)
                case 3: CompletionStep(selectedPlatforms: selectedPlatforms, hookInstalled: hookInstalled)
                default: EmptyView()
                }
            }
            
            // 底部按钮
            HStack {
                if currentStep > 0 {
                    Button("上一步") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep < totalSteps - 1 {
                    Button("下一步") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("开始使用") {
                        // 保存设置
                        var settings = stateManager.settings
                        settings.claudeMonitorEnabled = hookInstalled
                        settings.selectedPetID = "cat"
                        settings.petEnabled = true
                        SharedDefaults.saveSettings(settings)
                        SharedDefaults.saveEnrolled(selectedPlatforms)
                        
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button(currentStep == totalSteps - 1 ? "跳过" : "跳过引导") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Step 1: 欢迎

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "island.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            
            Text("欢迎使用 Vibe Island")
                .font(.title)
                .fontWeight(.bold)
            
            Text("你的 AI 编码助手状态监控平台\n实时监控 Claude Code、OpenCode、Codex 的运行状态")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Label("实时状态感知", systemImage: "bolt.fill")
                Label("声音提醒", systemImage: "speaker.wave.2.fill")
                Label("像素宠物", systemImage: "cat.fill")
                Label("多工具监控", systemImage: "rectangle.stack.fill")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(40)
    }
}

// MARK: - Step 2: 平台选择

struct PlatformSelectionStep: View {
    @Binding var selectedPlatforms: Set<ProviderType>
    
    var body: some View {
        VStack(spacing: 24) {
            Text("选择要监控的平台")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("你可以随时在设置中修改")
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                ForEach(ProviderType.allCases, id: \.self) { provider in
                    Button {
                        if selectedPlatforms.contains(provider) {
                            selectedPlatforms.remove(provider)
                        } else {
                            selectedPlatforms.insert(provider)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedPlatforms.contains(provider) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedPlatforms.contains(provider) ? .blue : .gray)
                            Text(provider.displayName)
                            Spacer()
                            Text(provider.keyDescription)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(40)
    }
}

// MARK: - Step 3: Hook 配置

struct HookSetupStep: View {
    @Binding var installed: Bool
    let stateManager: StateManager
    
    var body: some View {
        VStack(spacing: 24) {
            Text("配置 Claude Code Hook")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("安装 Hook 以实现实时状态感知")
                .foregroundStyle(.secondary)
            
            VStack(spacing: 16) {
                Button {
                    Task {
                        let result = await stateManager.installHooks()
                        if case .success = result {
                            installed = true
                        }
                    }
                } label: {
                    Label(installed ? "✅ 已安装" : "安装 Hook", systemImage: installed ? "checkmark.circle.fill" : "hammer.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(installed)
                
                if installed {
                    Text("✅ Hook 已成功安装\n重启 Claude Code 后生效")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Text("💡 提示：你也可以稍后在设置中安装")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(40)
    }
}

// MARK: - Step 4: 完成

struct CompletionStep: View {
    let selectedPlatforms: Set<ProviderType>
    let hookInstalled: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("设置完成！")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("已选择 \(selectedPlatforms.count) 个平台", systemImage: "checkmark")
                Label(hookInstalled ? "Hook 已安装" : "Hook 未安装（可在设置中安装）", systemImage: hookInstalled ? "checkmark" : "info.circle")
                Label("像素宠物已启用", systemImage: "checkmark")
                Label("声音提醒已启用", systemImage: "checkmark")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Text("点击「开始使用」进入主界面")
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

// MARK: - 辅助扩展

extension ProviderType {
    var keyDescription: String {
        switch self {
        case .mimo: return "小米 MIMO"
        case .kimi: return "Kimi"
        case .minimax: return "MiniMax"
        case .zai: return "智谱"
        case .ark: return "火山方舟"
        }
    }
}
