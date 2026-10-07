import Foundation

/// One timed section of a multi-section exam (e.g. 언어이해 · 20분).
public struct ExamSection: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var minutes: Int
    public init(id: UUID = UUID(), name: String, minutes: Int) {
        self.id = id; self.name = name; self.minutes = minutes
    }
}

/// A saved, reusable set of sections run back-to-back (e.g. 현대자동차그룹 HMAT).
public struct ExamPreset: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var sections: [ExamSection]
    public init(id: UUID = UUID(), name: String, sections: [ExamSection]) {
        self.id = id; self.name = name; self.sections = sections
    }
    public var totalMinutes: Int { sections.reduce(0) { $0 + $1.minutes } }
    /// Seeded on fresh installs as a worked example matching a real online aptitude test.
    public static var hmatSample: ExamPreset {
        ExamPreset(name: "현대자동차그룹 온라인 HMAT", sections: [
            ExamSection(name: "언어이해", minutes: 20),
            ExamSection(name: "논리판단", minutes: 10),
            ExamSection(name: "자료해석", minutes: 20),
            ExamSection(name: "공간지각(상반기)", minutes: 12),
            ExamSection(name: "도식이해(하반기)", minutes: 12)
        ])
    }
}

public enum ExamStatus: String, Codable { case ready, running, paused }

/// Running state of an exam. Deadline-based like `TimerState`, so it stays correct
/// across pause/resume/sleep without a running loop. Sections are copied in at start,
/// so editing the source preset never disturbs a run in progress.
public struct ExamTimerState: Codable, Equatable {
    public var status: ExamStatus = .ready
    public var presetName: String = ""
    public var sections: [ExamSection] = []
    public var currentIndex: Int = 0
    public var startedAt: Date?
    public var durationSeconds: TimeInterval = 0
    public var remainingSeconds: TimeInterval = 0
    public var deadline: Date?
    public init() {}
}

/// Emitted when a section's time runs out; drives the bell and section advance.
public struct ExamCompletion {
    public let finishedIndex: Int
    public let isLast: Bool
}
