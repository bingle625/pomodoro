import SwiftUI
import PomodoroCore
struct MainView: View {
    let store: AppStore
    let windows: WindowCoordinator
    @State private var tab = "요약"
    @State private var editor = false
    @State private var editingTask: FocusTask?
    @State private var deleting = false
    @State private var error: String?
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.border).frame(width: 1)
            VStack(spacing: 0) {
                if store.isUpdating {
                    Label("업데이트를 설치하고 있어요. 잠시 후 다시 실행합니다.", systemImage: "arrow.triangle.2.circlepath").font(.callout).padding(14)
                }
                if let message = windows.updates.waitingMessage, !store.isUpdating {
                    Label(message, systemImage: "arrow.down.circle").font(.callout).padding(14)
                }
                if let storageError = store.storageError {
                    HStack { Image(systemName: "exclamationmark.triangle"); Text(storageError).font(.caption).textSelection(.enabled); Spacer(); Button("다시 시도") { attempt { try store.retrySave() } } }
                        .padding(16).background(Theme.error.opacity(0.08)).foregroundStyle(Theme.error)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        HStack(spacing: 24) { ForEach(["요약", "회고", "시험"], id: \.self) { value in
                            Button { tab = value } label: {
                                VStack(spacing: 8) { Text(value).font(.system(size: 16, weight: .semibold)); Capsule().fill(tab == value ? Theme.text : .clear).frame(height: 2) }.fixedSize(horizontal: true, vertical: false)
                            }.buttonStyle(.plain).foregroundStyle(tab == value ? Theme.text : Theme.muted)
                        } }
                        if tab == "요약" { SummaryView(store: store) }
                        else if tab == "회고" { ReviewView(store: store) { windows.showMemo(recordID: $0) } }
                        else { ExamView(store: store) }
                    }.frame(maxWidth: 1120).padding(28).frame(maxWidth: .infinity)
                }
                TimerBar(store: store) { windows.showFloating() }.padding(.bottom, 22).padding(.top, 12)
            }
        }.background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.light)
            .frame(minWidth: 760, minHeight: 600).disabled(store.isUpdating)
            .sheet(isPresented: $editor) { TaskEditor(store: store, task: editingTask) }
            .alert("작업을 삭제할까요?", isPresented: $deleting) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) { attempt { try store.deleteTask(id: store.snapshot.selectedTaskID) } }
            } message: { Text("이 작업의 집중 기록 \(store.snapshot.records.filter { $0.taskID == store.snapshot.selectedTaskID }.count)개와 메모도 함께 삭제됩니다.") }
            .alert("확인해 주세요", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인") { error = nil } } message: { Text(error ?? "") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 9) { Image(systemName: "circle.lefthalf.filled").foregroundStyle(Theme.focus); Text("pomodoro").font(.system(size: 17, weight: .semibold, design: .rounded)) }.padding(.top, 16).padding(.horizontal, 18)
            Text("나의 작업").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted).padding(.horizontal, 20).padding(.top, 16)
            ScrollView {
                VStack(spacing: 4) { ForEach(store.snapshot.tasks) { task in
                    Button { attempt { try store.selectTask(task.id) } } label: {
                        HStack(spacing: 10) { Circle().fill(Color(hex: task.colorHex)).frame(width: 7, height: 7); Text(task.name).font(.system(size: 13, weight: task.id == store.snapshot.selectedTaskID ? .semibold : .regular)).lineLimit(2); Spacer(minLength: 0) }
                            .padding(.horizontal, 12).padding(.vertical, 12).background(task.id == store.snapshot.selectedTaskID ? Theme.hover : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                } }.padding(.horizontal, 8)
            }
            HStack { IconButton(symbol: "plus", label: "작업 추가") { editingTask = nil; editor = true }; Spacer(); IconButton(symbol: "gearshape", label: "설정") { windows.showSettings() } }.padding(14)
        }.frame(width: 190).background(.white.opacity(0.55))
    }
    private var header: some View {
        Card {
            HStack(spacing: 13) {
                Circle().fill(Color(hex: store.selectedTask.colorHex)).frame(width: 12, height: 12)
                Text(store.selectedTask.name).font(.system(size: 21, weight: .semibold)).lineLimit(2)
                Spacer()
                IconButton(symbol: "square.and.pencil", label: "작업 수정") { editingTask = store.selectedTask; editor = true }
                IconButton(symbol: "gearshape", label: "시간 설정") { windows.showSettings() }
                IconButton(symbol: "trash", label: "작업 삭제", tint: Theme.muted) { deleting = true }.disabled(store.snapshot.tasks.count == 1)
            }
        }
    }
    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}
