import Foundation
public enum TimeFormatting {
    public static func countdown(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds).rounded(.up)); return String(format: "%02d:%02d", value / 60, value % 60)
    }
    public static func total(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds)) / 60; return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds)) / 60
        return minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분"
    }
    public static func recordMinutes(_ seconds: TimeInterval) -> String { seconds < 60 ? "1분 미만" : "\(Int(seconds) / 60)" }
    public static func dialDegrees(_ seconds: TimeInterval) -> Double { min(360, max(0, seconds / 10)) }
    public static func date(_ date: Date, pattern: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = pattern; return f.string(from: date)
    }
}
