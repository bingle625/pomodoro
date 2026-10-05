import XCTest
@testable import PomodoroCore
final class ActivityHeatmapTests: XCTestCase {
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func calendar(_ zone: String = "Asia/Seoul") -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!; return c
    }
    func testNewestWeekAndMonthOnLeftWithFutureDaysBlank() {
        let columns = ActivityHeatmapData.columns(endingAt: date("2026-10-05T03:00:00Z"), calendar: calendar())
        XCTAssertEqual(columns.count, 26)
        XCTAssertEqual(columns[0].days[0], date("2026-10-04T15:00:00Z"))
        XCTAssertNil(columns[0].days[1])
        XCTAssertEqual(columns[1].days[0], date("2026-09-27T15:00:00Z"))
        XCTAssertEqual(columns[0].monthLabel, "10월")
        XCTAssertNil(columns[1].monthLabel)
        XCTAssertEqual(columns[2].monthLabel, "9월")
        XCTAssertTrue(columns[0].id > columns[25].id)
    }
    func testMonthLabelsAcrossYearAndCalendarDaysAcrossDST() {
        let year = ActivityHeatmapData.columns(endingAt: date("2026-01-01T03:00:00Z"), calendar: calendar())
        XCTAssertEqual(year[0].monthLabel, "1월")
        XCTAssertEqual(year[1].monthLabel, "12월")
        let c = calendar("America/Los_Angeles")
        let dst = ActivityHeatmapData.columns(endingAt: date("2026-03-09T12:00:00Z"), calendar: c)
        XCTAssertEqual(dst[0].days[0], date("2026-03-09T07:00:00Z"))
        XCTAssertEqual(dst[1].days[6], date("2026-03-08T08:00:00Z"))
    }
}
