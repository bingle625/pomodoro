import XCTest
@testable import PomodoroCore

final class LongBreakTests: XCTestCase {
    private func preferences(interval: Int = 2, minutes: Int = 12) throws -> Preferences {
        let json = """
        {"focusMinutes":1,"breakMinutes":1,"longBreakMinutes":\(minutes),"longBreakInterval":\(interval),"soundEnabled":true,"autoStart":true}
        """
        return try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
    }

    func testCustomCycleSurvivesRestorationAndRepeats() throws {
        let p = try preferences()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        var engine = TimerEngine(state: TimerState())
        engine.start(taskID: UUID(), preferences: p, at: now)
        for expected in ["rest", "focus", "longRest", "focus", "rest", "focus", "longRest"] {
            now += engine.state.durationSeconds
            XCTAssertNotNil(engine.advance(at: now, preferences: p))
            XCTAssertEqual(engine.state.phase.rawValue, expected)
            if expected == "longRest" { XCTAssertEqual(engine.state.durationSeconds, 720) }
            engine = TimerEngine(state: try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(engine.state)))
        }
    }

    func testInterruptedFocusAndPreferenceRefreshPreserveCycle() throws {
        var p = try preferences(); p.autoStart = false
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let task = UUID()
        var engine = TimerEngine(state: TimerState())
        engine.start(taskID: task, preferences: p, at: now)
        now += 60; _ = engine.advance(at: now, preferences: p)
        engine.start(taskID: task, preferences: p, at: now)
        now += 60; _ = engine.advance(at: now, preferences: p)
        engine.start(taskID: task, preferences: p, at: now)
        now += 10; _ = engine.stop(at: now, preferences: p)
        XCTAssertEqual(engine.state.completedFocusCount, 1)
        engine.refreshReady(preferences: p)
        engine.start(taskID: task, preferences: p, at: now)
        now += 60; _ = engine.advance(at: now, preferences: p)
        XCTAssertEqual(engine.state.phase.rawValue, "longRest")
        XCTAssertEqual(engine.state.status, .ready)
    }

    func testLegacySnapshotDefaultsToLongBreakAfterFourFocusSessions() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSnapshot())) as? [String: Any])
        var prefs = try XCTUnwrap(json["preferences"] as? [String: Any])
        prefs.removeValue(forKey: "longBreakMinutes"); prefs.removeValue(forKey: "longBreakInterval")
        var timer = try XCTUnwrap(json["timer"] as? [String: Any])
        timer.removeValue(forKey: "completedFocusCount")
        json["preferences"] = prefs; json["timer"] = timer
        let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        var p = snapshot.preferences; p.autoStart = true
        var engine = TimerEngine(state: snapshot.timer)
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        engine.start(taskID: snapshot.selectedTaskID, preferences: p, at: now)
        for _ in 0..<7 { now += engine.state.durationSeconds; _ = engine.advance(at: now, preferences: p) }
        XCTAssertEqual(engine.state.phase.rawValue, "longRest")
        XCTAssertEqual(engine.state.durationSeconds, 900)
    }

    @MainActor func testLongBreakDialAdjustsOnlyLongBreakPreference() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository()
        let store = AppStore(repository: repo, now: { now }); try store.load()
        var p = try preferences(interval: 1); p.autoStart = false
        try store.updatePreferences(p); try store.start(); now += 60; try store.tick()
        XCTAssertEqual(store.snapshot.timer.phase.rawValue, "longRest")
        try store.adjustRemainingMinutes(20)
        XCTAssertEqual(store.snapshot.preferences.breakMinutes, 1)
        XCTAssertEqual(store.snapshot.timer.remainingSeconds, 1200)
        let restored = AppStore(repository: repo, now: { now }); try restored.load()
        XCTAssertEqual(restored.snapshot.timer, store.snapshot.timer)
    }

    @MainActor func testFailedCompletionSaveDoesNotCountTwice() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository()
        let store = AppStore(repository: repo, now: { now }); try store.load()
        try store.updatePreferences(preferences())
        try store.start(); now += 60
        repo.failSave = true
        XCTAssertThrowsError(try store.tick())
        repo.failSave = false; try store.retrySave(); try store.tick()
        XCTAssertEqual(store.snapshot.timer.completedFocusCount, 1)
        now += 60; try store.tick(); now += 60; try store.tick()
        XCTAssertEqual(store.snapshot.timer.phase, .longRest)
        XCTAssertEqual(store.snapshot.timer.completedFocusCount, 0)
        XCTAssertEqual(store.snapshot.records.count, 2)
    }

    @MainActor func testReducedIntervalAppliesAtNextFocusCompletionAndPersistsToDisk() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = LocalRepository(fileURL: url)
        var snapshot = AppSnapshot(); snapshot.timer.completedFocusCount = 3
        try repo.save(snapshot)
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = AppStore(repository: repo, now: { now }); try store.load()
        try store.updatePreferences(preferences(interval: 2)); try store.start()
        now += 60; try store.tick()
        XCTAssertEqual(store.snapshot.timer.phase, .longRest)
        try store.pause()
        let restored = AppStore(repository: repo, now: { now }); try restored.load()
        XCTAssertEqual(restored.snapshot, store.snapshot)
        try restored.resume(); now += 720; try restored.tick()
        XCTAssertEqual(restored.snapshot.timer.phase, .focus)
        XCTAssertEqual(restored.snapshot.records.count, 1)
    }

    @MainActor func testInvalidLongBreakSettingsAreRejected() throws {
        let store = AppStore(repository: MemoryRepository()); try store.load()
        for (interval, minutes) in [(0, 15), (13, 15), (4, 0), (4, 61)] {
            let p = try preferences(interval: interval, minutes: minutes)
            XCTAssertThrowsError(try store.updatePreferences(p))
            var snapshot = AppSnapshot(); snapshot.preferences = p
            XCTAssertThrowsError(try LocalRepository.validate(snapshot))
        }
    }
}
