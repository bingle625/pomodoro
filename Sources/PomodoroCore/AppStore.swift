import Foundation
import Observation

@MainActor @Observable public final class AppStore {
    public private(set) var snapshot = AppSnapshot()
    public private(set) var storageError: String?
    public private(set) var isReadOnly = false
    public private(set) var isUpdating = false
    public func setUpdateInstallationInProgress(_ active: Bool) { isUpdating = active }
    public private(set) var currentDate = Date()
    public var onBell: (() -> Void)?
    @ObservationIgnored private let repository: any SnapshotRepository
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var pending: (AppSnapshot, Bool)?
    public var memoSessionID: UUID? { snapshot.pendingMemoIDs.first }
    public var selectedTask: FocusTask { snapshot.tasks.first(where: { $0.id == snapshot.selectedTaskID }) ?? snapshot.tasks[0] }
    public var remainingSeconds: TimeInterval { TimerEngine(state: snapshot.timer).remaining(at: currentDate) }
    public var hasPendingSave: Bool { pending != nil }
    public init(repository: any SnapshotRepository, now: @escaping () -> Date = Date.init) { self.repository = repository; self.now = now }
    public func load() throws {
        do {
            if let saved = try repository.load() { snapshot = saved } else { try repository.save(snapshot) }
            isReadOnly = false; storageError = nil; currentDate = now()
        } catch { isReadOnly = true; storageError = error.localizedDescription; throw error }
        try tick()
    }
    private func ensureWritable() throws {
        guard !isUpdating else { throw PomodoroError.invalid("업데이트 설치 중입니다. 잠시 기다려 주세요.") }
        guard !isReadOnly else { throw PomodoroError.invalid("기록을 읽을 수 없어 변경할 수 없습니다.") }
        guard pending == nil else { throw PomodoroError.invalid("저장을 먼저 다시 시도해 주세요.") }
    }
    private func commit(_ next: AppSnapshot, bell: Bool = false) throws {
        do {
            try repository.save(next); snapshot = next; pending = nil; storageError = nil
            if bell && next.preferences.soundEnabled { onBell?() }
        } catch { pending = (next, bell); storageError = error.localizedDescription; throw error }
    }
    public func retrySave() throws {
        guard let (savedValue, bell) = pending else { if isReadOnly { try load() }; return }
        var value = savedValue
        // A next stage deferred by a failed write starts on successful retry, not in the past.
        if bell, value.timer.status == .running {
            value.timer.startedAt = now(); value.timer.deadline = now().addingTimeInterval(value.timer.durationSeconds)
        }
        try commit(value, bell: bell)
    }
    private func editTimer(_ action: (inout TimerEngine, Date) -> TimerCompletion?) throws {
        try ensureWritable(); currentDate = now()
        var next = snapshot; var engine = TimerEngine(state: next.timer)
        let event = action(&engine, currentDate); next.timer = engine.state
        if let event, event.phase == .focus, !next.records.contains(where: { $0.id == event.sessionID }) {
            next.records.append(FocusRecord(id: event.sessionID, taskID: event.taskID, startedAt: event.startedAt, endedAt: event.endedAt, focusedSeconds: event.focusedSeconds, completed: event.completed))
            next.pendingMemoIDs.append(event.sessionID)
        }
        if next != snapshot { try commit(next, bell: event?.completed == true) }
    }
    public func tick() throws {
        currentDate = now()
        guard !isReadOnly, !isUpdating, pending == nil else { return }
        let p = snapshot.preferences
        try editTimer { $0.advance(at: $1, preferences: p) }
    }
    public func start() throws {
        let p = snapshot.preferences, id = snapshot.selectedTaskID
        try editTimer { $0.start(taskID: id, preferences: p, at: $1); return nil }
    }
    public func pause() throws {
        try tick()
        try editTimer { $0.pause(at: $1); return nil }
    }
    public func pauseForSleep() throws {
        guard !isReadOnly, !isUpdating else { return }
        if pending == nil {
            do { try pause(); return }
            catch { guard pending != nil else { throw error } }
        }
        // Preserve any unsaved edit while freezing its timer before the Mac sleeps.
        guard let (saved, bell) = pending else { return }
        var value = saved
        currentDate = now()
        if bell, value.timer.status == .running {
            // An auto-start deferred by a failed save has not begun yet.
            value.timer.startedAt = currentDate
            value.timer.deadline = currentDate.addingTimeInterval(value.timer.durationSeconds)
        }
        var engine = TimerEngine(state: value.timer)
        engine.pause(at: currentDate)
        value.timer = engine.state
        try commit(value, bell: bell)
    }
    public func deleteRecord(recordID: UUID) throws {
        try ensureWritable()
        guard snapshot.records.contains(where: { $0.id == recordID }) else { throw PomodoroError.invalid("기록을 찾을 수 없어요.") }
        var next = snapshot
        next.records.removeAll { $0.id == recordID }
        next.pendingMemoIDs.removeAll { $0 == recordID }
        try commit(next)
    }
    public func resume() throws { try editTimer { $0.resume(at: $1); return nil } }
    public func stop() throws {
        try tick()
        let p = snapshot.preferences
        try editTimer { $0.stop(at: $1, preferences: p) }
    }
    public func selectTask(_ id: UUID) throws {
        try ensureWritable()
        guard snapshot.timer.status == .ready else { throw PomodoroError.invalid("진행 중인 타이머를 먼저 종료해 주세요.") }
        guard snapshot.tasks.contains(where: { $0.id == id }) else { return }
        var next = snapshot; next.selectedTaskID = id; try commit(next)
    }
    private func validName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw PomodoroError.invalid("작업 이름을 입력해 주세요.") }; return value
    }
    public func addTask(name: String, colorHex: String) throws {
        try ensureWritable()
        let task = FocusTask(name: try validName(name), colorHex: colorHex)
        var next = snapshot; next.tasks.append(task)
        if next.timer.status == .ready { next.selectedTaskID = task.id }
        try commit(next)
    }
    public func updateTask(id: UUID, name: String, colorHex: String) throws {
        try ensureWritable(); let name = try validName(name)
        var next = snapshot
        if let index = next.tasks.firstIndex(where: { $0.id == id }) { next.tasks[index].name = name; next.tasks[index].colorHex = colorHex }
        try commit(next)
    }
    public func deleteTask(id: UUID) throws {
        try ensureWritable()
        guard snapshot.tasks.count > 1 else { throw PomodoroError.invalid("마지막 작업은 삭제할 수 없어요.") }
        guard snapshot.timer.status == .ready || snapshot.timer.taskID != id else { throw PomodoroError.invalid("타이머를 먼저 종료해 주세요.") }
        var next = snapshot; next.tasks.removeAll { $0.id == id }; next.records.removeAll { $0.taskID == id }
        let remainingIDs = Set(next.records.map(\.id)); next.pendingMemoIDs.removeAll { !remainingIDs.contains($0) }
        if next.selectedTaskID == id { next.selectedTaskID = next.tasks[0].id }; try commit(next)
    }
    public func updatePreferences(_ value: Preferences) throws {
        try ensureWritable()
        guard (1...60).contains(value.focusMinutes), (1...60).contains(value.breakMinutes), (1...60).contains(value.longBreakMinutes) else { throw PomodoroError.invalid("시간은 1~60분으로 설정해 주세요.") }
        guard (1...12).contains(value.longBreakInterval) else { throw PomodoroError.invalid("긴 휴식 주기는 집중 1~12회로 설정해 주세요.") }
        var next = snapshot; next.preferences = value
        var engine = TimerEngine(state: next.timer); engine.refreshReady(preferences: value); next.timer = engine.state
        try commit(next)
    }
    public var maximumAdjustableMinutes: Int {
        let elapsed = snapshot.timer.status == .paused ? snapshot.timer.durationSeconds - snapshot.timer.remainingSeconds : 0
        return max(0, min(60, Int(floor((3600 - elapsed) / 60))))
    }
    public func adjustRemainingMinutes(_ minutes: Int) throws {
        try ensureWritable()
        guard snapshot.timer.status != .running else { throw PomodoroError.invalid("시간을 조절하려면 먼저 일시정지해 주세요.") }
        guard minutes >= 1, minutes <= maximumAdjustableMinutes else { throw PomodoroError.invalid("전체 세션이 60분 이내가 되도록 남은 시간을 선택해 주세요.") }
        if snapshot.timer.status == .ready {
            var preferences = snapshot.preferences
            if snapshot.timer.phase == .focus { preferences.focusMinutes = minutes }
            else if snapshot.timer.phase == .longRest { preferences.longBreakMinutes = minutes }
            else { preferences.breakMinutes = minutes }
            try updatePreferences(preferences)
        } else {
            var next = snapshot
            let elapsed = next.timer.durationSeconds - next.timer.remainingSeconds
            next.timer.remainingSeconds = Double(minutes * 60)
            next.timer.durationSeconds = elapsed + next.timer.remainingSeconds
            try commit(next)
        }
    }
    public func saveMemo(recordID: UUID, text: String, taskID: UUID? = nil) throws {
        try ensureWritable(); var next = snapshot
        guard let index = next.records.firstIndex(where: { $0.id == recordID }) else { throw PomodoroError.invalid("기록을 찾을 수 없어요.") }
        if let taskID {
            guard next.tasks.contains(where: { $0.id == taskID }) else { throw PomodoroError.invalid("이동할 작업을 찾을 수 없어요.") }
            next.records[index].taskID = taskID
        }
        next.records[index].memo = text; next.pendingMemoIDs.removeAll { $0 == recordID }; try commit(next)
    }
    public func skipMemo(recordID: UUID) throws {
        try ensureWritable(); var next = snapshot; next.pendingMemoIDs.removeAll { $0 == recordID }; try commit(next)
    }
}
