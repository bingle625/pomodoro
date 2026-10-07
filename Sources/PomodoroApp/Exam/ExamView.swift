import SwiftUI
import PomodoroCore

/// 시험 모드 — run a saved set of sections back-to-back, each with its own limit.
struct ExamView: View {
    let store: AppStore
    @State private var editing: ExamPreset?
    @State private var showEditor = false
    @State private var deleting: ExamPreset?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if store.isExamActive { running } else { presetList }
        }
        .sheet(isPresented: $showEditor) { ExamPresetEditor(store: store, preset: editing) }
        .alert("시험 세트를 삭제할까요?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) { if let preset = deleting { attempt { try store.deleteExamPreset(id: preset.id) } } }
        } message: { Text("‘\(deleting?.name ?? "")’ 세트가 삭제됩니다.") }
        .alert("확인해 주세요", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인") { error = nil } } message: { Text(error ?? "") }
    }

    // MARK: Running

    private var running: some View {
        let timer = store.snapshot.examTimer
        let total = timer.sections.count
        let index = timer.currentIndex
        return VStack(alignment: .leading, spacing: 18) {
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(timer.presetName).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text("구간 \(index + 1) / \(total)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary)
                    }
                    Text(store.currentExamSection?.name ?? "").font(.system(size: 26, weight: .bold)).lineLimit(1)
                    Text(TimeFormatting.countdown(store.examRemainingSeconds)).font(.system(size: 54, weight: .semibold)).monospacedDigit()
                    ProgressView(value: store.examRemainingSeconds, total: max(1, timer.durationSeconds)).tint(Theme.focus)
                    HStack(spacing: 10) {
                        Button(timer.status == .running ? "일시정지" : "재개") {
                            attempt { timer.status == .running ? try store.pauseExam() : try store.resumeExam() }
                        }.buttonStyle(PrimaryButtonStyle(color: timer.status == .running ? Theme.secondary : Theme.focus))
                        Button("종료") { attempt { try store.stopExam() } }.buttonStyle(PrimaryButtonStyle(color: Theme.muted))
                    }
                }
            }
            Card {
                VStack(spacing: 0) {
                    ForEach(Array(timer.sections.enumerated()), id: \.element.id) { offset, section in
                        HStack(spacing: 12) {
                            Image(systemName: offset < index ? "checkmark.circle.fill" : offset == index ? "timer" : "circle")
                                .foregroundStyle(offset < index ? Theme.rest : offset == index ? Theme.focus : Theme.muted)
                            Text(section.name).font(.system(size: 14, weight: offset == index ? .semibold : .regular))
                                .foregroundStyle(offset == index ? Theme.text : Theme.secondary)
                            Spacer()
                            Text("\(section.minutes)분").font(.system(size: 13)).foregroundStyle(Theme.muted).monospacedDigit()
                        }.padding(.vertical, 9)
                        if offset < total - 1 { Divider().overlay(Theme.border) }
                    }
                }
            }
        }
    }

    // MARK: Preset list

    private var presetList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("시험 세트").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { editing = nil; showEditor = true } label: { Label("세트 추가", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
            }
            if store.snapshot.examPresets.isEmpty {
                EmptyState(title: "시험 세트가 없어요", message: "영역별 제한시간을 나눈 세트를 만들어 순서대로 타이머를 돌려요")
            } else {
                ForEach(store.snapshot.examPresets) { preset in presetCard(preset) }
            }
        }
    }

    private func presetCard(_ preset: ExamPreset) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preset.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                        Text("\(preset.sections.count)개 구간 · 총 \(TimeFormatting.duration(Double(preset.totalMinutes) * 60))").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    IconButton(symbol: "square.and.pencil", label: "세트 수정") { editing = preset; showEditor = true }
                    IconButton(symbol: "trash", label: "세트 삭제", tint: Theme.muted) { deleting = preset }
                }
                FlowChips(sections: preset.sections)
                Button("시작") { attempt { try store.startExam(presetID: preset.id) } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(preset.sections.isEmpty)
            }
        }
    }

    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

/// Wrapping row of section chips (이름·분).
private struct FlowChips: View {
    let sections: [ExamSection]
    var body: some View {
        FlexibleStack(sections) { section in
            HStack(spacing: 5) {
                Text(section.name).font(.system(size: 12, weight: .medium))
                Text("\(section.minutes)분").font(.system(size: 12)).foregroundStyle(Theme.muted).monospacedDigit()
            }.padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.hover, in: Capsule())
        }
    }
}

/// Minimal wrapping layout so section chips flow onto new lines.
private struct FlexibleStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) { self.data = data; self.content = content }
    var body: some View {
        Flow(spacing: 6) { ForEach(data) { content($0) } }
    }
}

/// Simple flow layout wrapping subviews horizontally.
private struct Flow: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
    }
}
