import SwiftUI
import LLMQuotaKit

struct WidgetSmallView: View {
    let entry: QuotaEntry

    var body: some View {
        if let quota = entry.quotas.first {
            VStack(spacing: 6) {
                Text(quota.provider.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                WidgetGaugeView(percent: quota.remainingPercent)
                    .frame(width: 60, height: 60)

                Text(quota.formattedRemaining)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(gaugeColor(for: quota.remainingPercent))
            }
            .padding(8)
        } else {
            VStack {
                Image(systemName: "key.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                Text("未配置")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func gaugeColor(for percent: Int) -> Color {
        if percent < 20 { return .red }
        if percent < 50 { return .orange }
        return .green
    }
}

struct WidgetGaugeView: View {
    let percent: Int

    private var fill: Double { Double(percent) / 100.0 }

    private var color: Color {
        if percent < 20 { return .red }
        if percent < 50 { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(.fill.quaternary, style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75 * fill)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                .rotationEffect(.degrees(135))

            Text("\(percent)%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

struct WidgetMediumView: View {
    let entry: QuotaEntry

    var body: some View {
        HStack(spacing: 12) {
            ForEach(entry.quotas.prefix(2)) { quota in
                VStack(spacing: 4) {
                    Text(quota.provider.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    WidgetGaugeView(percent: quota.remainingPercent)
                        .frame(width: 50, height: 50)

                    Text(quota.formattedRemaining)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
    }
}
