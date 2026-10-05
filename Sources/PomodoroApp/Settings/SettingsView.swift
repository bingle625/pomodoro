import SwiftUI
import PomodoroCore
struct SettingsView: View {
    let store: AppStore
    let updates: UpdateCoordinator
    let previewBell: () -> Void
    let draftChanged: (Bool) -> Void
    private var draft: Preferences {
        var p = Preferences(); p.focusMinutes = focus; p.breakMinutes = rest; p.longBreakMinutes = longRest; p.longBreakInterval = longBreakInterval; p.soundEnabled = sound; p.autoStart = auto; p.transparentFloatingBackground = transparent; return p
    }
    @State private var focus = 25
    @State private var rest = 5
    @State private var longRest = 15
    @State private var longBreakInterval = 4
    @State private var sound = true
    @State private var auto = false
    @State private var transparent = false
    @State private var error: String?
    @State private var saved = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            Text("나의 집중 리듬").font(.system(size: 24, weight: .semibold))
            Text("나에게 맞는 집중과 휴식 시간을 정해 보세요.").font(.system(size: 13)).foregroundStyle(Theme.secondary)
            Card {
                VStack(spacing: 20) {
                    durationRow("집중 시간", value: $focus, color: Theme.focus)
                    Divider()
                    durationRow("짧은 휴식 시간", value: $rest, color: Theme.rest)
                    Divider()
                    durationRow("긴 휴식 시간", value: $longRest, color: Theme.rest)
                    Divider()
                    HStack {
                        Circle().fill(Theme.rest).frame(width: 8, height: 8)
                        Text("긴 휴식 주기")
                        Spacer()
                        Text("집중")
                        TextField("긴 휴식 주기", value: $longBreakInterval, format: .number)
                            .accessibilityLabel("긴 휴식 주기").textFieldStyle(.roundedBorder).frame(width: 48)
                        Text("회마다").foregroundStyle(Theme.muted)
                        Stepper("긴 휴식 주기", value: $longBreakInterval, in: 1...12).labelsHidden()
                    }
                }
            }
            Text("시간 1~60분 · 주기 1~12회 · 변경한 설정은 다음 세션부터 적용돼요").font(.system(size: 12)).foregroundStyle(Theme.muted)
            Text("집중을 설정한 횟수만큼 완료하면 긴 휴식으로 전환해요. 중도 종료한 집중은 세지 않아요.").font(.system(size: 12)).foregroundStyle(Theme.secondary)
            Toggle("종료 종소리", isOn: $sound).toggleStyle(.switch)
            Button { previewBell() } label: { Label("종소리 미리 듣기", systemImage: "speaker.wave.2") }.buttonStyle(.borderless)
            Toggle("다음 단계 자동 시작", isOn: $auto).toggleStyle(.switch)
            Text("집중이 끝나면 메모 창이 열려요. 자동 시작을 켜면 메모를 쓰는 동안에도 휴식 시간이 흘러요.").font(.system(size: 12)).foregroundStyle(Theme.secondary)
            Toggle("플로팅 타이머 배경 투명", isOn: $transparent).toggleStyle(.switch)
            Text("저장하면 배경과 창 그림자가 사라지고 타이머와 버튼만 표시돼요.").font(.system(size: 12)).foregroundStyle(Theme.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(Theme.error) }
            HStack { if saved { Label("설정을 저장했어요", systemImage: "checkmark").font(.caption).foregroundStyle(Theme.rest) }; Spacer(); Button(store.hasPendingSave ? "저장 다시 시도" : "저장") { save() }.buttonStyle(PrimaryButtonStyle()) }
            Divider().padding(.top, 4)
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("앱 업데이트").font(.system(size: 16, weight: .semibold)); Spacer(); Text("v\(updates.version)").font(.caption).foregroundStyle(Theme.secondary) }
                Toggle("새 버전 자동 확인", isOn: Binding(get: { updates.automaticallyChecks }, set: { updates.setAutomaticChecking($0) })).toggleStyle(.switch)
                Toggle("자동 다운로드 및 설치", isOn: Binding(get: { updates.automaticallyDownloads }, set: { updates.setAutomaticDownloading($0) })).toggleStyle(.switch).disabled(!updates.automaticallyChecks)
                Text(updates.waitingMessage ?? "새 버전은 자동으로 다운로드합니다. 타이머와 메모가 끝나고 설정 창을 닫으면 설치 후 다시 실행합니다.").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                HStack {
                    if let checked = updates.lastChecked { Text("최근 확인 \(TimeFormatting.date(checked, pattern: "M/d HH:mm"))").font(.caption).foregroundStyle(Theme.muted) }
                    Spacer()
                    Button("지금 확인") { updates.checkForUpdates() }.disabled(!updates.canCheck)
                }
            }
        }.padding(30) }.frame(width: 470, height: 680).background(Theme.background).preferredColorScheme(.light)
            .disabled(store.isUpdating)
            .onChange(of: draft) { _, value in draftChanged(value != store.snapshot.preferences) }
            .onChange(of: store.snapshot.preferences) { _, value in draftChanged(draft != value) }
            .onAppear { let p = store.snapshot.preferences; focus = p.focusMinutes; rest = p.breakMinutes; longRest = p.longBreakMinutes; longBreakInterval = p.longBreakInterval; sound = p.soundEnabled; auto = p.autoStart; transparent = p.transparentFloatingBackground }
    }
    private func durationRow(_ title: String, value: Binding<Int>, color: Color) -> some View {
        HStack { Circle().fill(color).frame(width: 8, height: 8); Text(title); Spacer(); TextField(title, value: value, format: .number).accessibilityLabel(title).textFieldStyle(.roundedBorder).frame(width: 48); Text("분").foregroundStyle(Theme.muted); Stepper(title, value: value, in: 1...60).labelsHidden() }
    }
    private func save() {
        do { if store.hasPendingSave { try store.retrySave() }; try store.updatePreferences(draft); error = nil; saved = true; draftChanged(false) } catch { self.error = error.localizedDescription }
    }
}
