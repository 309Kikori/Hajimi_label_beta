//
//  OverviewView.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

// MARK: - Resize Handle
// MARK: - 调整手柄

/// A visual handle for resizing items in the overview.
///
/// 概览中用于调整项目大小的视觉手柄。
struct ResizeHandle: View {
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .shadow(radius: 2)
    }
}

// MARK: - Window Accessor & Event Monitor
// MARK: - 窗口访问器与事件监视器

/// A bridge to access the underlying NSWindow and monitor global events.
/// This is necessary because SwiftUI's native gesture handling can be limited for complex interactions like global panning with the middle mouse button.
///
/// 访问底层 NSWindow 并监视全局事件的桥梁。
/// 这是必要的，因为 SwiftUI 的原生手势处理对于像使用鼠标中键进行全局平移这样的复杂交互可能受到限制。
struct WindowAccessor: NSViewRepresentable {
    @ObservedObject var viewModel: OverviewViewModel
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.setupMonitor(for: window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.viewModel = viewModel
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    /// Coordinator class to handle NSEvents.
    ///
    /// 处理 NSEvent 的协调器类。
    class Coordinator {
        var viewModel: OverviewViewModel
        private var monitor: Any?
        private weak var window: NSWindow?
        
        // Pan State
        // 平移状态
        private var isPanning = false
        private var lastPanLocation: NSPoint = .zero
        
        init(viewModel: OverviewViewModel) {
            self.viewModel = viewModel
        }
        
        deinit {
            removeMonitor()
        }
        
        func setupMonitor(for window: NSWindow) {
            self.window = window
            removeMonitor()
            
            // Monitor events globally in the window.
            // We use .addLocalMonitorForEvents to intercept events before they reach other views.
            //
            // 在窗口中全局监视事件。
            // 我们使用 .addLocalMonitorForEvents 在事件到达其他视图之前拦截它们。
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify, .otherMouseDown, .otherMouseDragged, .otherMouseUp]) { [weak self] event in
                return self?.handleEvent(event) ?? event
            }
        }
        
        private func removeMonitor() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
        
        private func handleEvent(_ event: NSEvent) -> NSEvent? {
            guard let window = window, window.isKeyWindow else { return event }
            
            // Only handle events if the mouse is over the canvas (simplified check: if window is key).
            // Ideally we should check if mouse is over the specific view, but for now this mimics HajimiRef behavior.
            //
            // 仅当鼠标在画布上时处理事件（简化检查：如果窗口是关键窗口）。
            // 理想情况下，我们应该检查鼠标是否在特定视图上，但目前这模仿了 HajimiRef 的行为。
            
            switch event.type {
            case .scrollWheel:
                handleScrollWheel(event)
                return nil // Consume event (消耗事件)
                
            case .magnify:
                handleMagnify(event)
                return nil
                
            case .otherMouseDown:
                if event.buttonNumber == 2 { // Middle Button (中键)
                    isPanning = true
                    lastPanLocation = event.locationInWindow
                    NSCursor.closedHand.push()
                    return nil
                }
                
            case .leftMouseDown:
                // Space + Left Click -> Pan logic could go here.
                // 空格 + 左键 -> 平移逻辑可以放在这里。
                break
                
            case .otherMouseDragged:
                if isPanning {
                    let currentLocation = event.locationInWindow
                    let deltaX = currentLocation.x - lastPanLocation.x
                    let deltaY = currentLocation.y - lastPanLocation.y
                    
                    // Apply pan.
                    // [Interaction Optimization] Correct drag sensitivity after zooming.
                    // Since we changed the modifier order to Pan -> Scale -> Center,
                    // the offset is applied in World Space.
                    // Screen Delta = World Delta * Scale
                    // World Delta = Screen Delta / Scale
                    //
                    // 应用平移。
                    // [交互优化] 修正缩放后的拖拽灵敏度。
                    // 由于我们将修饰符顺序更改为 平移 -> 缩放 -> 居中，
                    // 偏移量是在世界空间中应用的。
                    // 屏幕增量 = 世界增量 * 缩放比例
                    // 世界增量 = 屏幕增量 / 缩放比例
                    viewModel.canvasOffset.width += deltaX / viewModel.canvasScale
                    viewModel.canvasOffset.height -= deltaY / viewModel.canvasScale
                    
                    lastPanLocation = currentLocation
                    return nil
                }
                
            case .otherMouseUp:
                if event.buttonNumber == 2 {
                    isPanning = false
                    NSCursor.pop()
                    return nil
                }
                
            default:
                break
            }
            
            return event
        }
        
