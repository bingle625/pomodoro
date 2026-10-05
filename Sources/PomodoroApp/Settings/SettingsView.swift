import SwiftUI
import PomodoroCore
struct SettingsView: View {
    let store: AppStore
    let previewBell: () -> Void
    @State private var focus = 25
    @State private var rest = 5
    @State private var sound = true
    @State private var auto = false
    @State private var error: String?
    @State private var saved = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("나의 집중 리듬").font(.system(size: 24, weight: .semibold))
            Text("나에게 맞는 집중과 휴식 시간을 정해 보세요.").font(.system(size: 13)).foregroundStyle(Theme.secondary)
            Card {
                VStack(spacing: 20) {
                    durationRow("집중 시간", value: $focus, color: Theme.focus)
                    Divider()
                    durationRow("휴식 시간", value: $rest, color: Theme.rest)
                }
            }
            Text("1~60분 · 변경한 시간은 다음 세션부터 적용돼요").font(.system(size: 12)).foregroundStyle(Theme.muted)
            Toggle("종료 종소리", isOn: $sound).toggleStyle(.switch)
            Button { previewBell() } label: { Label("종소리 미리 듣기", systemImage: "speaker.wave.2") }.buttonStyle(.borderless)
            Toggle("다음 단계 자동 시작", isOn: $auto).toggleStyle(.switch)
            Text("집중이 끝나면 메모 창이 열려요. 자동 시작을 켜면 메모를 쓰는 동안에도 휴식 시간이 흘러요.").font(.system(size: 12)).foregroundStyle(Theme.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(Theme.error) }
            HStack { if saved { Label("설정을 저장했어요", systemImage: "checkmark").font(.caption).foregroundStyle(Theme.rest) }; Spacer(); Button(store.hasPendingSave ? "저장 다시 시도" : "저장") { save() }.buttonStyle(PrimaryButtonStyle()) }
        }.padding(30).frame(width: 410).background(Theme.background).preferredColorScheme(.light)
            .onAppear { let p = store.snapshot.preferences; focus = p.focusMinutes; rest = p.breakMinutes; sound = p.soundEnabled; auto = p.autoStart }
    }
    private func durationRow(_ title: String, value: Binding<Int>, color: Color) -> some View {
        HStack { Circle().fill(color).frame(width: 8, height: 8); Text(title); Spacer(); TextField(title, value: value, format: .number).accessibilityLabel(title).textFieldStyle(.roundedBorder).frame(width: 48); Text("분").foregroundStyle(Theme.muted); Stepper(title, value: value, in: 1...60).labelsHidden() }
    }
    private func save() {
        do { if store.hasPendingSave { try store.retrySave() }; var p = Preferences(); p.focusMinutes = focus; p.breakMinutes = rest; p.soundEnabled = sound; p.autoStart = auto; try store.updatePreferences(p); error = nil; saved = true } catch { self.error = error.localizedDescription }
    }
}
