import Foundation

/// Pure sequential multi-section timer. Holds no clock; callers pass `at now:`.
/// Sections run back-to-back; a finished section auto-advances to the next and
/// the whole run resets to `.ready` once the last section ends.
public struct ExamEngine {
    public private(set) var state: ExamTimerState
    public init(state: ExamTimerState) { self.state = state }

    public func remaining(at now: Date) -> TimeInterval {
        if state.status == .running, let deadline = state.deadline {
            return min(state.durationSeconds, max(0, deadline.timeIntervalSince(now)))
        }
        return state.remainingSeconds
    }
    public var currentSection: ExamSection? {
        state.sections.indices.contains(state.currentIndex) ? state.sections[state.currentIndex] : nil
    }
    public mutating func start(sections: [ExamSection], presetName: String, at now: Date) {
        guard state.status == .ready, !sections.isEmpty else { return }
        state.sections = sections; state.presetName = presetName; state.currentIndex = 0
        state.startedAt = now
        begin(at: now)
    }
    public mutating func pause(at now: Date) {
        guard state.status == .running else { return }
        state.remainingSeconds = remaining(at: now); state.deadline = nil; state.status = .paused
    }
    public mutating func resume(at now: Date) {
        guard state.status == .paused else { return }
        state.deadline = now.addingTimeInterval(state.remainingSeconds); state.status = .running
    }
    public mutating func advance(at now: Date) -> ExamCompletion? {
        guard state.status == .running, remaining(at: now) <= 0, let deadline = state.deadline else { return nil }
        let finished = state.currentIndex
        if finished >= state.sections.count - 1 { state = ExamTimerState(); return ExamCompletion(finishedIndex: finished, isLast: true) }
        state.currentIndex += 1
        // Chain from the elapsed deadline so a late tick lands the next section correctly.
        begin(at: deadline)
        return ExamCompletion(finishedIndex: finished, isLast: false)
    }
    public mutating func stop() { state = ExamTimerState() }

    private mutating func begin(at now: Date) {
        let seconds = Double(state.sections[state.currentIndex].minutes) * 60
        state.durationSeconds = seconds; state.remainingSeconds = seconds
        state.deadline = now.addingTimeInterval(seconds); state.status = .running
    }
}