        private func handleScrollWheel(_ event: NSEvent) {
            // Wheel -> Zoom Canvas.
            // 滚轮 -> 缩放画布。
            let zoomDelta = event.deltaY * 0.005
            let zoomFactor = 1.0 + zoomDelta
            let newScale = viewModel.canvasScale * zoomFactor
            viewModel.canvasScale = min(max(newScale, 0.1), 10.0)
        }
        
        private func handleMagnify(_ event: NSEvent) {
            // Pinch to Zoom (Trackpad).
            // 捏合缩放（触控板）。
            let zoomFactor = 1.0 + event.magnification
            let newScale = viewModel.canvasScale * zoomFactor
            viewModel.canvasScale = min(max(newScale, 0.1), 10.0)
        }
    }
}

// MARK: - Grid Background
// MARK: - 网格背景

struct GridBackground: View {
    var offset: CGSize
    var scale: CGFloat
    var color: Color
    
    var body: some View {
        // [Performance Optimization] Use Canvas for high-performance drawing.
        // Canvas is much faster than creating thousands of Circle views in a ZStack.
        //
        // [性能优化] 使用 Canvas 的高性能绘制，优化网格密度。
        // Canvas 比在 ZStack 中创建数千个 Circle 视图要快得多。
        Canvas { context, size in
            let baseSpacing: CGFloat = 40.0
            var effectiveSpacing = baseSpacing
            
            // LOD (Level of Detail): Adjust grid density based on zoom level.
            // If the grid becomes too dense, double the spacing.
            //
            // LOD（细节层次）：根据缩放级别调整网格密度。
            // 如果网格变得太密，将间距加倍。
            while (effectiveSpacing * scale) < 15 {
                effectiveSpacing *= 2
            }
            
            let gridStep = effectiveSpacing * scale
            let dotRadius: CGFloat = 1.5
            
            let offsetX = offset.width * scale
            let offsetY = offset.height * scale
            
            // Calculate starting positions to ensure the grid moves with the canvas.
            // 使用取模运算计算起始位置，确保网格随画布移动。
            var startX = offsetX.truncatingRemainder(dividingBy: gridStep)
            if startX < 0 { startX += gridStep }
            
            var startY = offsetY.truncatingRemainder(dividingBy: gridStep)
            if startY < 0 { startY += gridStep }
            
            // Center alignment adjustment.
            // 中心对齐调整。
            startX += (size.width / 2).truncatingRemainder(dividingBy: gridStep)
            startY += (size.height / 2).truncatingRemainder(dividingBy: gridStep)

            // [Performance Optimization] Batch draw calls.
            // Create a single Path containing all dots and fill it once.
            //
            // [性能优化] 批量绘制点，减少单独的 fill 调用。
            // 创建一个包含所有点的 Path 并一次性填充。
            var path = Path()
            for x in stride(from: 0, to: size.width, by: gridStep) {
                for y in stride(from: 0, to: size.height, by: gridStep) {
                    path.addEllipse(in: CGRect(x: x, y: y, width: dotRadius * 2, height: dotRadius * 2))
                }
            }
            context.fill(path, with: .color(color.opacity(0.5)))
        }
        .allowsHitTesting(false) // Grid should not intercept clicks. (网格不应拦截点击)
    }
}

