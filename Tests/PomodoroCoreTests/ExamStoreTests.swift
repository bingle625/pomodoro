import XCTest
@testable import PomodoroCore

@MainActor final class ExamStoreTests: XCTestCase {
    let sections = [ExamSection(name: "언어이해", minutes: 20), ExamSection(name: "논리판단", minutes: 10)]

    private func store(now: @escaping () -> Date) throws -> AppStore {
        let s = AppStore(repository: MemoryRepository(), now: now); try s.load(); return s
    }

    func testFreshInstallSeedsHmatPreset() throws {
        let s = try store(now: { Date(timeIntervalSince1970: 1_800_000_000) })
        XCTAssertEqual(s.snapshot.examPresets.first?.name, "현대자동차그룹 온라인 HMAT")
        XCTAssertEqual(s.snapshot.examPresets.first?.sections.count, 5)
    }

    func testStartAdvanceAndFinishViaTick() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let s = try store(now: { now })
        var bells = 0; s.onBell = { bells += 1 }
        let id = try s.addExamPreset(name: "HMAT", sections: sections)
        try s.startExam(presetID: id)
        XCTAssertTrue(s.isExamActive)
        XCTAssertEqual(s.currentExamSection?.name, "언어이해")
        now += 1200; try s.tick()
        XCTAssertEqual(s.currentExamSection?.name, "논리판단")
        now += 600; try s.tick()
        XCTAssertFalse(s.isExamActive)
        XCTAssertEqual(bells, 2)
    }

    func testPauseResumeExcludesTime() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let s = try store(now: { now })
        let id = try s.addExamPreset(name: "HMAT", sections: sections)
        try s.startExam(presetID: id)
        now += 60; try s.pauseExam()
        now += 300; try s.resumeExam()
        now += 60; try s.tick()
        XCTAssertEqual(s.examRemainingSeconds, 1080)
    }

    func testCannotStartWhileFocusTimerRunning() throws {
        let s = try store(now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let id = try s.addExamPreset(name: "HMAT", sections: sections)
        try s.start()
        XCTAssertThrowsError(try s.startExam(presetID: id))
    }

    func testStopExamResets() throws {
        let s = try store(now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let id = try s.addExamPreset(name: "HMAT", sections: sections)
        try s.startExam(presetID: id)
        try s.stopExam()
        XCTAssertFalse(s.isExamActive)
    }

    func testInvalidSectionsRejected() throws {
        let s = try store(now: { Date(timeIntervalSince1970: 1_800_000_000) })
        XCTAssertThrowsError(try s.addExamPreset(name: "bad", sections: []))
        XCTAssertThrowsError(try s.addExamPreset(name: "bad", sections: [ExamSection(name: "", minutes: 10)]))
        XCTAssertThrowsError(try s.addExamPreset(name: "bad", sections: [ExamSection(name: "x", minutes: 0)]))
        XCTAssertThrowsError(try s.addExamPreset(name: "bad", sections: [ExamSection(name: "x", minutes: 181)]))
        XCTAssertThrowsError(try s.addExamPreset(name: "  ", sections: sections))
    }

    func testPersistenceRoundTripOfRunningExam() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = MemoryRepository()
        let s = AppStore(repository: repo, now: { now }); try s.load()
        let id = try s.addExamPreset(name: "HMAT", sections: sections)
        try s.startExam(presetID: id)
        now += 100
        let restored = AppStore(repository: repo, now: { now }); try restored.load()
        XCTAssertEqual(restored.currentExamSection?.name, "언어이해")
        XCTAssertEqual(restored.examRemainingSeconds, 1100)
    }

    func testEditingPresetDoesNotDisturbRunningExam() throws {
        let s = try store(now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let id = try s.addExamPreset(name: "HMAT", sections: sections)
        try s.startExam(presetID: id)
        // Editing a running set is blocked; the active run keeps its own copy regardless.
        XCTAssertThrowsError(try s.updateExamPreset(id: id, name: "HMAT2", sections: [ExamSection(name: "x", minutes: 5)]))
        XCTAssertEqual(s.snapshot.examTimer.sections, sections)
    }

    func testLegacySnapshotWithoutExamFieldsLoads() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSnapshot())) as? [String: Any])
        json.removeValue(forKey: "examPresets"); json.removeValue(forKey: "examTimer")
        let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(snapshot.examPresets.isEmpty)
        XCTAssertEqual(snapshot.examTimer.status, .ready)
        try LocalRepository.validate(snapshot)
    }
}
