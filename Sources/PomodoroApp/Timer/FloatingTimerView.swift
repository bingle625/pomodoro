import SwiftUI
import PomodoroCore
struct FloatingTimerView: View {
    let store: AppStore
    let windows: WindowCoordinator
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(symbol: "xmark", label: "플로팅 창 닫기") { windows.hideFloating() }
                Spacer()
                Text(store.snapshot.timer.status == .paused ? "일시정지" : store.snapshot.timer.phase == .focus ? "집중" : "휴식").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent(store.snapshot.timer.phase))
                    .frame(maxWidth: .infinity).frame(height: 32)
                    .overlay { WindowDragSurface().accessibilityHidden(true) }
                Spacer()
                IconButton(symbol: "arrow.up.left.and.arrow.down.right", label: "메인 화면") { windows.showMain() }
            }.padding(.horizontal, 12).padding(.top, 8)
            TimerDial(remainingSeconds: store.remainingSeconds, phase: store.snapshot.timer.phase).frame(width: 290, height: 270)
                .overlay { WindowDragSurface().accessibilityHidden(true) }
                .help("드래그하여 타이머 이동")
            HStack(spacing: 18) {
                Text(TimeFormatting.countdown(store.remainingSeconds)).font(.system(size: 25, weight: .semibold)).monospacedDigit()
                IconButton(symbol: store.snapshot.timer.status == .running ? "pause.fill" : "play.fill", label: store.snapshot.timer.status == .running ? "일시정지" : "시작", tint: Theme.accent(store.snapshot.timer.phase)) {
                    do { switch store.snapshot.timer.status { case .ready: try store.start(); case .running: try store.pause(); case .paused: try store.resume() } } catch { windows.showMain() }
                }.disabled(store.isReadOnly || store.hasPendingSave)
            }.padding(.bottom, 16)
        }.frame(width: 320, height: 360).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.light).disabled(store.isUpdating)
    }
}