struct OverviewView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var viewModel: OverviewViewModel
    @ObservedObject var settings: SettingsModel
    
    // [Box Selection] State
    // [拉框多选] 状态
    @State private var selectionRect: CGRect? = nil
    @State private var selectionStart: CGPoint? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            // 工具栏
            HStack {
                Text(NSLocalizedString("overview", comment: ""))
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.autoArrange()
                    // Reset view to center.
                    // 重置视图到中心。
                    viewModel.canvasScale = 1.0
                    viewModel.canvasOffset = .zero
                }) {
                    Label(NSLocalizedString("auto_arrange", comment: "Auto Arrange"), systemImage: "square.grid.3x3")
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor)), alignment: .bottom)
            
            // Canvas Area
            // 画布区域
            GeometryReader { geometry in
                ZStack {
                    // 0. Window Accessor for Events (Invisible)
                    // 0. 用于事件的窗口访问器（不可见）
                    WindowAccessor(viewModel: viewModel)
                        .frame(width: 0, height: 0)
                    
                    // 1. Background Color
                    // 1. 背景颜色
                    Color(nsColor: .windowBackgroundColor)
                        .ignoresSafeArea()
                    
                    // 2. Grid
                    // 2. 网格
                    GridBackground(offset: viewModel.canvasOffset, scale: viewModel.canvasScale, color: settings.gridColor)
                    
                    // 2.5. [Box Selection] Interaction Layer
                    // Captures drag events for box selection and click events for clearing selection.
                    //
                    // 2.5. [拉框多选] 交互层
                    // 捕获用于框选的拖拽事件和用于清除选区的点击事件。
                    Color.black.opacity(0.001) // Nearly transparent to allow hit testing. (几乎透明以允许命中测试)
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                                .onChanged { value in
                                    if selectionStart == nil {
                                        selectionStart = value.startLocation
                                    }
                                    let start = selectionStart!
                                    let current = value.location
                                    // Calculate selection rectangle.
                                    // 计算选区矩形。
                                    selectionRect = CGRect(
                                        x: min(start.x, current.x),
                                        y: min(start.y, current.y),
                                        width: abs(current.x - start.x),
                                        height: abs(current.y - start.y)
                                    )
                                }
                                .onEnded { value in
                                    if let rect = selectionRect {
                                        selectItems(in: rect, geometry: geometry)
                                    }
                                    // Reset selection state.
                                    // 重置选区状态。
                                    selectionRect = nil
                                    selectionStart = nil
                                }
                        )
                        .onTapGesture {
                            // Click on empty space clears selection.
                            // 点击空白区域清空选中。
                            viewModel.selectedItemIds.removeAll()
                        }
                    
                    // 3. Infinite Canvas Content
                    // 3. 无限画布内容
                    ZStack(alignment: .topLeading) {
                        // [Performance Optimization] View Culling: Only render items visible in the viewport.
                        // [性能优化] 视图剔除：只渲染可见区域的项目。
                        let visibleItems = viewModel.visibleItems(in: geometry.size)
                        ForEach(visibleItems) { item in
                            OverviewItemView_Optimized(
                                viewModel: viewModel,
                                item: item,
                                status: appModel.results[item.fileURL.lastPathComponent]
                            )
                        }
                        
                        // 6. [多选缩放] 选中项的包围盒及手柄 (移入 ZStack 以跟随变换)
                        if !viewModel.selectedItemIds.isEmpty {
                            SelectionOverlay(viewModel: viewModel)
                        }
                    }
                    // [Fix] Modifier Order for Correct Zooming
                    // [修复] 正确的缩放修饰符顺序
                    // 1. Pan (World Space)
                    // 1. 平移（世界空间）
                    .offset(viewModel.canvasOffset)
                    // 2. Zoom (Scale around top-leading origin to match coordinate system)
                    // 2. 缩放（围绕左上角原点缩放，以匹配坐标系）
                    .scaleEffect(viewModel.canvasScale, anchor: .topLeading)
                    // 3. Center on Screen (Screen Space)
                    // 3. 屏幕居中（屏幕空间）
                    .offset(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    
                    // 3.5. [Box Selection] Visual Feedback
                    // 3.5. [拉框多选] 视觉反馈
                    if let rect = selectionRect {
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 2)
                            .background(Color.blue.opacity(0.1))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .allowsHitTesting(false)
                    }
                    
                    // 4. Loading Indicator
                    // 4. 加载指示器
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                }
                .clipped()
                .coordinateSpace(name: "Canvas")
            }
        }
        .onAppear {
            // Initial load if needed.
            // 如果需要，进行初始加载。
            if viewModel.items.isEmpty && !appModel.files.isEmpty {
                viewModel.loadImages(from: appModel.files)
            }
        }
        .onChange(of: appModel.files) { _, newFiles in
            viewModel.loadImages(from: newFiles)
        }
        // [High Res Loading] Check when zoom or pan changes.
        // [高分辨率加载] 当缩放或平移变化时检查。
        .onChange(of: viewModel.canvasScale) { _, _ in
            // Debounce could be added here if needed.
            // Use a fixed reasonable viewport size for calculation, or pass geometry if available.
            // Using a slightly larger size ensures we load images just outside the view too.
            viewModel.checkAndLoadHighRes(viewportSize: CGSize(width: 1920, height: 1080))
        }
        .onChange(of: viewModel.canvasOffset) { _, _ in
            viewModel.checkAndLoadHighRes(viewportSize: CGSize(width: 1920, height: 1080))
        }
    }
    
    // [Box Selection] Convert screen space selection rect to world space and select intersecting items.
    // [拉框多选] 将屏幕空间的框选矩形转换为世界空间，并选中相交的项目。
    private func selectItems(in rect: CGRect, geometry: GeometryProxy) {
        let frameWidth = geometry.size.width
        let frameHeight = geometry.size.height
        let offset = viewModel.canvasOffset
        let scale = viewModel.canvasScale
        
        // Convert the four corners of the screen rect to world space.
        // 将屏幕矩形的四个角转换到世界空间。
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]
        
        let worldCorners = corners.map { p -> CGPoint in
            // Inverse Transform: Screen -> World
            // Screen = Center + (World + Offset) * Scale
            // World = (Screen - Center) / Scale - Offset
            //
            // 逆变换：屏幕坐标 -> 世界坐标
            // 注意：由于 scaleEffect 的 anchor 设置为 .topLeading，
            // 变换顺序实际上是：
            // 1. 平移 (Offset)
            // 2. 缩放 (Scale)
            // 3. 居中 (Center)
            //
            // 公式：Screen = (World + Offset) * Scale + Center
            
            let x1 = p.x - frameWidth / 2
            let y1 = p.y - frameHeight / 2
            
            let x2 = x1 / scale
            let y2 = y1 / scale
            
            let x3 = x2 - offset.width
            let y3 = y2 - offset.height
            
            return CGPoint(x: x3, y: y3)
        }
        
        let minWx = worldCorners.map { $0.x }.min()!
        let maxWx = worldCorners.map { $0.x }.max()!
        let minWy = worldCorners.map { $0.y }.min()!
        let maxWy = worldCorners.map { $0.y }.max()!
        
        let worldRect = CGRect(x: minWx, y: minWy, width: maxWx - minWx, height: maxWy - minWy)
        
        // Find items intersecting with worldRect.
        // 查找与 worldRect 相交的项目。
        var newSelection = Set<UUID>()
        for item in viewModel.items {
            // Calculate item's world frame considering its individual scale.
            // 计算考虑其单独缩放比例的项目的世界框架。
            let width = item.size.width * item.scale
            let height = item.size.height * item.scale
            let itemFrame = CGRect(
                x: item.position.x - width / 2,
                y: item.position.y - height / 2,
                width: width,
                height: height
            )
            
            // Check for intersection instead of just center point containment.
            // 检查相交而不是仅检查中心点包含。
            if worldRect.intersects(itemFrame) {
                newSelection.insert(item.id)
            }
        }
        
        viewModel.selectedItemIds = newSelection
    }
}

