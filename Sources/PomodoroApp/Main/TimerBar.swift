import SwiftUI
import PomodoroCore
struct TimerBar: View {
    let store: AppStore
    let openFloating: () -> Void
    var body: some View {
        HStack(spacing: 18) {
            IconButton(symbol: store.snapshot.timer.status == .running ? "pause.fill" : "play.fill", label: store.snapshot.timer.status == .running ? "일시정지" : "시작", tint: Theme.text) {
                perform { switch store.snapshot.timer.status { case .ready: try store.start(); case .running: try store.pause(); case .paused: try store.resume() } }
            }
            IconButton(symbol: "stop.fill", label: "종료", tint: Theme.muted) { perform { try store.stop() } }.disabled(store.snapshot.timer.status == .ready && store.snapshot.timer.phase == .focus && store.snapshot.timer.completedFocusCount == 0)
            Rectangle().fill(Theme.border).frame(width: 1, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.snapshot.timer.phase.title).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.accent(store.snapshot.timer.phase))
                Text(TimeFormatting.countdown(store.remainingSeconds)).font(.system(size: 21, weight: .semibold)).monospacedDigit()
            }.frame(width: 80, alignment: .leading)
            ProgressView(value: store.remainingSeconds, total: store.snapshot.timer.durationSeconds).tint(Theme.accent(store.snapshot.timer.phase)).frame(width: 110)
            IconButton(symbol: "pip.enter", label: "플로팅 타이머", action: openFloating)
        }.padding(.horizontal, 18).padding(.vertical, 9)
            .background(.white.opacity(0.9), in: Capsule()).overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            .disabled(store.isReadOnly || store.hasPendingSave)
    }
    private func perform(_ action: () throws -> Void) { do { try action() } catch { /* Persistent errors appear in MainView. */ } }
}
