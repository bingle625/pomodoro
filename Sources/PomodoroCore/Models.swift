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
    public var soundEnabled = true
    public var autoStart = false
    public init() {}
    public func duration(for phase: TimerPhase) -> TimeInterval { Double(phase == .focus ? focusMinutes : breakMinutes) * 60 }
}
public enum TimerPhase: String, Codable { case focus, rest }
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
    public init() {}
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
