import SwiftUI
import PomodoroCore
struct ReviewView: View {
    let store: AppStore
    let editMemo: (UUID) -> Void
    @State private var period: Period = .week
    @State private var date = Date()
    @State private var collapsed: Set<Date> = []
    private let stats = Statistics()
    var body: some View {
        let interval = stats.interval(for: period, containing: date)
        let groups = stats.days(records: store.snapshot.records, taskID: store.snapshot.selectedTaskID, interval: interval)
        let summary = stats.summary(records: store.snapshot.records, taskID: store.snapshot.selectedTaskID, interval: interval)
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Picker("기간", selection: $period) { ForEach(Period.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented).frame(width: 180)
                Spacer()
                Text("\(summary.count)").fontWeight(.semibold)
                Text("|").foregroundStyle(Theme.border)
                Text(TimeFormatting.total(summary.totalSeconds)).fontWeight(.semibold).monospacedDigit().accessibilityLabel("총 집중 시간 \(TimeFormatting.duration(summary.totalSeconds))")
            }
            HStack(spacing: 4) {
                IconButton(symbol: "chevron.left", label: "이전 기간") { date = stats.shifted(date, period: period, by: -1) }
                Text(periodTitle(interval)).font(.system(size: 13, weight: .medium)).frame(minWidth: 130)
                IconButton(symbol: "chevron.right", label: "다음 기간") { date = stats.shifted(date, period: period, by: 1) }
                Spacer(); Button("오늘") { date = store.currentDate }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
            if groups.isEmpty { Card { EmptyState(title: store.snapshot.records.isEmpty ? "아직 집중 기록이 없어요" : "이 기간에는 집중 기록이 없어요") } }
            ForEach(groups) { group in
                DaySection(group: group, expanded: Binding(get: { !collapsed.contains(group.date) }, set: { if $0 { collapsed.remove(group.date) } else { collapsed.insert(group.date) } }), editMemo: editMemo)
            }
        }.onChange(of: period) { _, _ in collapsed = [] }
    }
    private func periodTitle(_ range: DateInterval) -> String {
        if period == .month { return TimeFormatting.date(date, pattern: "yyyy년 M월") }
        if period == .day { return TimeFormatting.date(date, pattern: "M월 d일") }
        return "\(TimeFormatting.date(range.start, pattern: "M월 d일")) – \(TimeFormatting.date(range.end.addingTimeInterval(-1), pattern: "M월 d일"))"
    }
}
