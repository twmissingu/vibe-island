import WidgetKit
import SwiftUI
import LLMQuotaKit

struct QuotaEntry: TimelineEntry {
    let date: Date
    let quotas: [QuotaInfo]

    static let placeholder = QuotaEntry(
        date: .now,
        quotas: [.placeholder(for: .mimo), .placeholder(for: .kimi)]
    )
}

struct QuotaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (QuotaEntry) -> Void) {
        let quotas = SharedDefaults.loadQuotas()
        completion(QuotaEntry(date: .now, quotas: quotas))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaEntry>) -> Void) {
        let quotas = SharedDefaults.loadQuotas()
        let entry = QuotaEntry(date: .now, quotas: quotas)
        let nextDate = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextDate)))
    }
}
