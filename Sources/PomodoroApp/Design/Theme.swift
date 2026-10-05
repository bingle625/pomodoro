import SwiftUI
import PomodoroCore
extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xD90025
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}
enum Theme {
    static let background = Color(hex: "F5F3FC")
    static let surface = Color.white
    static let hover = Color(hex: "F0EDF7")
    static let focus = Color(hex: "D90025")
    static let dial = Color(hex: "D92D2D")
    static let rest = Color(hex: "287A60")
    static let text = Color(hex: "29282D")
    static let secondary = Color(hex: "625F6B")
    static let muted = Color(hex: "76717F")
    static let border = Color(hex: "E4E0EB")
    static let error = Color(hex: "B42318")
    static func accent(_ phase: TimerPhase) -> Color { phase == .focus ? focus : rest }
}
