import SwiftUI
import PomodoroCore

struct AdjustableTimerDial: View {
    let store: AppStore
    let perform: (() throws -> Void) -> Void
    @Binding var previewMinutes: Int?
    @GestureState private var dragging = false
    @State private var editingSession: UUID?
    private var enabled: Bool {
        store.snapshot.timer.status != .running && !store.isReadOnly && !store.hasPendingSave && !store.isUpdating && store.maximumAdjustableMinutes > 0
    }
    private var seconds: Double { previewMinutes.map { Double($0 * 60) } ?? store.remainingSeconds }
    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) * 0.335
            let angle = TimeFormatting.dialDegrees(seconds) * .pi / 180 - .pi / 2
            ZStack {
                TimerDial(remainingSeconds: seconds, phase: store.snapshot.timer.phase)
                if enabled {
                    Circle().fill(.white).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Theme.accent(store.snapshot.timer.phase), lineWidth: 3))
                        .position(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                }
            }.contentShape(Circle())
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($dragging) { _, active, _ in active = true }
                    .onChanged { value in
                        guard enabled else { return }
                        if editingSession == nil {
                            // Start only from the handle; angle wrapping is continuous from here.
                            let handle = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                            guard hypot(value.startLocation.x - handle.x, value.startLocation.y - handle.y) <= 24 else { return }
                            editingSession = store.snapshot.timer.sessionID
                        }
                        guard editingSession == store.snapshot.timer.sessionID else { return }
                        let previous = previewMinutes ?? min(60, max(1, Int((store.remainingSeconds / 60).rounded())))
                        previewMinutes = min(store.maximumAdjustableMinutes, TimerDialAdjustment.minutes(x: value.location.x - center.x, y: value.location.y - center.y, previous: previous))
                    }
                    .onEnded { _ in
                        defer { previewMinutes = nil; editingSession = nil }
                        guard enabled, editingSession == store.snapshot.timer.sessionID, let minutes = previewMinutes else { return }
                        perform { try store.adjustRemainingMinutes(minutes) }
                    })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("남은 시간 조절")
                .accessibilityValue(TimeFormatting.countdown(seconds))
                .accessibilityHint(enabled ? "위아래로 조절하여 분을 변경합니다" : "일시정지 후 조절할 수 있습니다")
                .accessibilityAdjustableAction { direction in
                    guard enabled else { return }
                    let current = Int((store.remainingSeconds / 60).rounded())
                    let next = min(store.maximumAdjustableMinutes, max(1, current + (direction == .increment ? 1 : -1)))
                    perform { try store.adjustRemainingMinutes(next) }
                }
        }
        .onChange(of: dragging) { _, active in if !active { previewMinutes = nil; editingSession = nil } }
        .onChange(of: store.snapshot.timer.status) { _, _ in previewMinutes = nil; editingSession = nil }
        .onDisappear { previewMinutes = nil; editingSession = nil }
        .help(enabled ? "손잡이를 드래그하여 남은 시간 조절 · 1~\(store.maximumAdjustableMinutes)분" : "일시정지하면 시간을 조절할 수 있어요")
    }
}
