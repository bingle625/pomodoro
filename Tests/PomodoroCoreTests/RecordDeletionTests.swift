import XCTest
@testable import PomodoroCore

final class RecordDeletionTests: XCTestCase {
    @MainActor func testDeleteRemovesOnlyChosenRecordAndMemoQueueEntry() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now })
        try store.load(); try store.start(); now += 1500; try store.tick()
        let first = try XCTUnwrap(store.snapshot.records.first)
        try store.start(); now += 300; try store.tick(); try store.start(); now += 1500; try store.tick()
        let second = try XCTUnwrap(store.snapshot.records.last)
        try store.start()
        let timer = store.snapshot.timer
        let tasks = store.snapshot.tasks
        try store.deleteRecord(recordID: first.id)
        XCTAssertEqual(store.snapshot.records, [second])
        XCTAssertEqual(store.snapshot.pendingMemoIDs, [second.id])
        XCTAssertEqual(store.snapshot.timer, timer)
        XCTAssertEqual(store.snapshot.tasks, tasks)
        let interval = DateInterval(start: first.startedAt, end: now.addingTimeInterval(1))
        let summary = Statistics().summary(records: store.snapshot.records, taskID: first.taskID, interval: interval)
        XCTAssertEqual(summary.count, 1); XCTAssertEqual(summary.totalSeconds, 1500)
        let restored = AppStore(repository: repo, now: { now }); try restored.load()
        XCTAssertEqual(restored.snapshot.records, [second])
        XCTAssertEqual(restored.snapshot.pendingMemoIDs, [second.id])
    }

    @MainActor func testDeleteFailurePreservesRecordUntilRetry() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository(); let store = AppStore(repository: repo, now: { now })
        try store.load(); try store.start(); now += 10; try store.stop()
        let before = store.snapshot
        repo.failSave = true
        XCTAssertThrowsError(try store.deleteRecord(recordID: before.records[0].id))
        XCTAssertEqual(store.snapshot, before); XCTAssertEqual(repo.value, before)
        XCTAssertTrue(store.hasPendingSave)
        repo.failSave = false; try store.retrySave()
        XCTAssertTrue(store.snapshot.records.isEmpty)
        XCTAssertTrue(store.snapshot.pendingMemoIDs.isEmpty)
        XCTAssertEqual(repo.value, store.snapshot)
    }

    @MainActor func testMissingRecordAndUpdateInterlockLeaveDataIntact() throws {
        let repo = MemoryRepository(); let store = AppStore(repository: repo); try store.load()
        let before = store.snapshot
        XCTAssertThrowsError(try store.deleteRecord(recordID: UUID()))
        store.setUpdateInstallationInProgress(true)
        XCTAssertThrowsError(try store.deleteRecord(recordID: UUID()))
        XCTAssertEqual(store.snapshot, before); XCTAssertFalse(store.hasPendingSave)
    }
}
