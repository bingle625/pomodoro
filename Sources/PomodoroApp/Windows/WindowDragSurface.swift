import AppKit
import SwiftUI

/// Explicit drag region: SwiftUI's hosting view does not reliably forward
/// background mouse-downs to a borderless panel's automatic dragging.
struct WindowDragSurface: NSViewRepresentable {
    func makeNSView(context: Context) -> DragSurfaceView { DragSurfaceView() }
    func updateNSView(_ nsView: DragSurfaceView, context: Context) {}
}
final class DragSurfaceView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}
