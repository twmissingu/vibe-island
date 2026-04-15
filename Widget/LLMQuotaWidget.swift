import WidgetKit
import SwiftUI
import AppIntents
import LLMQuotaKit

@main
struct LLMQuotaWidgets: WidgetBundle {
    var body: some Widget {
        QuotaSmallWidget()
        QuotaMediumWidget()
    }
}

struct QuotaSmallWidget: Widget {
    let kind = "QuotaSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuotaTimelineProvider()) { entry in
            WidgetSmallView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quota Island")
        .description("查看大模型 API 额度")
        .supportedFamilies([.systemSmall])
    }
}

struct QuotaMediumWidget: Widget {
    let kind = "QuotaMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuotaTimelineProvider()) { entry in
            WidgetMediumView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quota Island")
        .description("查看大模型 API 额度")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - ProviderIntent

struct ProviderIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "选择平台" }
    static var description: IntentDescription { IntentDescription("选择要显示的平台") }

    @Parameter(title: "平台")
    var provider: ProviderTypeAppEnum?
}

enum ProviderTypeAppEnum: String, AppEnum {
    case mimo, kimi, minimax, zai, ark, all

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "平台" }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .mimo: "小米 MIMO",
            .kimi: "Kimi",
            .minimax: "MiniMax",
            .zai: "智谱",
            .ark: "火山方舟",
            .all: "全部"
        ]
    }
}
