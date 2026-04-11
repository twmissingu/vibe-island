import SwiftUI
import LLMQuotaKit

struct IslandView: View {
    @Environment(QuotaViewModel.self) private var viewModel

    var body: some View {
        Group {
            switch viewModel.islandState {
            case .compact:
                CompactIslandView()
            case .expanded:
                ExpandedIslandView()
            }
        }
        .onTapGesture {
            viewModel.toggleIslandState()
        }
    }
}

// MARK: - Compact

struct CompactIslandView: View {
    @Environment(QuotaViewModel.self) private var viewModel

    private var primaryQuota: QuotaInfo? {
        viewModel.quotas
            .filter { $0.isHealthy }
            .sorted { $0.usageRatio > $1.usageRatio }
            .first
    }

    var body: some View {
        HStack(spacing: 10) {
            if let quota = primaryQuota {
                CompactProgressBar(ratio: quota.usageRatio)
                    .frame(width: 80)

                Text("\(quota.provider.displayName) \(quota.remainingPercent)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)

                Text(quota.formattedRemaining)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("加载中…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                Text("点击添加 API Key")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if viewModel.settings.petEnabled {
                PetView()
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundView)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch viewModel.settings.theme {
        case .glass:
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        case .pixel:
            Color(white: 0.12)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color(white: 0.3), lineWidth: 2)
                )
        }
    }
}

// MARK: - Compact Progress Bar

struct CompactProgressBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(barColor)
                    .frame(width: geo.size.width * min(ratio, 1.0))
            }
        }
        .frame(height: 6)
    }

    private var barColor: Color {
        if ratio >= 0.95 { return .red }
        if ratio >= 0.8 { return .orange }
        if ratio >= 0.5 { return .yellow }
        return .green
    }
}

// MARK: - VisualEffectView (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Pet Placeholder

struct PetView: View {
    var body: some View {
        Image(systemName: "cat.fill")
            .font(.system(size: 14))
            .foregroundStyle(.orange)
    }
}
