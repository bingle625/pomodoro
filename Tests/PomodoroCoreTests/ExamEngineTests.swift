import XCTest
@testable import PomodoroCore

final class ExamEngineTests: XCTestCase {
    let t = Date(timeIntervalSince1970: 1_800_000_000)
    let sections = [ExamSection(name: "언어이해", minutes: 20), ExamSection(name: "논리판단", minutes: 10), ExamSection(name: "자료해석", minutes: 20)]

    private func started() -> ExamEngine {
        var e = ExamEngine(state: ExamTimerState())
        e.start(sections: sections, presetName: "HMAT", at: t)
        return e
    }

    func testStartLoadsFirstSection() {
        let e = started()
        XCTAssertEqual(e.state.status, .running)
        XCTAssertEqual(e.currentSection?.name, "언어이해")
        XCTAssertEqual(e.remaining(at: t), 1200)
        XCTAssertEqual(e.state.currentIndex, 0)
    }

    func testAutoAdvanceRingsEachBoundaryAndFinishes() {
        var e = started()
        let first = e.advance(at: t.addingTimeInterval(1200))
        XCTAssertEqual(first?.isLast, false)
        XCTAssertEqual(e.currentSection?.name, "논리판단")
        XCTAssertEqual(e.remaining(at: t.addingTimeInterval(1200)), 600)
        let second = e.advance(at: t.addingTimeInterval(1800))
        XCTAssertEqual(second?.finishedIndex, 1)
        XCTAssertEqual(e.currentSection?.name, "자료해석")
        let last = e.advance(at: t.addingTimeInterval(3000))
        XCTAssertEqual(last?.isLast, true)
        XCTAssertEqual(e.state.status, .ready)
        XCTAssertTrue(e.state.sections.isEmpty)
    }

    func testAdvanceChainsFromDeadlineNotWallClock() {
        // A late tick still starts the next section's clock from the elapsed deadline.
        var e = started()
        _ = e.advance(at: t.addingTimeInterval(1300))
        XCTAssertEqual(e.state.deadline, t.addingTimeInterval(1200 + 600))
    }

    func testPauseExcludesTimeAcrossSections() {
        var e = started()
        e.pause(at: t.addingTimeInterval(60))
        e.resume(at: t.addingTimeInterval(360))
        XCTAssertEqual(e.remaining(at: t.addingTimeInterval(420)), 1080)
        XCTAssertNil(e.advance(at: t.addingTimeInterval(420)))
    }

    func testStopResetsToReady() {
        var e = started()
        e.stop()
        XCTAssertEqual(e.state.status, .ready)
        XCTAssertTrue(e.state.sections.isEmpty)
    }

    func testStateRoundTripPreservesRunning() throws {
        let e = started()
        let restored = ExamEngine(state: try JSONDecoder().decode(ExamTimerState.self, from: JSONEncoder().encode(e.state)))
        XCTAssertEqual(restored.remaining(at: t.addingTimeInterval(200)), 1000)
        XCTAssertEqual(restored.currentSection?.name, "언어이해")
    }

    func testStartIgnoredWhenAlreadyRunningOrEmpty() {
        var e = started()
        e.start(sections: [ExamSection(name: "X", minutes: 5)], presetName: "other", at: t)
        XCTAssertEqual(e.currentSection?.name, "언어이해")
        var empty = ExamEngine(state: ExamTimerState())
        empty.start(sections: [], presetName: "none", at: t)
        XCTAssertEqual(empty.state.status, .ready)
    }
}