// MARK: - Selection Overlay (Handles Group Resizing)
// MARK: - 选择覆盖层 (处理组调整大小)

struct SelectionOverlay: View {
    @ObservedObject var viewModel: OverviewViewModel
    
    // Drag state.
    // 拖拽状态。
    @State private var initialBounds: CGRect? = nil
    @State private var initialItems: [UUID: (pos: CGPoint, scale: CGFloat)] = [:]
    
    var body: some View {
        if let bounds = viewModel.calculateSelectionBounds() {
            // Draw in World Space directly.
            // Since SelectionOverlay is a child of the ZStack which already applies .offset and .scaleEffect,
            // we can use the bounds (in World Space) directly.
            //
            // 直接在世界坐标系中绘制。
            // 因为 SelectionOverlay 是 ZStack 的子视图，而 ZStack 已经应用了 .offset 和 .scaleEffect，
            // 所以我们可以直接使用 bounds（世界坐标）。
            
            ZStack {
                // Bounding box border.
                // 包围盒边框。
                Rectangle()
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1.5 / viewModel.canvasScale, dash: [5 / viewModel.canvasScale]))
                    .frame(width: bounds.width, height: bounds.height)
                    .position(x: bounds.midX, y: bounds.midY)
                    .allowsHitTesting(false)
                
                // 8 Control Handles.
                // 8 个控制手柄。
                let handleSize = 10.0 / viewModel.canvasScale
                
                // Corner Handles.
                // 角落手柄。
                ForEach([
                    (UnitPoint.topLeading, CursorType.resizeNorthWestSouthEast),
                    (UnitPoint.topTrailing, CursorType.resizeNorthEastSouthWest),
                    (UnitPoint.bottomLeading, CursorType.resizeNorthEastSouthWest),
                    (UnitPoint.bottomTrailing, CursorType.resizeNorthWestSouthEast)
                ], id: \.0) { anchor, cursor in
                    handleView(for: anchor, bounds: bounds, size: handleSize, cursor: cursor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 关键修复：确保 Overlay 填满父容器，使 .position() 坐标系正确
        }
    }
    
    enum CursorType {
        case resizeNorthWestSouthEast
        case resizeNorthEastSouthWest
    }
    
    private func handleView(for anchor: UnitPoint, bounds: CGRect, size: CGFloat, cursor: CursorType) -> some View {
        let x = bounds.minX + anchor.x * bounds.width
        let y = bounds.minY + anchor.y * bounds.height
        
        return Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.blue, lineWidth: 1.0 / viewModel.canvasScale))
            .position(x: x, y: y)
            .onHover { inside in
                if inside {
                    switch cursor {
                    case .resizeNorthWestSouthEast:
                        // macOS SwiftUI currently doesn't expose resize cursors, use crosshair or custom cursor.
                        // macOS SwiftUI 暂时没有公开的 resize 游标，先用 crosshair 或自定义。
                        NSCursor.crosshair.push()
                    case .resizeNorthEastSouthWest:
                        NSCursor.crosshair.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("Canvas"))
                    .onChanged { value in
                        handleDrag(value: value, anchor: anchor, currentBounds: bounds)
                    }
                    .onEnded { _ in
                        initialBounds = nil
                        initialItems = [:]
                    }
            )
    }
    
