import Foundation
public enum Period: String, CaseIterable, Identifiable {
    case day, week, month
    public var id: String { rawValue }
    public var label: String { switch self { case .day: return "일간"; case .week: return "주간"; case .month: return "월간" } }
}
public struct FocusSummary {
    public let count: Int
    public let totalSeconds: TimeInterval
    public var averageSeconds: TimeInterval { count == 0 ? 0 : totalSeconds / Double(count) }
}
public struct DayGroup: Identifiable {
    public var id: Date { date }
    public let date: Date
    public let records: [FocusRecord]
    public var totalSeconds: TimeInterval { records.reduce(0) { $0 + $1.focusedSeconds } }
}
public struct Statistics {
    public var calendar: Calendar
    public init(calendar: Calendar = .current) { var c = calendar; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4; self.calendar = c }
    public func interval(for period: Period, containing date: Date) -> DateInterval {
        let component: Calendar.Component = period == .day ? .day : period == .week ? .weekOfYear : .month
        return calendar.dateInterval(of: component, for: date)!
    }
    public func shifted(_ date: Date, period: Period, by count: Int) -> Date {
        calendar.date(byAdding: period == .day ? .day : period == .week ? .weekOfYear : .month, value: count, to: date)!
    }
    public func filtered(records: [FocusRecord], taskID: UUID?, interval: DateInterval) -> [FocusRecord] {
        records.filter { (taskID == nil || $0.taskID == taskID) && $0.startedAt >= interval.start && $0.startedAt < interval.end }
    }
    public func summary(records: [FocusRecord], taskID: UUID?, interval: DateInterval) -> FocusSummary {
        let values = filtered(records: records, taskID: taskID, interval: interval)
        return FocusSummary(count: values.count, totalSeconds: values.reduce(0) { $0 + $1.focusedSeconds })
    }
    public func days(records: [FocusRecord], taskID: UUID?, interval: DateInterval) -> [DayGroup] {
        Dictionary(grouping: filtered(records: records, taskID: taskID, interval: interval)) { calendar.startOfDay(for: $0.startedAt) }
            .map { DayGroup(date: $0.key, records: $0.value.sorted { $0.startedAt > $1.startedAt }) }.sorted { $0.date > $1.date }
    }
    public func taskTotals(records: [FocusRecord], interval: DateInterval) -> [UUID: TimeInterval] {
        Dictionary(grouping: filtered(records: records, taskID: nil, interval: interval), by: \.taskID).mapValues { $0.reduce(0) { $0 + $1.focusedSeconds } }
    }
}
