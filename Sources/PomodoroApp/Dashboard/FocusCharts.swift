import SwiftUI
import Charts
import PomodoroCore
struct FocusBars: View {
    let records: [FocusRecord]
    let today: Date
    var body: some View {
        let c = Calendar.current
        let totals = Dictionary(grouping: records) { c.startOfDay(for: $0.startedAt) }.mapValues { $0.reduce(0) { $0 + $1.focusedSeconds } }
        let days = (0..<30).map { c.date(byAdding: .day, value: $0 - 29, to: c.startOfDay(for: today))! }
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("하루의 집중").font(.system(size: 12, weight: .medium)); Spacer(); Text("최근 30일 · 분").font(.system(size: 10)).foregroundStyle(Theme.muted) }
            Chart(days, id: \.self) { date in BarMark(x: .value("날짜", date, unit: .day), y: .value("집중 시간", (totals[date] ?? 0) / 60)).foregroundStyle(Theme.focus).cornerRadius(2) }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.month().day()) } }
                .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) }
                .frame(height: 120)
                .accessibilityLabel("최근 30일 집중 시간 막대그래프")
        }
    }
}
struct FocusDistribution: View {
    let tasks: [FocusTask]
    let totals: [UUID: TimeInterval]
    let title: String
    var body: some View {
        let active = tasks.filter { (totals[$0.id] ?? 0) > 0 }
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(title).font(.system(size: 13, weight: .semibold)); Spacer(); Text("전체 작업").font(.system(size: 11)).foregroundStyle(Theme.muted) }
            Text(TimeFormatting.total(totals.values.reduce(0, +))).font(.system(size: 27, weight: .semibold)).monospacedDigit().accessibilityLabel("총 집중 시간 \(TimeFormatting.duration(totals.values.reduce(0, +)))")
            if active.isEmpty {
                Circle().stroke(Theme.background, lineWidth: 24).frame(width: 145, height: 145).overlay(Text("첫 집중을 기다려요").font(.system(size: 11)).foregroundStyle(Theme.muted)).frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                Chart(active) { task in SectorMark(angle: .value("집중", totals[task.id] ?? 0), innerRadius: .ratio(0.7), angularInset: active.count > 1 ? 2 : 0).foregroundStyle(Color(hex: task.colorHex)) }.frame(height: 175)
                ForEach(active) { task in HStack { Circle().fill(Color(hex: task.colorHex)).frame(width: 6, height: 6); Text(task.name).lineLimit(1); Spacer(); Text(TimeFormatting.duration(totals[task.id] ?? 0)).monospacedDigit() }.font(.system(size: 11)).foregroundStyle(Theme.secondary) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