    private func handleDrag(value: DragGesture.Value, anchor: UnitPoint, currentBounds: CGRect) {
        // 1. Initialize state.
        // 1. 初始化状态。
        if initialBounds == nil {
            initialBounds = currentBounds
            for id in viewModel.selectedItemIds {
                if let item = viewModel.items.first(where: { $0.id == id }) {
                    initialItems[id] = (item.position, item.scale)
                }
            }
        }
        
        guard let startBounds = initialBounds else { return }
        
        // 2. Calculate new bounding box after drag.
        // value.translation is in screen pixels, convert to world units.
        //
        // 2. 计算拖拽后的新包围盒。
        // value.translation 是屏幕像素，需要转为世界单位。
        let deltaX = value.translation.width / viewModel.canvasScale
        let deltaY = value.translation.height / viewModel.canvasScale
        
        var newBounds = startBounds
        
        // Adjust bounds based on anchor.
        // 根据锚点调整边界。
        if anchor.x == 0 { // Left
            newBounds.origin.x += deltaX
            newBounds.size.width -= deltaX
        } else { // Right
            newBounds.size.width += deltaX
        }
        
        if anchor.y == 0 { // Top
            newBounds.origin.y += deltaY
            newBounds.size.height -= deltaY
        } else { // Bottom
            newBounds.size.height += deltaY
        }
        
        // 3. Calculate scale factor.
        // Re-calculate based on fixed anchor point (diagonal point).
        //
        // 3. 计算缩放比例。
        // 重新计算：基于固定锚点（对角点）。
        let fixedAnchorX = anchor.x == 0 ? startBounds.maxX : startBounds.minX
        let fixedAnchorY = anchor.y == 0 ? startBounds.maxY : startBounds.minY
        let fixedPoint = CGPoint(x: fixedAnchorX, y: fixedAnchorY)
        
        let startPoint = CGPoint(
            x: anchor.x == 0 ? startBounds.minX : startBounds.maxX,
            y: anchor.y == 0 ? startBounds.minY : startBounds.maxY
        )
        
        let currentPoint = CGPoint(x: startPoint.x + deltaX, y: startPoint.y + deltaY)
        
        let startDist = hypot(startPoint.x - fixedPoint.x, startPoint.y - fixedPoint.y)
        let currentDist = hypot(currentPoint.x - fixedPoint.x, currentPoint.y - fixedPoint.y)
        
        let scaleFactor = startDist > 0 ? currentDist / startDist : 1.0
        
        // 4. Apply transform to all selected items.
        // 4. 应用变换到所有选中项。
        for id in viewModel.selectedItemIds {
            guard let initial = initialItems[id],
                  let index = viewModel.items.firstIndex(where: { $0.id == id }) else { continue }
            
            // Update Scale.
            // 更新 Scale。
            viewModel.items[index].scale = initial.scale * scaleFactor
            
            // Update Position.
            // New Position = Fixed Point + (Old Position - Fixed Point) * Scale Factor.
            //
            // 更新 Position。
            // 新位置 = 固定点 + (旧位置 - 固定点) * 缩放因子。
            let vecX = initial.pos.x - fixedPoint.x
            let vecY = initial.pos.y - fixedPoint.y
            
            viewModel.items[index].position = CGPoint(
                x: fixedPoint.x + vecX * scaleFactor,
                y: fixedPoint.y + vecY * scaleFactor
            )
        }
    }
}

