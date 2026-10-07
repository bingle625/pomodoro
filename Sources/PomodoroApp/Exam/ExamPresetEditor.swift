import SwiftUI
import PomodoroCore

/// Create or edit a saved exam set: a name plus an ordered list of 이름·분 sections.
struct ExamPresetEditor: View {
    let store: AppStore
    let preset: ExamPreset?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var sections: [ExamSection]
    @State private var error: String?

    init(store: AppStore, preset: ExamPreset?) {
        self.store = store; self.preset = preset
        _name = State(initialValue: preset?.name ?? "")
        _sections = State(initialValue: preset?.sections ?? [ExamSection(name: "", minutes: 20)])
    }

    private var totalMinutes: Int { sections.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(preset == nil ? "시험 세트 추가" : "시험 세트 수정").font(.system(size: 18, weight: .semibold))
            TextField("세트 이름 (예: 현대자동차그룹 온라인 HMAT)", text: $name)
                .textFieldStyle(.roundedBorder).font(.system(size: 14))

            HStack {
                Text("영역").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted)
                Spacer()
                Text("제한시간(분)").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted)
            }.padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($sections) { $section in sectionRow($section) }
                }
            }.frame(maxHeight: 300)

            Button { sections.append(ExamSection(name: "", minutes: 10)) } label: { Label("구간 추가", systemImage: "plus") }
                .buttonStyle(.plain).foregroundStyle(Theme.focus).font(.system(size: 13, weight: .medium))
                .disabled(sections.count >= 20)

            HStack {
                Text("총 \(TimeFormatting.duration(Double(totalMinutes) * 60))").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
                Spacer()
                Button("취소") { dismiss() }.buttonStyle(.plain).foregroundStyle(Theme.muted).font(.system(size: 14))
                Button("저장") { save() }.buttonStyle(PrimaryButtonStyle())
            }
            if let error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.error) }
        }
        .padding(24).frame(width: 440).background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.light)
    }

    private func sectionRow(_ section: Binding<ExamSection>) -> some View {
        HStack(spacing: 10) {
            TextField("영역 이름", text: section.name).textFieldStyle(.roundedBorder).font(.system(size: 14))
            TextField("분", value: section.minutes, format: .number).textFieldStyle(.roundedBorder)
                .frame(width: 56).multilineTextAlignment(.center).monospacedDigit()
            Stepper("", value: section.minutes, in: 1...180).labelsHidden()
            IconButton(symbol: "minus.circle", label: "구간 삭제", tint: Theme.muted) {
                sections.removeAll { $0.id == section.wrappedValue.id }
            }.disabled(sections.count <= 1)
        }
    }

    private func save() {
        do {
            if let preset { try store.updateExamPreset(id: preset.id, name: name, sections: sections) }
            else { try store.addExamPreset(name: name, sections: sections) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
