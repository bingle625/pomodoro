import XCTest
@testable import PomodoroCore
final class LocalRepositoryTests: XCTestCase {
    func file() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir.appendingPathComponent("state.json")
    }
    func testRoundTrip() throws {
        let repository = LocalRepository(fileURL: try file())
        var s = AppSnapshot()
        let record = FocusRecord(taskID: s.selectedTaskID, startedAt: Date(), endedAt: Date(), focusedSeconds: 60, memo: "한국어 🐻\n줄바꿈")
        s.records = [record]; s.pendingMemoIDs = [record.id]
        try repository.save(s)
        XCTAssertEqual(try repository.load(), s)
    }
    func testCorruptFileRemainsUnchanged() throws {
        let url = try file(); let original = Data("broken".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try LocalRepository(fileURL: url).load())
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testFutureSchema() throws {
        let url = try file(); var s = AppSnapshot(); s.schemaVersion = 999
        let data = try JSONEncoder().encode(s); try data.write(to: url)
        XCTAssertThrowsError(try LocalRepository(fileURL: url).load())
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
    func testSaveFailureKeepsOldFile() throws {
        let url = try file(); let repo = LocalRepository(fileURL: url)
        let s = AppSnapshot(); try repo.save(s)
        var invalid = s; invalid.preferences.focusMinutes = 0
        XCTAssertThrowsError(try repo.save(invalid))
        XCTAssertEqual(try repo.load(), s)
    }
    func testMissingAndInvalidReference() throws {
        let url = try file(); let repo = LocalRepository(fileURL: url)
        XCTAssertNil(try repo.load())
        var s = AppSnapshot(); s.selectedTaskID = UUID()
        try JSONEncoder().encode(s).write(to: url)
        XCTAssertThrowsError(try repo.load())
    }
}
