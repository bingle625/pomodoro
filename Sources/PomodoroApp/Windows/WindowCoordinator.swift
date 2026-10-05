import AppKit
import SwiftUI
import PomodoroCore

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
@MainActor final class WindowCoordinator: NSObject, NSWindowDelegate {
    let store: AppStore
    let bell: BellPlayer
    private var mainWindow: NSWindow?
    private var floating: NSPanel?
    private var memoWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var currentMemoID: UUID?
    init(store: AppStore, bell: BellPlayer) { self.store = store; self.bell = bell }
    func showMain() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Pomodoro"; window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: MainView(store: store, windows: self))
            window.minSize = NSSize(width: 760, height: 600); window.isReleasedWhenClosed = false; window.center()
            window.setFrameAutosaveName("PomodoroMain"); mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
    }
    func showFloating() {
        if floating == nil {
            let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 360), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = true; panel.hasShadow = true
            panel.backgroundColor = .clear; panel.isOpaque = false
            let root = FloatingTimerView(store: store, windows: self).clipShape(RoundedRectangle(cornerRadius: 24))
            panel.contentView = NSHostingView(rootView: root); panel.isReleasedWhenClosed = false
            panel.center(); panel.setFrameAutosaveName("PomodoroFloating"); floating = panel
        }
        if let panel = floating { keepVisible(panel); panel.orderFrontRegardless() }
    }
    func hideFloating() { floating?.orderOut(nil) }
    func screenConfigurationChanged() { if let floating { keepVisible(floating) } }
    private func keepVisible(_ window: NSWindow) {
        let screens = NSScreen.screens
        let screen = screens.first { $0.visibleFrame.intersects(window.frame) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        var origin = window.frame.origin
        origin.x = max(frame.minX, min(origin.x, frame.maxX - window.frame.width))
        origin.y = max(frame.minY, min(origin.y, frame.maxY - window.frame.height))
        window.setFrameOrigin(origin)
    }
    func synchronizeMemo() {
        guard memoWindow == nil, let id = store.memoSessionID else { return }
        showMemo(recordID: id)
    }
    func showMemo(recordID: UUID) {
        guard memoWindow == nil else { memoWindow?.makeKeyAndOrderFront(nil); return }
        currentMemoID = recordID
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 476, height: 420), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "집중 기록"; window.titlebarAppearsTransparent = true; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MemoView(store: store, recordID: recordID) { [weak self] in self?.finishMemo() })
        window.level = .floating; window.delegate = self; window.center(); memoWindow = window
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
    private func finishMemo() {
        memoWindow?.delegate = nil; memoWindow?.close(); memoWindow = nil; currentMemoID = nil
        synchronizeMemo()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === memoWindow, let id = currentMemoID else { return true }
        do { try store.skipMemo(recordID: id); finishMemo(); return false }
        catch { showError(error); return false }
    }
    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 530), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "설정"; window.titlebarAppearsTransparent = true; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store) { [weak self] in self?.playBell() })
            window.center(); settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func playBell() { do { try bell.play() } catch { showError(error) } }
    func showError(_ error: Error) { let alert = NSAlert(); alert.messageText = "확인해 주세요"; alert.informativeText = error.localizedDescription; alert.runModal() }
}
