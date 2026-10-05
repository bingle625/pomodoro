import XCTest
@testable import PomodoroCore
final class AppStoreTests: XCTestCase {
    @MainActor func testFirstLaunchAndFocusCompletion() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now })
        try store.load()
        XCTAssertEqual(store.snapshot.tasks.count, 1); XCTAssertEqual(store.snapshot.records.count, 0)
        var bells = 0; store.onBell = { bells += 1 }
        try store.start(); now += 1500; try store.tick(); try store.tick()
        XCTAssertEqual(store.snapshot.records.count, 1); XCTAssertEqual(bells, 1)
        XCTAssertEqual(store.memoSessionID, store.snapshot.records.first?.id)
        try store.skipMemo(recordID: store.memoSessionID!)
        try store.start(); now += 300; try store.tick()
        XCTAssertEqual(store.snapshot.records.count, 1); XCTAssertNil(store.memoSessionID); XCTAssertEqual(bells, 2)
    }
    @MainActor func testCompletionSaveRetryAndRelaunch() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now })
        try store.load(); try store.start()
        var bells = 0; store.onBell = { bells += 1 }; repo.failSave = true; now += 1500
        XCTAssertThrowsError(try store.tick()); XCTAssertEqual(bells, 0)
        repo.failSave = false; try store.retrySave(); try store.tick()
        XCTAssertEqual(bells, 1); XCTAssertEqual(store.snapshot.records.count, 1)
        let other = AppStore(repository: repo, now: { now }); try other.load(); try other.tick()
        XCTAssertEqual(other.snapshot.records.count, 1)
    }
    @MainActor func testMemoQueueIdentityAndFailedEdit() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now }); try store.load()
        try store.start(); now += 1500; try store.tick()
        let first = store.memoSessionID!
        try store.start(); now += 300; try store.tick(); try store.start(); now += 1500; try store.tick()
        let second = store.snapshot.pendingMemoIDs.last!
        repo.failSave = true
        XCTAssertThrowsError(try store.saveMemo(recordID: first, text: "실패한 메모"))
        XCTAssertEqual(store.snapshot.records.first?.memo, "")
        repo.failSave = false; try store.retrySave()
        XCTAssertEqual(store.snapshot.records.first?.memo, "실패한 메모")
        XCTAssertEqual(store.memoSessionID, second)
    }
    @MainActor func testReadOnlyAfterLoadError() throws {
        let repo = MemoryRepository(); repo.failLoad = true
        let store = AppStore(repository: repo); XCTAssertThrowsError(try store.load())
        XCTAssertTrue(store.isReadOnly); XCTAssertThrowsError(try store.start()); XCTAssertNil(repo.value)
    }
    @MainActor func testTaskRulesAndPreferences() throws {
        let repo = MemoryRepository(); let store = AppStore(repository: repo); try store.load()
        let original = store.snapshot.selectedTaskID
        XCTAssertThrowsError(try store.deleteTask(id: original))
        XCTAssertThrowsError(try store.addTask(name: "  ", colorHex: "D90025"))
        try store.addTask(name: "새 작업", colorHex: "287A60")
        let second = store.snapshot.selectedTaskID
        try store.start(); let deadline = store.snapshot.timer.deadline
        XCTAssertThrowsError(try store.selectTask(original)); XCTAssertThrowsError(try store.deleteTask(id: second))
        try store.pause(); XCTAssertThrowsError(try store.selectTask(original))
        var p = Preferences(); p.focusMinutes = 60; try store.updatePreferences(p)
        XCTAssertEqual(store.snapshot.timer.durationSeconds, 1500)
        p.focusMinutes = 0; XCTAssertThrowsError(try store.updatePreferences(p))
        p.focusMinutes = 61; XCTAssertThrowsError(try store.updatePreferences(p))
        try store.stop(); p.focusMinutes = 1; try store.updatePreferences(p)
        XCTAssertEqual(store.snapshot.timer.remainingSeconds, 60); XCTAssertNotNil(deadline)
        try store.deleteTask(id: second); XCTAssertEqual(store.snapshot.tasks.count, 1)
    }
    @MainActor func testInstallationInterlockRejectsNewChangesUntilAborted() throws {
        let repo = MemoryRepository(); let store = AppStore(repository: repo); try store.load()
        let before = store.snapshot
        store.setUpdateInstallationInProgress(true)
        XCTAssertThrowsError(try store.start())
        XCTAssertThrowsError(try store.addTask(name: "업데이트 중 작업", colorHex: "D90025"))
        XCTAssertThrowsError(try store.updatePreferences(Preferences()))
        XCTAssertEqual(store.snapshot, before)
        store.setUpdateInstallationInProgress(false)
        try store.start()
        XCTAssertEqual(store.snapshot.timer.status, .running)
    }
}
