import SwiftUI
import LLMQuotaKit

struct CircularGaugeView: View {
    let remainingPercent: Int
    let theme: AppTheme

    private var fill: Double { Double(remainingPercent) / 100.0 }

    private var statusColor: Color {
        switch remainingPercent {
        case ..<20: .red
        case ..<50: .orange
        default: .green
        }
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(.fill.quaternary, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                .rotationEffect(.degrees(135))

            // Fill
            Circle()
                .trim(from: 0, to: 0.75 * fill)
                .stroke(statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                .rotationEffect(.degrees(135))
                .animation(.easeInOut(duration: 0.5), value: fill)

            // Center text
            VStack(spacing: 0) {
                Text("\(remainingPercent)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                Text("%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
