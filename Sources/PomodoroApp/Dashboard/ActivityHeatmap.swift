import SwiftUI
import PomodoroCore
struct ActivityHeatmap: View {
    let records: [FocusRecord]
    let today: Date
    private let calendar = Calendar.current
    var body: some View {
        let columns = ActivityHeatmapData.columns(endingAt: today, calendar: calendar)
        let totals = Dictionary(grouping: records) { calendar.startOfDay(for: $0.startedAt) }.mapValues { $0.reduce(0) { $0 + $1.focusedSeconds } }
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("집중의 흔적").font(.system(size: 12, weight: .medium)); Spacer(); Text("← 최근 · 26주").font(.system(size: 10)).foregroundStyle(Theme.muted) }
            HStack(spacing: 3) {
                ForEach(columns) { column in
                    Text(column.monthLabel ?? "").font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.muted)
                        .fixedSize().frame(maxWidth: .infinity, alignment: .leading)
                }
            }.frame(height: 12)
            GeometryReader { proxy in
                let size = max(4, (proxy.size.width - 25 * 3) / 26)
                HStack(alignment: .top, spacing: 3) {
                    ForEach(columns) { column in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { index in
                                if let date = column.days[index] {
                                    let seconds = totals[date] ?? 0
                                    RoundedRectangle(cornerRadius: 2).fill(seconds > 0 ? Theme.focus.opacity(min(1, 0.25 + seconds / 7200)) : Theme.background)
                                        .frame(width: size, height: size)
                                        .help("\(TimeFormatting.date(date, pattern: "yyyy년 M월 d일")) · \(TimeFormatting.duration(seconds))")
                                        .accessibilityLabel("\(TimeFormatting.date(date, pattern: "yyyy년 M월 d일")) \(TimeFormatting.duration(seconds))")
                                } else {
                                    Color.clear.frame(width: size, height: size).accessibilityHidden(true)
                                }
                            }
                        }
                    }
                }
            }.aspectRatio(26.0 / 7.0, contentMode: .fit)
            HStack(spacing: 4) { Text("적음"); ForEach(0..<4) { i in RoundedRectangle(cornerRadius: 2).fill(i == 0 ? Theme.background : Theme.focus.opacity(Double(i) / 3)).frame(width: 9, height: 9) }; Text("많음") }.font(.system(size: 9)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
