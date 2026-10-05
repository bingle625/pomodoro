import XCTest
@testable import PomodoroCore

final class PreferencesTests: XCTestCase {
    func testOlderPreferencesDefaultToOpaqueBackground() throws {
        let data = Data(#"{"focusMinutes":40,"breakMinutes":10,"soundEnabled":false,"autoStart":true}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertFalse(preferences.transparentFloatingBackground)
        XCTAssertEqual(preferences.focusMinutes, 40)
        XCTAssertEqual(preferences.breakMinutes, 10)
        XCTAssertFalse(preferences.soundEnabled)
        XCTAssertTrue(preferences.autoStart)
    }

    @MainActor func testTransparencySurvivesSaveAndReloadWithoutChangingTimer() throws {
        let repository = MemoryRepository()
        let store = AppStore(repository: repository)
        try store.load(); try store.start()
        let timer = store.snapshot.timer
        var preferences = store.snapshot.preferences
        preferences.transparentFloatingBackground = true
        try store.updatePreferences(preferences)
        let data = try JSONEncoder().encode(store.snapshot)
        repository.value = try JSONDecoder().decode(AppSnapshot.self, from: data)
        let reloaded = AppStore(repository: repository)
        try reloaded.load()
        XCTAssertTrue(reloaded.snapshot.preferences.transparentFloatingBackground)
        XCTAssertEqual(reloaded.snapshot.timer, timer)
    }
}
