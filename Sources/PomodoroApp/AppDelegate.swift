import AppKit
import PomodoroCore
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var store: AppStore!
    private var windows: WindowCoordinator!
    private var updates: UpdateCoordinator!
    private var ticker: Timer?
    private let bell = BellPlayer()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .aqua)
        do {
            let url: URL
            if let path = ProcessInfo.processInfo.environment["POMODORO_DATA_PATH"] { url = URL(fileURLWithPath: path) }
            else { url = try LocalRepository.defaultFileURL() }
            store = AppStore(repository: LocalRepository(fileURL: url))
            updates = UpdateCoordinator(store: store)
            windows = WindowCoordinator(store: store, bell: bell, updates: updates)
            updates.hasOpenEditor = { [weak windows = windows] in windows?.hasOpenEditor ?? false }
            updates.settingsState = { [weak windows = windows] in (windows?.settingsOpen ?? false, windows?.settingsDirty ?? false) }
            store.onBell = { [weak self] in self?.windows.playBell() }
            do { try store.load() } catch { /* Main window displays persistent storage error. */ }
            installMenu(); windows.showMain(); windows.synchronizeMemo(); updates.start()
            ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in Task { @MainActor in self?.update() } }
            if let ticker { RunLoop.main.add(ticker, forMode: .common) }
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        } catch { let alert = NSAlert(); alert.messageText = "앱을 시작할 수 없어요"; alert.informativeText = error.localizedDescription; alert.runModal(); NSApp.terminate(nil) }
    }
    private func update() { try? store.tick(); windows.synchronizeMemo(); updates.synchronize() }
    @objc private func woke() { update() }
    @objc private func screenChanged() { windows.screenConfigurationChanged() }
    func applicationDidBecomeActive(_ notification: Notification) { if store != nil { update() } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { windows.showMain(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard store.hasPendingSave else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = "아직 저장하지 못한 기록이 있어요"; alert.informativeText = "종료 전에 저장을 다시 시도해 주세요."
        alert.addButton(withTitle: "돌아가기"); alert.addButton(withTitle: "저장 다시 시도")
        if alert.runModal() == .alertSecondButtonReturn { do { try store.retrySave(); return .terminateNow } catch { windows.showError(error) } }
        return .terminateCancel
    }
    private func installMenu() {
        let menu = NSMenu()
        let app = NSMenuItem(); let submenu = NSMenu()
        submenu.addItem(withTitle: "Pomodoro 정보", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let update = NSMenuItem(title: "업데이트 확인…", action: #selector(checkForUpdates), keyEquivalent: ""); update.target = self; submenu.addItem(update)
        submenu.addItem(.separator())
        let settings = NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ","); settings.target = self; submenu.addItem(settings)
        submenu.addItem(.separator()); submenu.addItem(withTitle: "Pomodoro 가리기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        submenu.addItem(withTitle: "Pomodoro 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        app.submenu = submenu; menu.addItem(app)
        let edit = NSMenuItem(); edit.title = "편집"; let editing = NSMenu(title: "편집")
        for (title, action, key) in [("실행 취소", "undo:", "z"), ("잘라내기", "cut:", "x"), ("복사", "copy:", "c"), ("붙여넣기", "paste:", "v"), ("전체 선택", "selectAll:", "a")] { editing.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        edit.submenu = editing; menu.addItem(edit)
        let window = NSMenuItem(); window.title = "윈도우"; let windowMenu = NSMenu(title: "윈도우")
        let main = NSMenuItem(title: "메인 화면", action: #selector(openMain), keyEquivalent: "1"); main.target = self; windowMenu.addItem(main)
        let floating = NSMenuItem(title: "플로팅 타이머", action: #selector(openFloating), keyEquivalent: "2"); floating.target = self; windowMenu.addItem(floating)
        window.submenu = windowMenu; menu.addItem(window); NSApp.mainMenu = menu
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates) { return updates?.canCheck ?? false }
        return true
    }
    @objc private func checkForUpdates() { updates.checkForUpdates() }
    @objc private func openSettings() { windows.showSettings() }
    @objc private func openMain() { windows.showMain() }
    @objc private func openFloating() { windows.showFloating() }
}
