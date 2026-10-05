import SwiftUI
import PomodoroCore
struct DaySection: View {
    let group: DayGroup
    @Binding var expanded: Bool
    let editMemo: (UUID) -> Void
    var body: some View {
        VStack(spacing: 14) {
            Button { expanded.toggle() } label: {
                Card {
                    HStack {
                        Text(TimeFormatting.date(group.date, pattern: "M월 d일")).fontWeight(.semibold)
                        Spacer(); Text("\(group.records.count)"); Text("|").foregroundStyle(Theme.border)
                        Text(TimeFormatting.total(group.totalSeconds)).monospacedDigit()
                        Image(systemName: expanded ? "minus" : "chevron.down").padding(.leading, 8)
                    }.font(.system(size: 16)).foregroundStyle(Theme.secondary)
                }
            }.buttonStyle(.plain).accessibilityLabel("\(TimeFormatting.date(group.date, pattern: "M월 d일")), \(expanded ? "접기" : "펼치기")")
            if expanded {
                VStack(spacing: 12) { ForEach(group.records) { record in
                    Button { editMemo(record.id) } label: {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) {
                                Text(TimeFormatting.date(record.startedAt, pattern: "HH:mm")).font(.system(size: 14, weight: .medium)).monospacedDigit().frame(width: 52)
                                recordCard(record).frame(minWidth: 350)
                            }.padding(.leading, 20)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(TimeFormatting.date(record.startedAt, pattern: "HH:mm")).font(.caption).padding(.leading, 12)
                                recordCard(record)
                            }.padding(.leading, 14)
                        }
                    }.buttonStyle(.plain)
                } }.padding(.leading, 12).overlay(alignment: .leading) { Rectangle().fill(Theme.border).frame(width: 1).padding(.leading, 5) }
            }
        }
    }
    private func recordCard(_ record: FocusRecord) -> some View {
        Card(padding: 18) {
            HStack(spacing: 16) {
                Text(TimeFormatting.recordMinutes(record.focusedSeconds)).font(.system(size: record.focusedSeconds < 60 ? 13 : 24, weight: .semibold)).monospacedDigit().frame(minWidth: 32)
                Rectangle().fill(Theme.border).frame(width: 1, height: 24)
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.memo.isEmpty ? "메모 없음" : record.memo).font(.system(size: 14)).lineLimit(3).multilineTextAlignment(.leading)
                    if !record.completed { Text("중단").font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 3).background(Theme.hover, in: Capsule()) }
                }
                Spacer(minLength: 0)
            }.foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
