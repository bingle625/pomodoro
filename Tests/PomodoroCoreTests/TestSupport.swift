import Foundation
@testable import PomodoroCore
final class MemoryRepository: SnapshotRepository {
    var value: AppSnapshot?
    var failSave = false
    var failLoad = false
    func load() throws -> AppSnapshot? {
        if failLoad { throw PomodoroError.invalid("load failed") }; return value
    }
    func save(_ snapshot: AppSnapshot) throws {
        if failSave { throw PomodoroError.invalid("save failed") }; value = snapshot
    }
}
