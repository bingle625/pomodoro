import XCTest
@testable import PomodoroCore

final class SessionTerminationTests: XCTestCase {
    @MainActor func testQuitSavesPartialFocusAndRelaunchStartsAtZero() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = LocalRepository(fileURL: url)
        var state = AppSnapshot(); state.timer.completedFocusCount = 3; try repo.save(state)
        let store = AppStore(repository: repo, now: { now }); try store.load(); try store.start()
        now += 120; try store.prepareForTermination()
        now += 7200
        let restored = AppStore(repository: repo, now: { now }); try restored.load()
        XCTAssertEqual(restored.snapshot.timer.status, .ready)
        XCTAssertEqual(restored.snapshot.timer.phase, .focus)
        XCTAssertEqual(restored.snapshot.timer.completedFocusCount, 0)
        XCTAssertEqual(restored.snapshot.records.count, 1)
        XCTAssertEqual(restored.snapshot.records.first?.focusedSeconds, 120)
        XCTAssertEqual(restored.snapshot.records.first?.completed, false)
        try restored.start(); now += 1500; try restored.tick()
        XCTAssertEqual(restored.snapshot.timer.phase, .rest)
        XCTAssertEqual(restored.snapshot.timer.completedFocusCount, 1)
    }

    @MainActor func testQuitFromReadyOrPausedRestResetsToFocus() throws {
        for status in [TimerStatus.ready, .paused] {
            var now = Date(timeIntervalSince1970: 1_800_000_000)
            var state = AppSnapshot(); state.timer.phase = .longRest
            let repo = MemoryRepository(); repo.value = state
            let store = AppStore(repository: repo, now: { now }); try store.load()
            if status == .paused { try store.start(); now += 60; try store.pause() }
            try store.prepareForTermination()
            XCTAssertEqual(store.snapshot.timer.phase, .focus)
            XCTAssertEqual(store.snapshot.timer.status, .ready)
            XCTAssertEqual(store.snapshot.timer.completedFocusCount, 0)
            XCTAssertTrue(store.snapshot.records.isEmpty)
        }
    }

    @MainActor func testFailedQuitSaveCanRetryWithoutDuplicateRecords() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now }); try store.load(); try store.start()
        now += 60; repo.failSave = true
        XCTAssertThrowsError(try store.prepareForTermination())
        XCTAssertTrue(store.hasPendingSave)
        repo.failSave = false; now += 60; try store.prepareForTermination()
        XCTAssertEqual(store.snapshot.records.count, 1)
        XCTAssertEqual(store.snapshot.records.first?.focusedSeconds, 60)
        XCTAssertEqual(store.snapshot.timer.status, .ready)
        XCTAssertEqual(store.snapshot.timer.completedFocusCount, 0)
    }

    @MainActor func testQuitLeavesUnreadableStorageUntouched() throws {
        let repo = MemoryRepository(); repo.failLoad = true
        let store = AppStore(repository: repo); XCTAssertThrowsError(try store.load())
        try store.prepareForTermination()
        XCTAssertNil(repo.value)
    }
}
