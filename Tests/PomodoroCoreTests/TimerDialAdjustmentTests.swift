import XCTest
@testable import PomodoroCore

final class TimerDialAdjustmentTests: XCTestCase {
    func testClockwiseMinutePositions() {
        XCTAssertEqual(TimerDialAdjustment.minutes(x: 100, y: 0, previous: 15), 15)
        XCTAssertEqual(TimerDialAdjustment.minutes(x: 0, y: 100, previous: 30), 30)
        XCTAssertEqual(TimerDialAdjustment.minutes(x: -100, y: 0, previous: 45), 45)
    }
    func testTwelveOClockClampsAtBothEndsInsteadOfWrapping() {
        XCTAssertEqual(TimerDialAdjustment.minutes(x: 0, y: -100, previous: 59), 60)
        XCTAssertEqual(TimerDialAdjustment.minutes(x: 5, y: -100, previous: 60), 60)
        XCTAssertEqual(TimerDialAdjustment.minutes(x: 0, y: -100, previous: 1), 1)
        XCTAssertEqual(TimerDialAdjustment.minutes(x: -5, y: -100, previous: 1), 1)
    }
    func testCenterDoesNotJumpAndMinutesRoundToNearestTick() {
        XCTAssertEqual(TimerDialAdjustment.minutes(x: 0, y: 0, previous: 25), 25)
        let angle = 23.3 * Double.pi / 30
        XCTAssertEqual(TimerDialAdjustment.minutes(x: sin(angle) * 100, y: -cos(angle) * 100, previous: 23), 23)
    }
    @MainActor func testReadyAdjustmentPersistsPreferenceAndStartUsesIt() throws {
        let repo = MemoryRepository(); let store = AppStore(repository: repo)
        try store.load(); try store.adjustRemainingMinutes(35)
        XCTAssertEqual(store.snapshot.preferences.focusMinutes, 35)
        XCTAssertEqual(store.remainingSeconds, 2100)
        try store.start()
        XCTAssertEqual(store.snapshot.timer.durationSeconds, 2100)
        XCTAssertThrowsError(try store.adjustRemainingMinutes(10))
    }
    @MainActor func testPausedAdjustmentPreservesElapsedAndRecordsItOnStop() throws {
        var now = Date(timeIntervalSince1970: 1800000000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now })
        try store.load(); try store.start(); now += 120; try store.pause()
        let id = store.snapshot.timer.sessionID
        try store.adjustRemainingMinutes(10)
        XCTAssertEqual(store.remainingSeconds, 600)
        XCTAssertEqual(store.snapshot.timer.durationSeconds, 720)
        XCTAssertEqual(store.snapshot.timer.sessionID, id)
        XCTAssertEqual(store.snapshot.preferences.focusMinutes, 25)
        XCTAssertThrowsError(try store.adjustRemainingMinutes(59))
        XCTAssertThrowsError(try store.adjustRemainingMinutes(0))
        try store.resume(); now += 60; try store.stop()
        XCTAssertEqual(store.snapshot.records.first?.focusedSeconds, 180)
    }
}
