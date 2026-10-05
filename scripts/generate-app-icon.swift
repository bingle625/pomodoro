#!/usr/bin/env swift
import AppKit

// Geometric artwork drawn at each output resolution for crisp Dock/Finder icons.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Packaging/AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}
func render(pixels: Int, url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 186, yRadius: 186)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(245, 243, 252).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: .white, ending: color(236, 231, 249))!.draw(in: tile, angle: -90)
    let center = NSPoint(x: 512, y: 512)
    let radius: CGFloat = 244
    color(226, 219, 237).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
    let wedge = NSBezierPath()
    wedge.move(to: center)
    wedge.line(to: NSPoint(x: 512, y: 512 + radius))
    wedge.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -60, clockwise: true)
    wedge.close()
    NSGradient(starting: color(239, 57, 64), ending: color(217, 0, 37))!.draw(in: wedge, angle: -90)
    // Minor ticks are omitted at the smallest sizes to keep the silhouette clean.
    for tick in 0..<60 where pixels >= 64 || tick % 5 == 0 {
        let major = tick % 5 == 0
        let angle = CGFloat(tick) * .pi / 30
        let inner: CGFloat = major ? 283 : 295
        let outer: CGFloat = 316
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 512 + sin(angle) * inner, y: 512 + cos(angle) * inner))
        path.line(to: NSPoint(x: 512 + sin(angle) * outer, y: 512 + cos(angle) * outer))
        path.lineWidth = major ? 13 : 6
        path.lineCapStyle = .round
        (major ? color(217, 0, 37) : color(207, 166, 184)).setStroke()
        path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
for size in [16, 32, 128, 256, 512] {
    try render(pixels: size, url: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(pixels: size * 2, url: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
print(output.path)
