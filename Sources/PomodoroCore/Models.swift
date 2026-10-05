import Foundation

public struct FocusTask: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public init(id: UUID = UUID(), name: String, colorHex: String = "D90025") {
        self.id = id; self.name = name; self.colorHex = colorHex
    }
}
public struct Preferences: Codable, Equatable {
    public var focusMinutes = 25
    public var breakMinutes = 5
    public var longBreakMinutes = 15
    public var longBreakInterval = 4
    public var soundEnabled = true
    public var autoStart = false
    public var transparentFloatingBackground = false
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case focusMinutes, breakMinutes, longBreakMinutes, longBreakInterval, soundEnabled, autoStart, transparentFloatingBackground
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try values.decode(Int.self, forKey: .focusMinutes)
        breakMinutes = try values.decode(Int.self, forKey: .breakMinutes)
        longBreakMinutes = try values.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 15
        longBreakInterval = try values.decodeIfPresent(Int.self, forKey: .longBreakInterval) ?? 4
        soundEnabled = try values.decode(Bool.self, forKey: .soundEnabled)
        autoStart = try values.decode(Bool.self, forKey: .autoStart)
        // Older state files predate the optional appearance setting.
        transparentFloatingBackground = try values.decodeIfPresent(Bool.self, forKey: .transparentFloatingBackground) ?? false
    }
    public func duration(for phase: TimerPhase) -> TimeInterval {
        switch phase {
        case .focus: return Double(focusMinutes) * 60
        case .rest: return Double(breakMinutes) * 60
        case .longRest: return Double(longBreakMinutes) * 60
        }
    }
}
public enum TimerPhase: String, Codable {
    case focus, rest, longRest
    public var title: String {
        switch self {
        case .focus: return "집중"
        case .rest: return "짧은 휴식"
        case .longRest: return "긴 휴식"
        }
    }
}
public enum TimerStatus: String, Codable { case ready, running, paused }
public struct TimerState: Codable, Equatable {
    public var phase: TimerPhase = .focus
    public var status: TimerStatus = .ready
    public var sessionID: UUID = UUID()
    public var taskID: UUID?
    public var startedAt: Date?
    public var durationSeconds: TimeInterval = 1500
    public var remainingSeconds: TimeInterval = 1500
    public var deadline: Date?
    public var completedFocusCount = 0
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case phase, status, sessionID, taskID, startedAt, durationSeconds, remainingSeconds, deadline, completedFocusCount
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        phase = try values.decode(TimerPhase.self, forKey: .phase)
        status = try values.decode(TimerStatus.self, forKey: .status)
        sessionID = try values.decode(UUID.self, forKey: .sessionID)
        taskID = try values.decodeIfPresent(UUID.self, forKey: .taskID)
        startedAt = try values.decodeIfPresent(Date.self, forKey: .startedAt)
        durationSeconds = try values.decode(TimeInterval.self, forKey: .durationSeconds)
        remainingSeconds = try values.decode(TimeInterval.self, forKey: .remainingSeconds)
        deadline = try values.decodeIfPresent(Date.self, forKey: .deadline)
        completedFocusCount = try values.decodeIfPresent(Int.self, forKey: .completedFocusCount) ?? 0
    }
}
public struct FocusRecord: Codable, Equatable, Identifiable {
    public var id: UUID
    public var taskID: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var focusedSeconds: TimeInterval
    public var completed: Bool
    public var memo: String
    public init(id: UUID = UUID(), taskID: UUID, startedAt: Date, endedAt: Date, focusedSeconds: TimeInterval, completed: Bool = true, memo: String = "") {
        self.id = id; self.taskID = taskID; self.startedAt = startedAt; self.endedAt = endedAt
        self.focusedSeconds = focusedSeconds; self.completed = completed; self.memo = memo
    }
}
public struct TimerCompletion {
    public let sessionID: UUID
    public let phase: TimerPhase
    public let taskID: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let focusedSeconds: TimeInterval
    public let completed: Bool
}
public struct AppSnapshot: Codable, Equatable {
    public var schemaVersion = 1
    public var tasks: [FocusTask]
    public var selectedTaskID: UUID
    public var preferences = Preferences()
    public var timer = TimerState()
    public var records: [FocusRecord] = []
    public var pendingMemoIDs: [UUID] = []
    public init() {
        let task = FocusTask(name: "나의 집중")
        tasks = [task]; selectedTaskID = task.id
    }
}
public enum PomodoroError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
