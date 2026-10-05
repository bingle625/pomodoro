import SwiftUI
import PomodoroCore
struct SummaryView: View {
    let store: AppStore
    @State private var period: Period = .week
    private let stats = Statistics()
    private var interval: DateInterval { stats.interval(for: period, containing: store.currentDate) }
    private var summary: FocusSummary { stats.summary(records: store.snapshot.records, taskID: store.snapshot.selectedTaskID, interval: interval) }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) { metrics; distribution }.frame(width: 310)
                VStack(spacing: 16) { heatmap; bars; recent }.frame(minWidth: 420)
            }
            VStack(spacing: 16) { metrics; heatmap; bars; distribution; recent }
        }
    }
    private var metrics: some View {
        Card {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) { ForEach(Period.allCases) { p in
                    Button { period = p } label: { Text(p == .day ? "오늘" : p == .week ? "이번 주" : "이번 달").font(.system(size: 12, weight: period == p ? .semibold : .regular)).foregroundStyle(period == p ? Theme.text : Theme.muted) }.buttonStyle(.plain)
                } }
                VStack(spacing: 9) {
                    Text(TimeFormatting.duration(summary.totalSeconds)).font(.system(size: 36, weight: .bold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                    let previous = stats.interval(for: period, containing: stats.shifted(store.currentDate, period: period, by: -1))
                    let delta = summary.totalSeconds - stats.summary(records: store.snapshot.records, taskID: store.snapshot.selectedTaskID, interval: previous).totalSeconds
                    HStack(spacing: 5) {
                        Text("지난 \(period == .day ? "하루" : period == .week ? "주" : "달") 대비").foregroundStyle(Theme.muted)
                        Text("\(delta >= 0 ? "+" : "−")\(TimeFormatting.duration(abs(delta)))").foregroundStyle(Theme.focus)
                    }.font(.system(size: 11, weight: .medium))
                }.frame(maxWidth: .infinity).padding(.vertical, 36)
                Divider()
                HStack {
                    metric("집중 횟수", "\(summary.count)회")
                    Rectangle().fill(Theme.border).frame(width: 1, height: 30)
                    metric("평균 집중 시간", TimeFormatting.duration(summary.averageSeconds))
                }
                Divider()
                HStack { Text("전체 누적").foregroundStyle(Theme.muted); Spacer(); Text(TimeFormatting.duration(store.snapshot.records.filter { $0.taskID == store.snapshot.selectedTaskID }.reduce(0) { $0 + $1.focusedSeconds })).fontWeight(.semibold) }.font(.system(size: 12))
            }
        }
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 7) { Text(label).font(.system(size: 11)).foregroundStyle(Theme.muted); Text(value).font(.system(size: 16, weight: .semibold)).monospacedDigit() }.frame(maxWidth: .infinity)
    }
    private var heatmap: some View {
        Card(padding: 18) { ActivityHeatmap(records: store.snapshot.records.filter { $0.taskID == store.snapshot.selectedTaskID }, today: store.currentDate) }
    }
    private var bars: some View {
        Card(padding: 18) { FocusBars(records: store.snapshot.records.filter { $0.taskID == store.snapshot.selectedTaskID }, today: store.currentDate) }
    }
    private var distribution: some View {
        Card { FocusDistribution(tasks: store.snapshot.tasks, totals: stats.taskTotals(records: store.snapshot.records, interval: interval), title: period == .day ? "오늘" : period == .week ? "이번 주" : "이번 달") }
    }
    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("최근 집중").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted).padding(.leading, 4)
            let records = store.snapshot.records.filter { $0.taskID == store.snapshot.selectedTaskID }.sorted { $0.startedAt > $1.startedAt }.prefix(5)
            if records.isEmpty { Card { EmptyState() } }
            ForEach(Array(records)) { r in
                Card(padding: 16) {
                    HStack(spacing: 14) {
                        Text(TimeFormatting.recordMinutes(r.focusedSeconds)).font(.system(size: 20, weight: .semibold)).monospacedDigit()
                        Rectangle().fill(Theme.border).frame(width: 1, height: 20)
                        Text(r.memo.isEmpty ? "메모 없음" : r.memo).font(.system(size: 12)).foregroundStyle(Theme.secondary).lineLimit(2)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
