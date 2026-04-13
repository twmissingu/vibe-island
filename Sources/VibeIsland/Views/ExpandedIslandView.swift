import SwiftUI
import LLMQuotaKit

struct ExpandedIslandView: View {
    @Environment(StateManager.self) private var viewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.quotas) { quota in
                QuotaCardView(quota: quota, theme: viewModel.settings.theme)
            }

            if viewModel.quotas.isEmpty {
                emptyState
            }

            footer
        }
        .padding(12)
        .frame(width: 360)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("请在设置中添加 API Key")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(height: 100)
    }

    private var footer: some View {
        HStack {
            if let last = viewModel.lastRefresh {
                Text("更新于 \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch viewModel.settings.theme {
        case .glass:
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        case .pixel:
            Color(white: 0.1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(white: 0.3), lineWidth: 2)
                )
        }
    }
}

// MARK: - QuotaCardView

struct QuotaCardView: View {
    let quota: QuotaInfo
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 8) {
            header
            CircularGaugeView(
                remainingPercent: quota.remainingPercent,
                theme: theme
            )
            .frame(width: 80, height: 80)
            detailRows
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(theme == .glass ? 0.05 : 0.03))
        )
    }

    private var header: some View {
        HStack {
            Text(quota.provider.displayName)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let error = quota.error {
                Text(error.displayMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            } else {
                Text("✅")
                    .font(.system(size: 11))
            }
        }
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            detailRow("剩余", value: "\(quota.formattedRemaining) / \(quota.formattedTotal)")
            detailRow("已用", value: "\(quota.formattedUsed) (\(quota.usedPercent)%)")
            if let reset = quota.nextResetAt {
                detailRow("重置", value: reset.formatted(date: .abbreviated, time: .shortened))
            }
            detailRow("Key", value: quota.keyIdentifier)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
