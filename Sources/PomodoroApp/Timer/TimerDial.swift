import SwiftUI
import PomodoroCore
struct TimerDial: View {
    let remainingSeconds: TimeInterval
    let phase: TimerPhase
    private var color: Color { phase == .focus ? Theme.dial : Theme.rest }
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = side * 0.335
            let degrees = TimeFormatting.dialDegrees(remainingSeconds)
            ZStack {
                Path { path in
                    guard degrees > 0 else { return }
                    if degrees >= 360 { path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)) }
                    else {
                        path.move(to: center)
                        path.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(degrees - 90), clockwise: false)
                        path.closeSubpath()
                    }
                }.fill(color)
                ForEach(0..<60, id: \.self) { index in
                    let angle = Double(index) * .pi / 30 - .pi / 2
                    let major = index % 5 == 0
                    Path { path in
                        let inside = radius + 5.0, outside = radius + (major ? 21.0 : 13.0)
                        path.move(to: CGPoint(x: center.x + cos(angle) * inside, y: center.y + sin(angle) * inside))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * outside, y: center.y + sin(angle) * outside))
                    }.stroke(color.opacity(major ? 1 : 0.28), style: StrokeStyle(lineWidth: major ? 1.8 : 1.4, lineCap: .round))
                    if major {
                        Text("\(index)").font(.system(size: side * 0.045, weight: .semibold)).foregroundStyle(color)
                            .position(x: center.x + cos(angle) * (radius + 36), y: center.y + sin(angle) * (radius + 36))
                    }
                }
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(phase.title) 타이머").accessibilityValue(TimeFormatting.countdown(remainingSeconds))
    }
}