// MARK: - Overview Item View - Simplified Version
// MARK: - 概览项目视图 - 简化版本

struct OverviewItemView_Optimized: View {
    @ObservedObject var viewModel: OverviewViewModel
    var item: OverviewItem
    let status: String?
    
    // Local state for resize gesture.
    // 调整大小手势的本地状态。
    @State private var initialDragScale: CGFloat? = nil
    @State private var dragStartDistance: CGFloat = 0
    
    var isSelected: Bool {
        viewModel.selectedItemIds.contains(item.id)
    }
    
    // Calculate display position (including drag offset).
    // 计算显示位置（包含拖拽偏移）。
    private var displayPosition: CGPoint {
        let currentOffset = isSelected ? viewModel.currentDragOffset : .zero
        return CGPoint(
            x: item.position.x + currentOffset.width,
            y: item.position.y + currentOffset.height
        )
    }
    
    // Constant screen space size.
    // 恒定屏幕空间尺寸。
    private var handleSize: CGFloat {
        // [Fix] Remove item.scale dependency as we now bake scale into frame size.
        // [修复] 移除 item.scale 依赖，因为我们现在将缩放烘焙到帧大小中。
        let totalScale = max(viewModel.canvasScale, 0.01)
        return 12.0 / totalScale
    }
    
    private var borderWidth: CGFloat {
        // [Fix] Remove item.scale dependency.
        // [修复] 移除 item.scale 依赖。
        let totalScale = max(viewModel.canvasScale, 0.01)
        return 3.0 / totalScale
    }
    
