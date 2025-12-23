import SwiftUI
import AppKit

/// A SwiftUI wrapper around an NSView to handle scroll wheel events.
/// SwiftUI's native `.onScroll` or gesture modifiers don't always provide precise delta values needed for zooming.
///
/// 一个 NSView 的 SwiftUI 包装器，用于处理滚轮事件。
/// SwiftUI 的原生 .onScroll 或手势修饰符并不总是提供缩放所需的精确增量值。
struct ScrollWheelHandler: NSViewRepresentable {
    /// Callback closure triggered on scroll events.
    /// Passes the calculated zoom factor.
    ///
    /// 滚动事件触发的回调闭包。
    /// 传递计算出的缩放因子。
    var onScroll: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollView(frame: .zero)
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed for now.
        // 目前不需要更新。
    }
    
    /// Internal NSView subclass to override event handling.
    ///
    /// 内部 NSView 子类，用于重写事件处理。
    class ScrollView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        
        // Accept first responder status to receive key events (if needed).
        // 接受第一响应者状态以接收按键事件（如果需要）。
        override var acceptsFirstResponder: Bool { true }
        
        override func scrollWheel(with event: NSEvent) {
            // Detect vertical scroll for zoom.
            // 检测垂直滚动以进行缩放。
            if event.deltaY != 0 {
                // Sensitivity factor to control zoom speed.
                // 控制缩放速度的灵敏度因子。
                let sensitivity: CGFloat = 0.1
                
                // Calculate zoom factor: 1.0 + delta * sensitivity.
                // e.g. delta = 1.0 -> factor = 1.1 (Zoom In)
                // e.g. delta = -1.0 -> factor = 0.9 (Zoom Out)
                //
                // 计算缩放因子：1.0 + delta * sensitivity。
                // 例如 delta = 1.0 -> factor = 1.1（放大）
                // 例如 delta = -1.0 -> factor = 0.9（缩小）
                let zoomFactor = 1.0 + (event.deltaY * sensitivity)
                onScroll?(zoomFactor)
            }
        }
    }
}
