import XCTest
@testable import PomodoroCore
final class UpdateInstallGateTests: XCTestCase {
    @MainActor func testEachUnsafeStateDefersAndSafeStateInstallsOnce() {
        let states = [
            UpdateSafety(timerStatus: .running), UpdateSafety(timerStatus: .paused),
            UpdateSafety(savePending: true), UpdateSafety(readOnly: true),
            UpdateSafety(memoPending: true), UpdateSafety(editorOpen: true)
        ]
        for state in states {
            let gate = UpdateInstallGate(); var installs = 0
            gate.deferInstallation { installs += 1 }
            gate.process(state)
            XCTAssertEqual(installs, 0); XCTAssertTrue(gate.isPending); XCTAssertNotNil(state.blockingReason)
            gate.process(UpdateSafety()); gate.process(UpdateSafety())
            XCTAssertEqual(installs, 1); XCTAssertFalse(gate.isPending)
        }
    }
    @MainActor func testCancelClearsOldInstallationCallback() {
        let gate = UpdateInstallGate(); var installs = 0
        gate.deferInstallation { installs += 1 }; gate.cancel(); gate.process(UpdateSafety())
        XCTAssertEqual(installs, 0); XCTAssertFalse(gate.isPending)
    }
    @MainActor func testDisablingAutomaticInstallWhileWaitingDoesNotRestart() {
        let gate = UpdateInstallGate(); var installs = 0
        gate.deferInstallation(automatic: true) { installs += 1 }
        gate.process(UpdateSafety(timerStatus: .running), automaticInstallationEnabled: true)
        gate.process(UpdateSafety(), automaticInstallationEnabled: false)
        XCTAssertEqual(installs, 0); XCTAssertTrue(gate.isPending)
        gate.process(UpdateSafety(), automaticInstallationEnabled: true)
        XCTAssertEqual(installs, 1)
    }
    @MainActor func testExplicitInstallStillRunsWhenAutomaticPreferenceIsOff() {
        let gate = UpdateInstallGate(); var installs = 0
        gate.deferInstallation(automatic: false) { installs += 1 }
        gate.process(UpdateSafety(), automaticInstallationEnabled: false)
        XCTAssertEqual(installs, 1)
    }
}
