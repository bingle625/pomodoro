import Foundation

public struct TimerEngine {
    public private(set) var state: TimerState
    public init(state: TimerState) { self.state = state }
    public func remaining(at now: Date) -> TimeInterval {
        if state.status == .running, let deadline = state.deadline {
            return min(state.durationSeconds, max(0, deadline.timeIntervalSince(now)))
        }
        return state.remainingSeconds
    }
    public mutating func start(taskID: UUID, preferences: Preferences, at now: Date) {
        guard state.status == .ready else { return }
        state.sessionID = UUID(); state.taskID = taskID; state.startedAt = now
        state.durationSeconds = preferences.duration(for: state.phase)
        state.remainingSeconds = state.durationSeconds
        state.deadline = now.addingTimeInterval(state.durationSeconds); state.status = .running
    }
    public mutating func pause(at now: Date) {
        guard state.status == .running else { return }
        state.remainingSeconds = remaining(at: now); state.deadline = nil; state.status = .paused
    }
    public mutating func resume(at now: Date) {
        guard state.status == .paused else { return }
        state.deadline = now.addingTimeInterval(state.remainingSeconds); state.status = .running
    }
    public mutating func advance(at now: Date, preferences: Preferences) -> TimerCompletion? {
        guard state.status == .running, remaining(at: now) <= 0, let deadline = state.deadline else { return nil }
        let completion = event(at: deadline, focused: state.durationSeconds, completed: true)
        let taskID = state.taskID
        let next: TimerPhase
        if state.phase == .focus {
            state.completedFocusCount += 1
            if state.completedFocusCount >= preferences.longBreakInterval {
                next = .longRest
                state.completedFocusCount = 0
            } else {
                next = .rest
            }
        } else {
            next = .focus
        }
        prepare(phase: next, preferences: preferences)
        if preferences.autoStart, let taskID { start(taskID: taskID, preferences: preferences, at: now) }
        return completion
    }
    public mutating func stop(at now: Date, preferences: Preferences) -> TimerCompletion? {
        guard state.status != .ready else { return nil }
        let elapsed = state.durationSeconds - remaining(at: now)
        let completion = elapsed >= 1 ? event(at: now, focused: elapsed, completed: false) : nil
        prepare(phase: .focus, preferences: preferences)
        return completion
    }
    public mutating func refreshReady(preferences: Preferences) {
        guard state.status == .ready else { return }
        prepare(phase: state.phase, preferences: preferences)
    }
    private mutating func prepare(phase: TimerPhase, preferences: Preferences) {
        let completedFocusCount = state.completedFocusCount
        state = TimerState(); state.phase = phase
        state.completedFocusCount = completedFocusCount
        state.durationSeconds = preferences.duration(for: phase); state.remainingSeconds = state.durationSeconds
    }
    private func event(at endedAt: Date, focused: TimeInterval, completed: Bool) -> TimerCompletion? {
        guard let taskID = state.taskID, let startedAt = state.startedAt else { return nil }
        return TimerCompletion(sessionID: state.sessionID, phase: state.phase, taskID: taskID,
                               startedAt: startedAt, endedAt: endedAt, focusedSeconds: focused, completed: completed)
    }
}
