import XCTest
@testable import PomodoroCore
final class TimerEngineTests: XCTestCase {
    let t = Date(timeIntervalSince1970: 1_800_000_000)
    let task = UUID()
    func engine(_ p: Preferences = Preferences()) -> TimerEngine {
        var e = TimerEngine(state: TimerState())
        e.start(taskID: task, preferences: p, at: t)
        return e
    }
    func testDefaultCycle() {
        var e = engine()
        XCTAssertEqual(e.remaining(at: t), 1500)
        XCTAssertNotNil(e.advance(at: t.addingTimeInterval(1500), preferences: Preferences()))
        XCTAssertEqual(e.state.phase, .rest)
        XCTAssertEqual(e.state.status, .ready)
        XCTAssertNil(e.advance(at: t.addingTimeInterval(1501), preferences: Preferences()))
    }
    func testPauseExcludesTime() {
        var e = engine()
        e.pause(at: t.addingTimeInterval(60))
        e.resume(at: t.addingTimeInterval(360))
        XCTAssertEqual(e.remaining(at: t.addingTimeInterval(420)), 1380)
    }
    func testLateWakeStartsOneRestNow() {
        var p = Preferences(); p.autoStart = true
        var e = engine(p)
        let event = e.advance(at: t.addingTimeInterval(7200), preferences: p)
        XCTAssertEqual(event?.focusedSeconds, 1500)
        XCTAssertEqual(event?.endedAt, t.addingTimeInterval(1500))
        XCTAssertEqual(e.state.deadline, t.addingTimeInterval(7500))
        XCTAssertNil(e.advance(at: t.addingTimeInterval(7200), preferences: p))
    }
    func testPartialStopAndZeroStop() {
        var e = engine()
        let event = e.stop(at: t.addingTimeInterval(9), preferences: Preferences())
        XCTAssertEqual(event?.focusedSeconds, 9)
        XCTAssertEqual(event?.completed, false)
        XCTAssertEqual(e.state.phase, .focus)
        e = engine()
        XCTAssertNil(e.stop(at: t, preferences: Preferences()))
        XCTAssertEqual(e.state.status, .ready)
    }
    func testRestCompletion() {
        var e = engine()
        _ = e.advance(at: t.addingTimeInterval(1500), preferences: Preferences())
        e.start(taskID: task, preferences: Preferences(), at: t.addingTimeInterval(1500))
        let event = e.advance(at: t.addingTimeInterval(1800), preferences: Preferences())
        XCTAssertEqual(event?.phase, .rest)
        XCTAssertEqual(e.state.phase, .focus)
    }
    func testStateRoundTripPreservesRunningAndPaused() throws {
        var e = engine()
        var restored = TimerEngine(state: try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(e.state)))
        XCTAssertEqual(restored.remaining(at: t.addingTimeInterval(100)), 1400)
        e.pause(at: t.addingTimeInterval(60))
        restored = TimerEngine(state: try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(e.state)))
        XCTAssertEqual(restored.remaining(at: t.addingTimeInterval(9999)), 1440)
    }
}
