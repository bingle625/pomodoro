import Foundation
import Observation

public struct UpdateSafety {
    public var timerStatus: TimerStatus
    public var savePending: Bool
    public var readOnly: Bool
    public var memoPending: Bool
    public var editorOpen: Bool
    public init(timerStatus: TimerStatus = .ready, savePending: Bool = false, readOnly: Bool = false, memoPending: Bool = false, editorOpen: Bool = false) {
        self.timerStatus = timerStatus; self.savePending = savePending; self.readOnly = readOnly
        self.memoPending = memoPending; self.editorOpen = editorOpen
    }
    public var blockingReason: String? {
        if savePending || readOnly { return "기록 저장 문제를 해결하면 업데이트를 설치합니다." }
        if timerStatus != .ready { return "진행 중인 타이머가 끝나면 업데이트를 설치합니다." }
        if memoPending || editorOpen { return "메모와 설정 창을 닫으면 업데이트를 설치합니다." }
        return nil
    }
}

@MainActor @Observable public final class UpdateInstallGate {
    public private(set) var isPending = false
    public private(set) var isAutomaticPending = false
    @ObservationIgnored private var installation: (() -> Void)?
    public init() {}
    public func deferInstallation(automatic: Bool = false, _ action: @escaping () -> Void) { installation = action; isPending = true; isAutomaticPending = automatic }
    public func process(_ safety: UpdateSafety, automaticInstallationEnabled: Bool = true) {
        guard !isAutomaticPending || automaticInstallationEnabled else { return }
        guard safety.blockingReason == nil, let action = installation else { return }
        installation = nil; isPending = false; isAutomaticPending = false
        action()
    }
    public func cancel() { installation = nil; isPending = false; isAutomaticPending = false }
}
