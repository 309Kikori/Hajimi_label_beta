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
                    // When zoomed out (scale < 1), 1px on screen corresponds to 1/scale px in world space.
                    // Dividing by scale ensures that the canvas moves 1:1 with the mouse cursor visually.
                    //
                    // 应用平移。
                    // [交互优化] 修正缩放后的拖拽灵敏度。
                    // 当画布缩放比例很小（缩小）时，屏幕上的 1px 对应画布世界坐标中的 1/scale px。
                    // 如果不除以 scale，在缩小状态下拖拽会感觉非常“滑”或移动极其缓慢（不跟手）。
                    // 除以 scale 后，鼠标移动 1px，画布内容在视觉上也准确移动 1px。
                    viewModel.canvasOffset.width += deltaX / viewModel.canvasScale
                    viewModel.canvasOffset.height -= deltaY / viewModel.canvasScale // Y is inverted in some contexts, but here deltaY is up-positive (Y 在某些上下文中是反转的，但这里 deltaY 是向上为正)
                    
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
            context.fill(path, with: .color(.gray.opacity(0.5)))
        }
        .allowsHitTesting(false) // Grid should not intercept clicks. (网格不应拦截点击)
    }
}

struct OverviewView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var viewModel: OverviewViewModel
    
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
                    GridBackground(offset: viewModel.canvasOffset, scale: viewModel.canvasScale)
                    
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
                    ZStack {
                        // [Performance Optimization] View Culling: Only render items visible in the viewport.
                        // [性能优化] 视图剔除：只渲染可见区域的项目。
                        let visibleItems = viewModel.visibleItems(in: geometry.size)
                        ForEach(visibleItems) { item in
                            OverviewItemView(
                                item: item,
                                status: appModel.results[item.fileURL.lastPathComponent],
                                isSelected: viewModel.selectedItemIds.contains(item.id),
                                canvasScale: viewModel.canvasScale,
                                onDragEnd: { offset in
                                    // Update item position in model.
                                    // 更新模型中的项目位置。
                                    let newPos = CGPoint(
                                        x: item.position.x + offset.width,
                                        y: item.position.y + offset.height
                                    )
                                    viewModel.updatePosition(for: item.id, newPosition: newPos)
                                },
                                onScaleChange: { scaleFactor in
                                    if let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
                                        viewModel.items[index].scale *= scaleFactor
                                    }
                                }
                            )
                            .position(x: item.position.x, y: item.position.y)
                            .scaleEffect(item.scale) // Apply individual item scale. (应用单个项目缩放)
                            .onTapGesture {
                                viewModel.selectedItemIds = [item.id]
                            }
                            .onTapGesture(count: 2) {
                                // Double click to open in Review mode.
                                // 双击在审核模式中打开。
                                appModel.selectedFile = item.fileURL
                                appModel.activeTab = .review
                            }
                        }
                    }
                    .offset(viewModel.canvasOffset)
                    .scaleEffect(viewModel.canvasScale)
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
            // Screen = Center + (World * Scale + Offset)
            // World = (Screen - Center) / Scale - Offset
            //
            // 逆变换：屏幕坐标 -> 世界坐标
            
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
            if worldRect.contains(CGPoint(x: item.position.x, y: item.position.y)) {
                newSelection.insert(item.id)
            }
        }
        
        viewModel.selectedItemIds = newSelection
    }
}

struct OverviewItemView: View {
    let item: OverviewItem
    let status: String?
    let isSelected: Bool
    let canvasScale: CGFloat
    
    // Callbacks for interaction events.
    // 交互事件的回调。
    var onDragEnd: ((CGSize) -> Void)?
    var onScaleChange: ((CGFloat) -> Void)?
    
    // Local state for temporary gesture transformations.
    // 用于临时手势变换的本地状态。
    @State private var dragOffset: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    
    // [Performance Optimization] Cache status color calculation.
    // [性能优化] 缓存状态颜色计算。
    private var cachedStatusColor: Color {
        guard let status = status else { return .gray }
        return statusColor(status)
    }
    
    // [Visual Design] Constant screen-space handle size.
    // Ensures handles remain the same visual size regardless of zoom level.
    //
    // [视觉设计] 恒定屏幕空间手柄大小。
    // 确保无论缩放级别如何，手柄保持相同的视觉大小。
    private var handleSize: CGFloat {
        12.0 / (item.scale * canvasScale)
    }
    
    private var borderWidth: CGFloat {
        3.0 / (item.scale * canvasScale)
    }
    
