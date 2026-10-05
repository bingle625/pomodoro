import Foundation
import Observation

public struct UpdateSafety {
    public var timerStatus: TimerStatus
    public var savePending: Bool
    public var readOnly: Bool
    public var memoPending: Bool
    public var editorOpen: Bool
    public var settingsOpen: Bool
    public var settingsDirty: Bool
    public init(timerStatus: TimerStatus = .ready, savePending: Bool = false, readOnly: Bool = false, memoPending: Bool = false, editorOpen: Bool = false, settingsOpen: Bool = false, settingsDirty: Bool = false) {
        self.timerStatus = timerStatus; self.savePending = savePending; self.readOnly = readOnly
        self.memoPending = memoPending; self.editorOpen = editorOpen
        self.settingsOpen = settingsOpen; self.settingsDirty = settingsDirty
    }
    public var blockingReason: String? { blockingReason(automatic: false) }
    public func blockingReason(automatic: Bool) -> String? {
        if savePending || readOnly { return "기록 저장 문제를 해결하면 업데이트를 설치합니다." }
        if timerStatus == .paused { return "타이머가 일시정지되어 있어요. 타이머를 재개해 마치거나 종료하면 설치합니다." }
        if timerStatus == .running { return "진행 중인 타이머가 끝나면 업데이트를 설치합니다." }
        if memoPending || editorOpen { return "메모와 편집 중인 작업을 저장하고 창을 닫으면 설치합니다." }
        if settingsOpen && settingsDirty { return "변경한 설정을 저장하거나 설정 창을 닫으면 설치합니다." }
        if automatic && settingsOpen { return "설정 창을 닫으면 업데이트를 설치합니다." }
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
        guard safety.blockingReason(automatic: isAutomaticPending) == nil, let action = installation else { return }
        installation = nil; isPending = false; isAutomaticPending = false
        action()
    }
    public func cancel() { installation = nil; isPending = false; isAutomaticPending = false }
}
