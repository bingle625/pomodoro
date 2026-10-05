import SwiftUI
import PomodoroCore
struct TaskEditor: View {
    let store: AppStore
    var task: FocusTask?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color = "D90025"
    @State private var error: String?
    private let colors = ["D90025", "287A60", "6366F1", "C47C24", "3179A5", "A24886"]
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(task == nil ? "새로운 집중" : "작업 수정").font(.title2.bold())
            TextField("어떤 일에 집중할까요?", text: $name).textFieldStyle(.roundedBorder).onSubmit(save)
            HStack(spacing: 14) { ForEach(colors, id: \.self) { hex in
                Button { color = hex } label: { Circle().fill(Color(hex: hex)).frame(width: 24, height: 24).padding(4).overlay(Circle().stroke(color == hex ? Theme.text : .clear, lineWidth: 1.5)) }.buttonStyle(.plain).accessibilityLabel("색상 \(hex)")
            } }
            if let error { Text(error).foregroundStyle(Theme.error).font(.caption) }
            HStack { Spacer(); Button("취소") { dismiss() }; Button(store.hasPendingSave ? "저장 다시 시도" : "저장", action: save).buttonStyle(PrimaryButtonStyle()) }
        }.padding(28).frame(width: 370).onAppear { name = task?.name ?? ""; color = task?.colorHex ?? "D90025" }
    }
    private func save() {
        do { if store.hasPendingSave { try store.retrySave(); dismiss(); return }; if let task { try store.updateTask(id: task.id, name: name, colorHex: color) } else { try store.addTask(name: name, colorHex: color) }; dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
