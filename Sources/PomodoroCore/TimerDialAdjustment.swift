import Foundation

public enum TimerDialAdjustment {
    /// Coordinates relative to the dial center; positive y points down.
    public static func minutes(x: Double, y: Double, previous: Int) -> Int {
        guard hypot(x, y) >= 12 else { return previous }
        var angle = atan2(x, -y) * 180 / .pi
        if angle < 0 { angle += 360 }
        var delta = angle - Double(previous) * 6
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return min(60, max(1, Int((Double(previous) + delta / 6).rounded())))
    }
}
