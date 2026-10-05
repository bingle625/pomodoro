import SwiftUI
import PomodoroCore

struct MenuBarTimerView: View {
    let store: AppStore
    let perform: (() throws -> Void) -> Void
    let openMain: () -> Void
    let openFloating: () -> Void
    @State private var previewMinutes: Int?
    private var accent: Color { Theme.accent(store.snapshot.timer.phase) }
    private var timer: TimerState { store.snapshot.timer }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(timer.phase.title).font(.headline).foregroundStyle(accent)
                Spacer()
                Text(timer.status == .paused ? "일시정지 · 손잡이로 시간 조절" : timer.status == .running ? "진행 중" : "손잡이를 드래그해 시간 조절")
                    .font(.caption).foregroundStyle(Theme.secondary)
            }
            Picker("작업", selection: Binding(
                get: { store.snapshot.selectedTaskID },
                set: { id in perform { try store.selectTask(id) } }
            )) {
                ForEach(store.snapshot.tasks) { task in
                    Text(task.name).tag(task.id)
                }
            }.pickerStyle(.menu)
                .disabled(timer.status != .ready || store.isReadOnly || store.hasPendingSave || store.isUpdating)
                .help(timer.status == .ready ? "집중할 작업을 선택하세요" : "작업을 변경하려면 타이머를 종료해 주세요")
            AdjustableTimerDial(store: store, perform: perform, previewMinutes: $previewMinutes)
                .frame(width: 280, height: 260)
            HStack(spacing: 16) {
                Text(TimeFormatting.countdown(previewMinutes.map { Double($0 * 60) } ?? store.remainingSeconds))
                    .font(.system(size: 32, weight: .semibold)).monospacedDigit().foregroundStyle(accent)
                Spacer()
                IconButton(symbol: timer.status == .running ? "pause.fill" : "play.fill", label: timer.status == .running ? "일시정지" : timer.status == .paused ? "재개" : "시작", tint: accent) {
                    perform {
                        switch timer.status {
                        case .ready: try store.start()
                        case .running: try store.pause()
                        case .paused: try store.resume()
                        }
                    }
                }
                IconButton(symbol: "stop.fill", label: "타이머 종료", tint: accent) {
                    perform { try store.stop() }
                }.disabled(timer.status == .ready)
            }.disabled(store.isReadOnly || store.hasPendingSave || store.isUpdating)
            HStack {
                Text("현재 \(TimeFormatting.date(store.currentDate, pattern: "HH:mm"))")
                Spacer()
                if let deadline = timer.deadline, timer.status == .running {
                    Text("종료 \(TimeFormatting.date(deadline, pattern: "HH:mm"))")
                } else {
                    Text(timer.status == .paused ? "재개하면 종료 시각을 표시해요" : "시작하면 종료 시각을 표시해요")
                }
            }.font(.system(size: 11)).foregroundStyle(Theme.secondary)
            Divider()
            HStack {
                Button("메인 화면", action: openMain)
                Spacer()
                Button("플로팅 타이머", action: openFloating)
            }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.secondary)
        }.padding(20).frame(width: 320, height: 500).background(Theme.background).preferredColorScheme(.light)
    }
}
