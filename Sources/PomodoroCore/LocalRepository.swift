import Foundation

public protocol SnapshotRepository {
    func load() throws -> AppSnapshot?
    func save(_ snapshot: AppSnapshot) throws
}
public struct LocalRepository: SnapshotRepository {
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }
    public static func defaultFileURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Pomodoro/state.json")
    }
    public func load() throws -> AppSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: Data(contentsOf: fileURL))
            try Self.validate(snapshot)
            return snapshot
        } catch { throw PomodoroError.invalid("기록을 읽지 못했어요. 원본은 보존됩니다.\n\(fileURL.path)\n\(error.localizedDescription)") }
    }
    public func save(_ snapshot: AppSnapshot) throws {
        try Self.validate(snapshot)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }
    static func validate(_ s: AppSnapshot) throws {
        let taskIDs = Set(s.tasks.map(\.id)), recordIDs = Set(s.records.map(\.id))
        guard s.schemaVersion == 1 else { throw PomodoroError.invalid("지원하지 않는 기록 버전입니다.") }
        guard !s.tasks.isEmpty, taskIDs.count == s.tasks.count, taskIDs.contains(s.selectedTaskID),
              s.tasks.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              (1...60).contains(s.preferences.focusMinutes), (1...60).contains(s.preferences.breakMinutes),
              (1...60).contains(s.preferences.longBreakMinutes), (1...12).contains(s.preferences.longBreakInterval),
              (0...11).contains(s.timer.completedFocusCount),
              recordIDs.count == s.records.count,
              s.records.allSatisfy({ taskIDs.contains($0.taskID) && $0.focusedSeconds.isFinite && $0.focusedSeconds >= 1 && $0.endedAt >= $0.startedAt }),
              Set(s.pendingMemoIDs).count == s.pendingMemoIDs.count,
              s.pendingMemoIDs.allSatisfy({ recordIDs.contains($0) }),
              s.timer.durationSeconds.isFinite, (60...3600).contains(s.timer.durationSeconds),
              s.timer.remainingSeconds.isFinite, (0...s.timer.durationSeconds).contains(s.timer.remainingSeconds)
        else { throw PomodoroError.invalid("기록 형식이나 시간 값이 올바르지 않습니다.") }
        if s.timer.status != .ready {
            guard let task = s.timer.taskID, taskIDs.contains(task), s.timer.startedAt != nil,
                  s.timer.status != .running || s.timer.deadline != nil else { throw PomodoroError.invalid("진행 중인 타이머 정보가 올바르지 않습니다.") }
        }
        try validateExam(s)
    }
    static func validateExam(_ s: AppSnapshot) throws {
        let presetIDs = Set(s.examPresets.map(\.id))
        guard presetIDs.count == s.examPresets.count,
              s.examPresets.allSatisfy({ isValidSections($0.sections) && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { throw PomodoroError.invalid("시험 세트 형식이 올바르지 않습니다.") }
        let e = s.examTimer
        if e.status != .ready {
            guard isValidSections(e.sections), e.sections.indices.contains(e.currentIndex), e.startedAt != nil,
                  e.durationSeconds.isFinite, e.durationSeconds > 0,
                  e.remainingSeconds.isFinite, (0...e.durationSeconds).contains(e.remainingSeconds),
                  e.status != .running || e.deadline != nil
            else { throw PomodoroError.invalid("진행 중인 시험 정보가 올바르지 않습니다.") }
        }
    }
    private static func isValidSections(_ sections: [ExamSection]) -> Bool {
        !sections.isEmpty && sections.count <= 20
            && sections.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...180).contains($0.minutes) }
    }
}
