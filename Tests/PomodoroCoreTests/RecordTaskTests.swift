import XCTest
@testable import PomodoroCore

final class RecordTaskTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot() -> AppSnapshot {
        var value = AppSnapshot()
        value.tasks[0].name = "코테 공부"
        value.tasks.append(FocusTask(name: "인적성 공부"))
        value.records = [FocusRecord(taskID: value.tasks[0].id, startedAt: now.addingTimeInterval(-600), endedAt: now, focusedSeconds: 600, completed: false, memo: "풀이 기록")]
        value.pendingMemoIDs = [value.records[0].id]
        return value
    }

    @MainActor func testMovePreservesRecordDetailsAndTransfersStatistics() throws {
        let repo = MemoryRepository(); repo.value = snapshot()
        let store = AppStore(repository: repo, now: { self.now }); try store.load()
        let original = store.snapshot.records[0]
        let destination = store.snapshot.tasks[1].id
        try store.start()
        let timer = store.snapshot.timer
        try store.saveMemo(recordID: original.id, text: original.memo, taskID: destination)
        var expected = original; expected.taskID = destination
        XCTAssertEqual(store.snapshot.records, [expected])
        XCTAssertEqual(store.snapshot.timer, timer)
        XCTAssertEqual(store.snapshot.selectedTaskID, original.taskID)
        XCTAssertTrue(store.snapshot.pendingMemoIDs.isEmpty)
        let interval = DateInterval(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(1))
        let stats = Statistics()
        XCTAssertEqual(stats.summary(records: store.snapshot.records, taskID: original.taskID, interval: interval).totalSeconds, 0)
        XCTAssertEqual(stats.summary(records: store.snapshot.records, taskID: destination, interval: interval).totalSeconds, 600)
        XCTAssertEqual(stats.summary(records: store.snapshot.records, taskID: destination, interval: interval).count, 1)
    }

    @MainActor func testMovedTaskAndEditedMemoSurviveDiskReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = LocalRepository(fileURL: url); let original = snapshot(); try repo.save(original)
        let store = AppStore(repository: repo, now: { self.now }); try store.load()
        try store.saveMemo(recordID: original.records[0].id, text: "수정한 메모", taskID: original.tasks[1].id)
        let restored = AppStore(repository: repo, now: { self.now }); try restored.load()
        XCTAssertEqual(restored.snapshot.records[0].taskID, original.tasks[1].id)
        XCTAssertEqual(restored.snapshot.records[0].memo, "수정한 메모")
        XCTAssertTrue(restored.snapshot.pendingMemoIDs.isEmpty)
    }

    @MainActor func testInvalidDestinationOrRecordLeavesSnapshotUnchanged() throws {
        let repo = MemoryRepository(); repo.value = snapshot()
        let store = AppStore(repository: repo); try store.load()
        let before = store.snapshot
        XCTAssertThrowsError(try store.saveMemo(recordID: before.records[0].id, text: "변경", taskID: UUID()))
        XCTAssertThrowsError(try store.saveMemo(recordID: UUID(), text: "변경", taskID: before.tasks[1].id))
        XCTAssertEqual(store.snapshot, before)
        XCTAssertEqual(repo.value, before)
    }

    @MainActor func testFailedMoveRetriesTaskAndMemoTogether() throws {
        let repo = MemoryRepository(); repo.value = snapshot()
        let store = AppStore(repository: repo); try store.load()
        let before = store.snapshot
        repo.failSave = true
        XCTAssertThrowsError(try store.saveMemo(recordID: before.records[0].id, text: "수정한 메모", taskID: before.tasks[1].id))
        XCTAssertEqual(store.snapshot, before)
        XCTAssertEqual(repo.value, before)
        repo.failSave = false; try store.retrySave()
        XCTAssertEqual(store.snapshot.records[0].taskID, before.tasks[1].id)
        XCTAssertEqual(store.snapshot.records[0].memo, "수정한 메모")
        XCTAssertTrue(store.snapshot.pendingMemoIDs.isEmpty)
        XCTAssertEqual(repo.value, store.snapshot)
    }

    @MainActor func testSelectTaskAdjustDurationAndStartRecordsChosenTask() throws {
        var date = now
        let repo = MemoryRepository(); repo.value = snapshot()
        let store = AppStore(repository: repo, now: { date }); try store.load()
        let originalTask = store.snapshot.tasks[0].id
        let destination = store.snapshot.tasks[1].id
        try store.selectTask(destination); try store.adjustRemainingMinutes(10); try store.start()
        XCTAssertEqual(store.snapshot.timer.taskID, destination)
        XCTAssertEqual(store.snapshot.timer.durationSeconds, 600)
        XCTAssertThrowsError(try store.selectTask(originalTask))
        date += 60; try store.pause()
        XCTAssertThrowsError(try store.selectTask(originalTask))
        try store.resume(); date += 540; try store.tick()
        XCTAssertEqual(store.snapshot.records.last?.taskID, destination)
        XCTAssertEqual(store.snapshot.records.last?.focusedSeconds, 600)
        let restored = AppStore(repository: repo, now: { date }); try restored.load()
        XCTAssertEqual(restored.snapshot.selectedTaskID, destination)
    }
}
