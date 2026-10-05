import XCTest
@testable import PomodoroCore
final class TimeFormattingTests: XCTestCase {
    func testDialAndFormatting() {
        XCTAssertEqual(TimeFormatting.dialDegrees(1500), 150)
        XCTAssertEqual(TimeFormatting.dialDegrees(300), 30)
        XCTAssertEqual(TimeFormatting.dialDegrees(3600), 360)
        XCTAssertEqual(TimeFormatting.dialDegrees(0), 0)
        XCTAssertEqual(TimeFormatting.recordMinutes(59), "1분 미만")
        XCTAssertEqual(TimeFormatting.countdown(1500), "25:00")
        XCTAssertEqual(TimeFormatting.countdown(0.1), "00:01")
        XCTAssertEqual(TimeFormatting.total(8340), "02:19")
    }
}
