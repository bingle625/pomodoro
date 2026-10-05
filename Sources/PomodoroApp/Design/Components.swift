import SwiftUI
struct Card<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.035), radius: 16, y: 4)
    }
}
struct IconButton: View {
    let symbol: String
    let label: String
    var tint: Color = Theme.secondary
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(width: 32, height: 32) }
            .buttonStyle(.plain).foregroundStyle(tint).help(label).accessibilityLabel(label)
    }
}
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.focus
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .semibold)).padding(.horizontal, 18).frame(height: 36)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.white)
    }
}
struct EmptyState: View {
    var title = "아직 집중 기록이 없어요"
    var message = "집중을 시작하면 시간과 메모가 여기에 쌓여요"
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf").font(.system(size: 28, weight: .light)).foregroundStyle(Theme.muted)
            Text(title).font(.system(size: 16, weight: .semibold))
            Text(message).font(.system(size: 13)).foregroundStyle(Theme.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 45)
    }
}
