import AppKit
import SwiftUI
import PomodoroCore

@MainActor final class MenuBarTimer: NSObject {
    private let store: AppStore
    private let windows: WindowCoordinator
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var lastDisplayKey = ""

    init(store: AppStore, windows: WindowCoordinator) {
        self.store = store
        self.windows = windows
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.contentViewController = NSHostingController(rootView: MenuBarTimerView(
            store: store,
            perform: { [weak self] action in self?.perform(action) },
            openMain: { [weak self] in self?.popover.performClose(nil); self?.windows.showMain() },
            openFloating: { [weak self] in self?.popover.performClose(nil); self?.windows.showFloating() }
        ))
        if let button = item.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleNone
        }
        synchronize()
    }

    func synchronize() {
        let timer = store.snapshot.timer
        let time = TimeFormatting.countdown(store.remainingSeconds)
        let phase = timer.phase.title
        let status = timer.status == .paused ? "일시정지" : timer.status == .ready ? "준비" : "진행 중"
        let key = "\(phase)-\(status)-\(time)"
        guard key != lastDisplayKey else { return }
        lastDisplayKey = key
        item.button?.title = " \(time)"
        item.button?.image = dialImage(seconds: store.remainingSeconds, phase: timer.phase, paused: timer.status == .paused)
        item.button?.toolTip = "\(phase) · \(status) · \(time) — 클릭하여 타이머 열기"
        item.button?.setAccessibilityLabel("Pomodoro \(phase), \(status), 남은 시간 \(time)")
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button = item.button else { return }
        try? store.tick()
        synchronize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func perform(_ action: () throws -> Void) {
        do { try action(); windows.synchronizeMemo(); synchronize() }
        catch { popover.performClose(nil); windows.showMain(); windows.showError(error) }
    }

    private func dialImage(seconds: TimeInterval, phase: TimerPhase, paused: Bool) -> NSImage {
        let degrees = TimeFormatting.dialDegrees(seconds)
        let color = phase == .focus ? NSColor(srgbRed: 0.85, green: 0.18, blue: 0.18, alpha: 1) : NSColor(srgbRed: 0.16, green: 0.48, blue: 0.38, alpha: 1)
        return NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 18, height: 18)).fill()
            NSColor.black.withAlphaComponent(0.2).setStroke()
            NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 18, height: 18)).stroke()
            color.setFill()
            if degrees >= 360 {
                NSBezierPath(ovalIn: NSRect(x: 4, y: 4, width: 12, height: 12)).fill()
            } else if degrees > 0 {
                let sector = NSBezierPath()
                sector.move(to: NSPoint(x: 10, y: 10))
                sector.line(to: NSPoint(x: 10, y: 16))
                sector.appendArc(withCenter: NSPoint(x: 10, y: 10), radius: 6, startAngle: 90, endAngle: 90 - degrees, clockwise: true)
                sector.close(); sector.fill()
            }
            if paused {
                NSColor.labelColor.setFill()
                NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 6)).fill()
                NSBezierPath(rect: NSRect(x: 3, y: 0, width: 2, height: 6)).fill()
            }
            return true
        }
    }
}
