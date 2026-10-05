import XCTest
@testable import PomodoroCore
final class StatisticsTests: XCTestCase {
    let id = UUID()
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func stats(_ zone: String = "Asia/Seoul") -> Statistics {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!; return Statistics(calendar: c)
    }
    func testTotalsAndHalfOpenBoundary() {
        let start = date("2026-10-05T00:00:00Z"), end = date("2026-10-06T00:00:00Z")
        let records = [1500.0, 540, 300].enumerated().map { FocusRecord(taskID: id, startedAt: start + Double($0.offset), endedAt: start + 2000, focusedSeconds: $0.element) }
        let excluded = FocusRecord(taskID: id, startedAt: end, endedAt: end + 60, focusedSeconds: 60)
        let other = FocusRecord(taskID: UUID(), startedAt: start, endedAt: start + 60, focusedSeconds: 60)
        let summary = stats().summary(records: records + [excluded, other], taskID: id, interval: DateInterval(start: start, end: end))
        XCTAssertEqual(summary.count, 3); XCTAssertEqual(summary.totalSeconds, 2340); XCTAssertEqual(summary.averageSeconds, 780)
        XCTAssertEqual(stats().summary(records: [], taskID: nil, interval: DateInterval(start: start, end: end)).averageSeconds, 0)
    }
    func testWeekMonthAndDST() {
        XCTAssertEqual(stats().interval(for: .week, containing: date("2026-10-07T00:00:00Z")).start, date("2026-10-04T15:00:00Z"))
        let leap = stats().interval(for: .month, containing: date("2024-02-20T00:00:00Z"))
        XCTAssertEqual(leap.end, date("2024-02-29T15:00:00Z"))
        let dst = stats("America/Los_Angeles").interval(for: .day, containing: date("2026-03-08T12:00:00Z"))
        XCTAssertEqual(dst.duration, 23 * 3600)
    }
    func testCrossMidnightBelongsToStart() {
        let start = date("2026-10-05T14:55:00Z")
        let r = FocusRecord(taskID: id, startedAt: start, endedAt: start + 1500, focusedSeconds: 1500)
        let groups = stats().days(records: [r], taskID: id, interval: stats().interval(for: .day, containing: start))
        XCTAssertEqual(groups.count, 1); XCTAssertEqual(groups.first?.totalSeconds, 1500)
        XCTAssertEqual(groups.first?.date, date("2026-10-04T15:00:00Z"))
    }
}
