import SwiftUI
import AppKit

struct ScrollWheelHandler: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollView(frame: .zero)
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class ScrollView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func scrollWheel(with event: NSEvent) {
            // Detect vertical scroll for zoom
            if event.deltaY != 0 {
                // Sensitivity factor
                let sensitivity: CGFloat = 0.1
                // Calculate zoom factor: 1.0 + delta * sensitivity
                // e.g. delta = 1.0 -> factor = 1.1
                // e.g. delta = -1.0 -> factor = 0.9
                let zoomFactor = 1.0 + (event.deltaY * sensitivity)
                onScroll?(zoomFactor)
            }
        }
    }
}
