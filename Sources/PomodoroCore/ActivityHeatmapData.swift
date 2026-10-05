import Foundation

public struct ActivityWeek: Identifiable {
    public let id: Date
    public let days: [Date?]
    public let monthLabel: String?
}
public enum ActivityHeatmapData {
    /// Newest week is the leftmost column; each column runs Monday to Sunday.
    public static func columns(endingAt today: Date, weeks: Int = 26, calendar: Calendar = .current) -> [ActivityWeek] {
        var calendar = calendar; calendar.firstWeekday = 2; calendar.minimumDaysInFirstWeek = 4
        let end = calendar.startOfDay(for: today)
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: end)?.start else { return [] }
        var previousMonth: DateComponents?
        return (0..<max(0, weeks)).compactMap { index in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -index, to: currentWeek) else { return nil }
            let days: [Date?] = (0..<7).map { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: start), day <= end else { return nil }
                return day
            }
            let month = calendar.dateComponents([.year, .month], from: days.compactMap { $0 }.last ?? start)
            let label = month == previousMonth ? nil : "\(month.month ?? 1)월"
            previousMonth = month
            return ActivityWeek(id: start, days: days, monthLabel: label)
        }
    }
}
