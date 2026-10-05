import SwiftUI
import PomodoroCore
struct MemoView: View {
    let store: AppStore
    let recordID: UUID
    let close: () -> Void
    @State private var draft = ""
    @State private var taskID: UUID?
    @State private var error: String?
    @FocusState private var focused: Bool
    private var record: FocusRecord? { store.snapshot.records.first { $0.id == recordID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Image(systemName: "square.and.pencil").foregroundStyle(Theme.focus); Text("잠깐의 회고").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary) }
            Text("이번 집중 시간에\n무엇을 했나요?").font(.system(size: 25, weight: .semibold)).lineSpacing(4)
            if let record {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("작업", selection: $taskID) {
                        ForEach(store.snapshot.tasks) { task in
                            Text(task.name).tag(Optional(task.id))
                        }
                    }.pickerStyle(.menu)
                        .disabled(store.isReadOnly || store.isUpdating || store.hasPendingSave)
                    Text("저장하면 선택한 작업으로 기록을 옮겨요.")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Text("\(TimeFormatting.duration(record.focusedSeconds)) · \(TimeFormatting.date(record.endedAt, pattern: "M월 d일 HH:mm"))")
                        .font(.system(size: 12)).foregroundStyle(Theme.secondary).lineLimit(2)
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft).font(.system(size: 14)).scrollContentBackground(.hidden).padding(8).focused($focused)
                if draft.isEmpty { Text("예: 알고리즘 두 문제 풀이, 틀린 문제 정리").font(.system(size: 13)).foregroundStyle(Theme.muted).padding(14).allowsHitTesting(false) }
            }.frame(height: 126).background(.white, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
            if store.snapshot.timer.phase != .focus && store.snapshot.timer.status == .running {
                Label("\(store.snapshot.timer.phase.title) 시간이 흐르고 있어요  \(TimeFormatting.countdown(store.remainingSeconds))", systemImage: "leaf").font(.system(size: 12)).foregroundStyle(Theme.rest)
            }
            if let error { Text(error).font(.caption).foregroundStyle(Theme.error) }
            HStack {
                Text("⌘ ↵ 저장").font(.system(size: 11)).foregroundStyle(Theme.muted)
                Spacer()
                Button("건너뛰기") { finish(save: false) }.buttonStyle(.plain).foregroundStyle(Theme.secondary)
                Button(store.hasPendingSave ? "저장 다시 시도" : "저장") { finish(save: true) }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.return, modifiers: .command)
            }
        }.padding(28).frame(width: 420).background(Theme.background).preferredColorScheme(.light)
            .onAppear { draft = record?.memo ?? ""; taskID = record?.taskID; focused = true }
    }
    private func finish(save: Bool) {
        do {
            if store.hasPendingSave { try store.retrySave() }
            if save { try store.saveMemo(recordID: recordID, text: draft, taskID: taskID) } else { try store.skipMemo(recordID: recordID) }
            close()
        } catch { self.error = error.localizedDescription }
    }
}
