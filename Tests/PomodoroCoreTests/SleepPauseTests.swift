import XCTest
@testable import PomodoroCore

final class SleepPauseTests: XCTestCase {
    @MainActor func testSleepPausesEveryPhaseUntilManualResumeAndSurvivesReload() throws {
        for phase in [TimerPhase.focus, .rest, .longRest] {
            var now = Date(timeIntervalSince1970: 1_800_000_000)
            var initial = AppSnapshot(); initial.timer.phase = phase
            let repo = MemoryRepository(); repo.value = initial
            let store = AppStore(repository: repo, now: { now }); try store.load(); try store.start()
            let duration = store.snapshot.timer.durationSeconds
            now += 60; try store.pauseForSleep()
            let paused = store.snapshot.timer
            XCTAssertEqual(paused.status, .paused)
            XCTAssertEqual(paused.remainingSeconds, duration - 60)
            XCTAssertNil(paused.deadline)
            now += 7200; try store.tick()
            XCTAssertEqual(store.snapshot.timer, paused)
            XCTAssertTrue(store.snapshot.records.isEmpty)
            let restored = AppStore(repository: repo, now: { now }); try restored.load()
            XCTAssertEqual(restored.snapshot.timer, paused)
            try restored.resume(); now += 30; try restored.stop()
            if phase == .focus { XCTAssertEqual(restored.snapshot.records.first?.focusedSeconds, 90) }
            else { XCTAssertTrue(restored.snapshot.records.isEmpty) }
        }
    }

    @MainActor func testSleepAtCompletionPausesAutoStartedNextPhase() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now }); try store.load()
        var p = Preferences(); p.autoStart = true; try store.updatePreferences(p)
        try store.start(); now += 1500; try store.pauseForSleep()
        XCTAssertEqual(store.snapshot.records.count, 1)
        XCTAssertEqual(store.snapshot.timer.phase, .rest)
        XCTAssertEqual(store.snapshot.timer.status, .paused)
        XCTAssertEqual(store.snapshot.timer.remainingSeconds, 300)
        now += 7200; try store.tick()
        XCTAssertEqual(store.snapshot.records.count, 1)
        XCTAssertEqual(store.remainingSeconds, 300)
    }

    @MainActor func testSleepLeavesReadyAndAlreadyPausedTimersUnchanged() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = AppStore(repository: MemoryRepository(), now: { now }); try store.load()
        let ready = store.snapshot
        try store.pauseForSleep(); XCTAssertEqual(store.snapshot, ready)
        try store.start(); now += 60; try store.pause()
        let paused = store.snapshot
        now += 60; try store.pauseForSleep(); XCTAssertEqual(store.snapshot, paused)
    }

    @MainActor func testSleepPreservesPendingEditAndPausesItsRunningTimerOnRetry() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now }); try store.load()
        try store.start(); now += 60
        let id = store.snapshot.selectedTaskID
        repo.failSave = true
        XCTAssertThrowsError(try store.updateTask(id: id, name: "변경한 작업", colorHex: "D90025"))
        XCTAssertThrowsError(try store.pauseForSleep())
        now += 7200; repo.failSave = false; try store.retrySave(); try store.tick()
        XCTAssertEqual(store.snapshot.timer.status, .paused)
        XCTAssertEqual(store.remainingSeconds, 1440)
        XCTAssertEqual(store.selectedTask.name, "변경한 작업")
        XCTAssertTrue(store.snapshot.records.isEmpty)
    }

    @MainActor func testFailedCompletionBeforeSleepDoesNotStartNextPhaseOnWakeRetry() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now }); try store.load()
        var p = Preferences(); p.autoStart = true; try store.updatePreferences(p); try store.start()
        now += 1500; repo.failSave = true; XCTAssertThrowsError(try store.tick())
        now += 60; XCTAssertThrowsError(try store.pauseForSleep())
        now += 7200; repo.failSave = false; try store.retrySave(); try store.tick()
        XCTAssertEqual(store.snapshot.records.count, 1)
        XCTAssertEqual(store.snapshot.timer.phase, .rest)
        XCTAssertEqual(store.snapshot.timer.status, .paused)
        XCTAssertEqual(store.remainingSeconds, 300)
    }
}