    private var cachedStatusColor: Color {
        guard let status = status else { return .gray }
        return statusColor(status)
    }
    
    var body: some View {
        // [Fix] Bake item.scale into layout frames to ensure correct hit testing.
        // [修复] 将 item.scale 烘焙到布局帧中，以确保正确的命中测试。
        let scaledWidth = item.size.width * item.scale
        let scaledHeight = item.size.height * item.scale
        
        ZStack {
            // 1. Image Layer (Centered at position).
            // 1. 图片层（以位置为中心）。
            ZStack {
                if let nsImage = item.thumbnail {
                    Image(nsImage: nsImage)
                        .resizable()
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: scaledWidth, height: scaledHeight)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(4)
                        .shadow(radius: isSelected ? 4 : 2)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: scaledWidth, height: scaledHeight)
                        .overlay(ProgressView())
                }
                
                // Selection border.
                // 选中边框。
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, lineWidth: borderWidth)
                        .frame(width: scaledWidth, height: scaledHeight)
                }
            }
            .frame(width: scaledWidth, height: scaledHeight)
            
            // 2. Status Indicator (Overlay, Top-Left).
            // 2. 状态指示器（覆盖层，左上角）。
            if let status = status {
                Text(NSLocalizedString(status, comment: ""))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(cachedStatusColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .offset(y: -scaledHeight/2 - 15)
            }
            
            // 3. Filename (Overlay, Bottom).
            // 3. 文件名（覆盖层，底部）。
            Text(item.fileURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: scaledWidth)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
                .offset(y: scaledHeight/2 + 15)
        }
        // [Fix] Removed .scaleEffect(item.scale) to fix hit testing issues.
        // [修复] 移除了 .scaleEffect(item.scale) 以修复命中测试问题。
        .contentShape(Rectangle())
        // Tap to select.
        // 单击选中。
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.shift) {
                if isSelected {
                    viewModel.selectedItemIds.remove(item.id)
                } else {
                    viewModel.selectedItemIds.insert(item.id)
                }
            } else {
                viewModel.selectedItemIds = [item.id]
            }
        }
        // Drag to move.
        // 拖拽移动。
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("Canvas")) // Use Canvas coordinate space. (使用 Canvas 坐标系)
                .onChanged { value in
                    // If dragging an unselected image, select it first.
                    // 如果拖拽的是未选中的图片，先选中它。
                    if !isSelected {
                        viewModel.selectedItemIds = [item.id]
                    }
                    
                    // Update drag offset.
                    // value.translation is in screen pixels, divide by canvasScale to convert to world coordinates.
                    //
                    // 更新拖拽偏移。
                    // value.translation 是屏幕像素单位，需要除以 canvasScale 转换为世界坐标单位。
                    viewModel.currentDragOffset = CGSize(
                        width: value.translation.width / viewModel.canvasScale,
                        height: value.translation.height / viewModel.canvasScale
                    )
                }
                .onEnded { value in
                    // Commit move.
                    // 提交移动。
                    let finalOffset = CGSize(
                        width: value.translation.width / viewModel.canvasScale,
                        height: value.translation.height / viewModel.canvasScale
                    )
                    
                    for id in viewModel.selectedItemIds {
                        if let index = viewModel.items.firstIndex(where: { $0.id == id }) {
                            viewModel.items[index].position.x += finalOffset.width
                            viewModel.items[index].position.y += finalOffset.height
                        }
                    }
                    
                    viewModel.currentDragOffset = .zero
                }
        )
        .position(displayPosition)
    }
    
    func statusColor(_ status: String) -> Color {
        switch status {
        case "pass": return Color(hex: "0e639c") ?? .blue
        case "fail": return Color(hex: "a10000") ?? .red
        case "invalid": return Color(hex: "8e8e8e") ?? .gray
        default: return .gray
        }
    }
}

struct OverviewView_Previews: PreviewProvider {
    static var previews: some View {
        OverviewView(appModel: AppModel(), viewModel: OverviewViewModel(), settings: SettingsModel())
    }
}