    var body: some View {
        VStack(spacing: 5) {
            // Status Indicator Badge
            // 状态指示徽章
            if let status = status {
                Text(NSLocalizedString(status, comment: ""))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(cachedStatusColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            // Image Content
            // 图片内容
            if let nsImage = item.thumbnail {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: item.size.width, height: item.size.height)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
                    .shadow(radius: isSelected ? 4 : 2)
                    .overlay(
                        ZStack {
                            // Selection Border
                            // 选中边框
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isSelected ? borderWidth : 0)
                            
                            // Resize Handles (Only visible when selected)
                            // 调整手柄（仅在选中时可见）
                            if isSelected {
                                // Top-Left
                                ResizeHandle(size: handleSize)
                                    .position(x: 0, y: 0)
                                    .gesture(resizeGesture(corner: .topLeft))
                                
                                // Top-Right
                                ResizeHandle(size: handleSize)
                                    .position(x: item.size.width, y: 0)
                                    .gesture(resizeGesture(corner: .topRight))
                                
                                // Bottom-Left
                                ResizeHandle(size: handleSize)
                                    .position(x: 0, y: item.size.height)
                                    .gesture(resizeGesture(corner: .bottomLeft))
                                
                                // Bottom-Right
                                ResizeHandle(size: handleSize)
                                    .position(x: item.size.width, y: item.size.height)
                                    .gesture(resizeGesture(corner: .bottomRight))
                            }
                        }
                    )
            } else {
                // Placeholder while loading
                // 加载时的占位符
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: item.size.width, height: item.size.height)
                    .overlay(ProgressView())
            }
            
            // Filename Label
            // 文件名标签
            Text(item.fileURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: item.size.width)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
        }
        .padding(5)
        .scaleEffect(zoomScale) // Apply temporary zoom scale from gesture. (应用手势的临时缩放比例)
        .offset(dragOffset)     // Apply temporary drag offset. (应用临时拖拽偏移)
        .gesture(
            SimultaneousGesture(
                // Drag Gesture for moving the item.
                // 用于移动项目的拖拽手势。
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        // Convert screen translation to world translation.
                        // 将屏幕平移转换为世界平移。
                        self.dragOffset = CGSize(
                            width: value.translation.width / canvasScale,
                            height: value.translation.height / canvasScale
                        )
                    }
                    .onEnded { value in
                        let worldOffset = CGSize(
                            width: value.translation.width / canvasScale,
                            height: value.translation.height / canvasScale
                        )
                        onDragEnd?(worldOffset)
                        self.dragOffset = .zero
                    }
                ,
                // Magnification Gesture for scaling the item (Trackpad pinch).
                // 用于缩放项目的放大手势（触控板捏合）。
                MagnificationGesture()
                    .onChanged { value in
                        zoomScale = value
                    }
                    .onEnded { value in
                        onScaleChange?(value)
                        zoomScale = 1.0
                    }
            )
        )
    }
    
    // [Interaction Logic] Resize Handle Gesture
    // [交互逻辑] 调整手柄手势
    private func resizeGesture(corner: ResizeCorner) -> some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                // Visual feedback during drag could be implemented here.
                // 拖拽过程中的视觉反馈可以在这里实现。
            }
            .onEnded { value in
                // Calculate scale factor based on drag distance and corner.
                // 根据拖拽距离和角落计算缩放因子。
                let delta = value.translation
                let originalSize = item.size
                
                var scaleDelta: CGFloat = 0
                switch corner {
                case .topLeft:
                    scaleDelta = -(delta.width + delta.height) / (originalSize.width + originalSize.height)
                case .topRight:
                    scaleDelta = (delta.width - delta.height) / (originalSize.width + originalSize.height)
                case .bottomLeft:
                    scaleDelta = (-delta.width + delta.height) / (originalSize.width + originalSize.height)
                case .bottomRight:
                    scaleDelta = (delta.width + delta.height) / (originalSize.width + originalSize.height)
                }
                
                // Apply new scale with limits (0.1x to 5.0x).
                // 应用新的缩放比例，并限制范围（0.1x 到 5.0x）。
                let newScale = max(0.1, min(5.0, item.scale * (1.0 + scaleDelta / canvasScale)))
                onScaleChange?(newScale / item.scale)
            }
    }
    
    enum ResizeCorner {
        case topLeft, topRight, bottomLeft, bottomRight
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
        OverviewView(appModel: AppModel(), viewModel: OverviewViewModel())
    }
}
