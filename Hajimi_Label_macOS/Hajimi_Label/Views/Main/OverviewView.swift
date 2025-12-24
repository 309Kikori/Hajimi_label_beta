import SwiftUI

// MARK: - Resize Handle
struct ResizeHandle: View {
    let size: CGFloat
    let borderWidth: CGFloat // 使用和图片边框相同的屏幕空间适配宽度
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: borderWidth)
            )
            .shadow(radius: 2)
    }
}

// MARK: - Window Accessor & Event Monitor
struct WindowAccessor: NSViewRepresentable {
    @ObservedObject var viewModel: OverviewViewModel
    
    func makeNSView(context: Context) -> WindowAccessorView {
        let view = WindowAccessorView()
        view.onWindowAvailable = { window in
            context.coordinator.setupMonitor(for: window)
        }
        return view
    }
    
    func updateNSView(_ nsView: WindowAccessorView, context: Context) {
        context.coordinator.viewModel = viewModel
        // 如果 window 已经可用但监听器还没设置，现在设置
        if let window = nsView.window {
            context.coordinator.setupMonitor(for: window)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    // 自定义 NSView 子类，用于正确获取 window
    class WindowAccessorView: NSView {
        var onWindowAvailable: ((NSWindow) -> Void)?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window = window {
                onWindowAvailable?(window)
            }
        }
    }
    
    class Coordinator {
        var viewModel: OverviewViewModel
        private var monitor: Any?
        private weak var window: NSWindow?
        private var isMonitorSetup = false
        
        // Pan State
        private var isPanning = false
        private var lastPanLocation: NSPoint = .zero
        
        init(viewModel: OverviewViewModel) {
            self.viewModel = viewModel
        }
        
        deinit {
            removeMonitor()
        }
        
        func setupMonitor(for window: NSWindow) {
            // 防止重复设置
            guard !isMonitorSetup || self.window !== window else { return }
            
            self.window = window
            removeMonitor()
            isMonitorSetup = true
            
            // Monitor events globally in the window
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
            
            // Only handle events if the mouse is over the canvas (simplified check: if window is key)
            // Ideally we should check if mouse is over the specific view, but for now this mimics HajimiRef
            
            switch event.type {
            case .scrollWheel:
                handleScrollWheel(event)
                return nil 
                
            case .magnify:
                handleMagnify(event)
                return nil
                
            case .otherMouseDown:
                if event.buttonNumber == 2 { // Middle Button
                    isPanning = true
                    lastPanLocation = event.locationInWindow
                    NSCursor.closedHand.push()
                    return nil
                }
                
            case .leftMouseDown:
                // Space + Left Click -> Pan
                // Removed invalid NSEvent.modifierFlags.contains(.space) check.
                // Pan is handled by Middle Mouse (button 2) or we can add a key monitor if needed.
                break
                
            case .otherMouseDragged:
                if isPanning {
                    let currentLocation = event.locationInWindow
                    let deltaX = currentLocation.x - lastPanLocation.x
                    let deltaY = currentLocation.y - lastPanLocation.y
                    
                    // Apply pan
                    // [交互优化] 修正缩放后的拖拽灵敏度
                    // 当画布缩放比例很小（缩小）时，屏幕上的 1px 对应画布世界坐标中的 1/scale px。
                    // 如果不除以 scale，在缩小状态下拖拽会感觉非常“滑”或移动极其缓慢（不跟手）。
                    // 除以 scale 后，鼠标移动 1px，画布内容在视觉上也准确移动 1px。
                    viewModel.canvasOffset.width += deltaX / viewModel.canvasScale
                    viewModel.canvasOffset.height -= deltaY / viewModel.canvasScale // Y is inverted in some contexts, but here deltaY is up-positive
                    
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
            // Wheel -> Zoom Canvas
            let zoomDelta = event.deltaY * 0.005
            let zoomFactor = 1.0 + zoomDelta
            let newScale = viewModel.canvasScale * zoomFactor
            viewModel.canvasScale = min(max(newScale, 0.1), 10.0)
        }
        
        private func handleMagnify(_ event: NSEvent) {
            let zoomFactor = 1.0 + event.magnification
            let newScale = viewModel.canvasScale * zoomFactor
            viewModel.canvasScale = min(max(newScale, 0.1), 10.0)
        }
    }
}

// MARK: - Grid Background
struct GridBackground: View {
    var offset: CGSize
    var scale: CGFloat
    
    var body: some View {
        // [性能优化] 使用 Canvas 的高性能绘制，优化网格密度
        Canvas { context, size in
            let baseSpacing: CGFloat = 40.0
            var effectiveSpacing = baseSpacing
            
            // LOD: 根据缩放级别调整网格密度
            while (effectiveSpacing * scale) < 15 {
                effectiveSpacing *= 2
            }
            
            let gridStep = effectiveSpacing * scale
            let dotRadius: CGFloat = 1.5
            
            let offsetX = offset.width * scale
            let offsetY = offset.height * scale
            
            var startX = offsetX.truncatingRemainder(dividingBy: gridStep)
            if startX < 0 { startX += gridStep }
            
            var startY = offsetY.truncatingRemainder(dividingBy: gridStep)
            if startY < 0 { startY += gridStep }
            
            startX += (size.width / 2).truncatingRemainder(dividingBy: gridStep)
            startY += (size.height / 2).truncatingRemainder(dividingBy: gridStep)

            // [性能优化] 批量绘制点，减少单独的 fill 调用
            var path = Path()
            for x in stride(from: 0, to: size.width, by: gridStep) {
                for y in stride(from: 0, to: size.height, by: gridStep) {
                    path.addEllipse(in: CGRect(x: x, y: y, width: dotRadius * 2, height: dotRadius * 2))
                }
            }
            context.fill(path, with: .color(.gray.opacity(0.5)))
        }
        .allowsHitTesting(false)
    }
}

struct OverviewView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var viewModel: OverviewViewModel
    
    // [拉框多选] 状态
    @State private var selectionRect: CGRect? = nil
    @State private var selectionStart: CGPoint? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(NSLocalizedString("overview", comment: ""))
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.autoArrange()
                    // autoArrange 内部已经设置了正确的 canvasOffset 来居中显示
                    viewModel.canvasScale = 1.0
                }) {
                    Label(NSLocalizedString("auto_arrange", comment: "Auto Arrange"), systemImage: "square.grid.3x3")
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor)), alignment: .bottom)
            
            // Canvas - 完全照抄 HajimiRef 的 CanvasView 结构
            GeometryReader { geometry in
                ZStack {
                    // 0. Window Accessor for Events
                    WindowAccessor(viewModel: viewModel)
                        .frame(width: 0, height: 0)
                    
                    // 1. Background Color
                    Color(nsColor: .windowBackgroundColor)
                        .ignoresSafeArea()
                    
                    // 2. Grid
                    GridBackground(offset: viewModel.canvasOffset, scale: viewModel.canvasScale)
                    
                    // 3. [拉框多选] 交互层 - 放在图片层下面，用于框选和点击清空
                    // 完全照抄 HajimiRef 的逻辑
                    Color.black.opacity(0.001)
                        .gesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                                .onChanged { value in
                                    if selectionStart == nil {
                                        selectionStart = value.startLocation
                                    }
                                    let start = selectionStart!
                                    let current = value.location
                                    selectionRect = CGRect(
                                        x: min(start.x, current.x),
                                        y: min(start.y, current.y),
                                        width: abs(current.x - start.x),
                                        height: abs(current.y - start.y)
                                    )
                                }
                                .onEnded { value in
                                    if let rect = selectionRect {
                                        selectItems(in: rect, geometry: geometry, addToSelection: NSEvent.modifierFlags.contains(.shift))
                                    }
                                    selectionRect = nil
                                    selectionStart = nil
                                }
                        )
                        .onTapGesture {
                            // 点击空白区域清空选中
                            viewModel.selectedItemIds.removeAll()
                        }
                    
                    // 4. Images Layer - 图片层放在框选交互层上面
                    ZStack {
                        // [性能优化] 视图剔除：只渲染可见区域的项目
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
                    .offset(viewModel.canvasOffset)
                    .scaleEffect(viewModel.canvasScale)
                    // 确保 ZStack 填满屏幕，使 .position() 的坐标系与屏幕一致
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    
                    // 5. [拉框多选] 显示框选矩形
                    if let rect = selectionRect {
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 1)
                            .background(Color.blue.opacity(0.1))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .allowsHitTesting(false)
                    }
                    
                    // 7. Loading Indicator
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
                // Pan Gesture (Space + Drag or Middle Click is handled by WindowAccessor)
                // We removed the fallback DragGesture to avoid conflict and "double counting" bugs.
            }
        }
        .onAppear {
            if viewModel.items.isEmpty && !appModel.files.isEmpty {
                viewModel.loadImages(from: appModel.files)
            }
        }
        .onChange(of: appModel.files) { _, newFiles in
            viewModel.loadImages(from: newFiles)
        }
    }
    
    // [坐标转换] 屏幕坐标 -> 世界坐标
    // 
    // 变换链：ZStack.offset(O).scaleEffect(S)
    // 正向：Screen = Center + (World + Offset - Center) * Scale
    //       简化：Screen = Center*(1-S) + (World + Offset)*S
    // 
    // 当 Scale = 1 时：Screen = World + Offset
    // 所以：World = Screen - Offset
    // 
    // 当 Scale ≠ 1 时，以屏幕中心为锚点：
    // Screen - Center = (World + Offset - Center) * Scale
    // World = (Screen - Center) / Scale - Offset + Center
    //
    // 但由于我们的 offset 设置为 (-centerX, -centerY)，
    // 当用户点击屏幕中心时，应该得到世界坐标 (centerX, centerY)
    // 验证：World = (Center - Center) / Scale - (-centerX, -centerY) + Center
    //            = 0 + (centerX, centerY) + Center  ← 错！多加了 Center
    //
    // 实际正确公式（不加回 Center）：
    // World = (Screen - Center) / Scale - Offset
    //
    private func screenToWorld(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        let frameWidth = geometry.size.width
        let frameHeight = geometry.size.height
        let offset = viewModel.canvasOffset
        let scale = viewModel.canvasScale
        
        // Step 1: 相对于屏幕中心
        let x1 = point.x - frameWidth / 2
        let y1 = point.y - frameHeight / 2
        
        // Step 2: 逆缩放
        let x2 = x1 / scale
        let y2 = y1 / scale
        
        // Step 3: 逆偏移（并加回 Center 以匹配 Top-Left 坐标系）
        // item.position 是相对于 Top-Left 的，所以我们需要将中心相对坐标转换回 Top-Left 相对坐标
        let worldX = x2 - offset.width + frameWidth / 2
        let worldY = y2 - offset.height + frameHeight / 2
        
        return CGPoint(x: worldX, y: worldY)
    }
    
    // [拉框多选] 将屏幕空间的框选矩形转换为世界空间，并选中相交的项目
    private func selectItems(in rect: CGRect, geometry: GeometryProxy, addToSelection: Bool = false) {
        // 将屏幕矩形的四个角转换到世界空间
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]
        
        let worldCorners = corners.map { screenToWorld($0, geometry: geometry) }
        
        let minWx = worldCorners.map { $0.x }.min()!
        let maxWx = worldCorners.map { $0.x }.max()!
        let minWy = worldCorners.map { $0.y }.min()!
        let maxWy = worldCorners.map { $0.y }.max()!
        
        let worldRect = CGRect(x: minWx, y: minWy, width: maxWx - minWx, height: maxWy - minWy)
        
        // 检查图片中心是否在 worldRect 内（和 HajimiRef 一样）
        var newSelection = Set<UUID>()
        for item in viewModel.items {
            // item.position 已经是以画布中心为原点的世界坐标
            if worldRect.contains(item.position) {
                newSelection.insert(item.id)
            }
        }
        
        // 根据模式更新选择
        if addToSelection {
            viewModel.selectedItemIds.formUnion(newSelection)
        } else {
            viewModel.selectedItemIds = newSelection
        }
    }
}

// MARK: - Selection Overlay (Handles Group Resizing)
struct SelectionOverlay: View {
    @ObservedObject var viewModel: OverviewViewModel
    
    // 拖拽状态
    @State private var initialBounds: CGRect? = nil
    @State private var initialItems: [UUID: (pos: CGPoint, scale: CGFloat)] = [:]
    
    var body: some View {
        if let bounds = viewModel.calculateSelectionBounds() {
            // 转换到屏幕坐标系进行绘制（因为 Overlay 在 ZStack 顶层，且 ZStack 已经应用了 offset/scale）
            // 但这里我们直接在世界坐标系绘制，因为 SelectionOverlay 也是 ZStack 的子视图，
            // 并且 ZStack 已经应用了 .offset 和 .scaleEffect。
            // 所以 bounds (世界坐标) 可以直接使用。
            
            ZStack {
                // 包围盒边框
                Rectangle()
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1.5 / viewModel.canvasScale, dash: [5 / viewModel.canvasScale]))
                    .frame(width: bounds.width, height: bounds.height)
                    .position(x: bounds.midX, y: bounds.midY)
                    .allowsHitTesting(false)
                
                // 8个控制手柄
                let handleSize = 10.0 / viewModel.canvasScale
                
                // 角落手柄
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
                        NSCursor.crosshair.push() // macOS SwiftUI 暂时没有公开的 resize 游标，先用 crosshair 或自定义
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
        // 1. 初始化状态
        if initialBounds == nil {
            initialBounds = currentBounds
            for id in viewModel.selectedItemIds {
                if let item = viewModel.items.first(where: { $0.id == id }) {
                    initialItems[id] = (item.position, item.scale)
                }
            }
        }
        
        guard let startBounds = initialBounds else { return }
        
        // 2. 计算拖拽后的新包围盒
        // value.translation 是屏幕像素，需要转为世界单位
        let deltaX = value.translation.width / viewModel.canvasScale
        let deltaY = value.translation.height / viewModel.canvasScale
        
        var newBounds = startBounds
        
        // 根据锚点调整边界
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
        
        // 3. 计算缩放比例
        // 避免除以零
        let scaleX = startBounds.width > 0 ? newBounds.width / startBounds.width : 1.0
        let scaleY = startBounds.height > 0 ? newBounds.height / startBounds.height : 1.0
        
        // 保持纵横比（取最大变化）
        // 实际上用户可能希望自由缩放，但图片通常保持比例。这里假设保持比例。
        // 如果要自由缩放，需要分别应用 scaleX 和 scaleY，但这会拉伸图片。
        // 这里我们采用 Uniform Scaling，取 max(scaleX, scaleY) 或者根据拖拽主轴决定。
        // 简单起见，我们取 width 的变化作为主导（或者根据 anchor 决定）。
        // 更严谨的做法是：计算新 Bounds 的宽高比，如果 shift 按下则锁定...
        // 这里简化为：使用 scaleX 作为统一缩放因子（假设用户主要在调整大小）
        // 或者取平均值？或者取 max？
        // 让我们用 scaleX (如果拖动的是左右边) 或 scaleY (如果拖动的是上下边)。
        // 对于角点，取 max(abs(scaleX), abs(scaleY)) * sign?
        // 让我们简单点：使用对角线长度比。
        
        // 重新计算：基于固定锚点（对角点）
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
        
        // 4. 应用变换到所有选中项
        for id in viewModel.selectedItemIds {
            guard let initial = initialItems[id],
                  let index = viewModel.items.firstIndex(where: { $0.id == id }) else { continue }
            
            // 更新 Scale
            viewModel.items[index].scale = initial.scale * scaleFactor
            
            // 更新 Position
            // 新位置 = 固定点 + (旧位置 - 固定点) * 缩放因子
            let vecX = initial.pos.x - fixedPoint.x
            let vecY = initial.pos.y - fixedPoint.y
            
            viewModel.items[index].position = CGPoint(
                x: fixedPoint.x + vecX * scaleFactor,
                y: fixedPoint.y + vecY * scaleFactor
            )
        }
    }
}

// MARK: - Overview Item View - 简化版本
struct OverviewItemView_Optimized: View {
    @ObservedObject var viewModel: OverviewViewModel
    var item: OverviewItem
    let status: String?
    
    // Local state for resize gesture
    @State private var initialDragScale: CGFloat? = nil
    @State private var dragStartDistance: CGFloat = 0
    
    var isSelected: Bool {
        viewModel.selectedItemIds.contains(item.id)
    }
    
    // 计算显示位置（包含拖拽偏移）
    private var displayPosition: CGPoint {
        let currentOffset = isSelected ? viewModel.currentDragOffset : .zero
        return CGPoint(
            x: item.position.x + currentOffset.width,
            y: item.position.y + currentOffset.height
        )
    }
    
    // 恒定屏幕空间尺寸
    private var handleSize: CGFloat {
        let totalScale = max(item.scale * viewModel.canvasScale, 0.01)
        return 12.0 / totalScale
    }
    
    private var borderWidth: CGFloat {
        let totalScale = max(item.scale * viewModel.canvasScale, 0.01)
        return 3.0 / totalScale
    }
    
    private var cachedStatusColor: Color {
        guard let status = status else { return .gray }
        return statusColor(status)
    }
    
    var body: some View {
        ZStack {
            // 1. Image Layer (Centered at position)
            ZStack {
                if let nsImage = item.thumbnail {
                    Image(nsImage: nsImage)
                        .resizable()
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: item.size.width, height: item.size.height)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(4)
                        .shadow(radius: isSelected ? 4 : 2)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: item.size.width, height: item.size.height)
                        .overlay(ProgressView())
                }
                
                // 选中边框
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, lineWidth: borderWidth)
                        .frame(width: item.size.width, height: item.size.height)
                }
            }
            .frame(width: item.size.width, height: item.size.height)
            
            // 2. Status Indicator (Overlay, Top-Left)
            if let status = status {
                Text(NSLocalizedString(status, comment: ""))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(cachedStatusColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .position(x: 0, y: -15) // Offset relative to center? No, position in ZStack
                    // Better: Use alignment in ZStack or offset
                    .offset(y: -item.size.height/2 - 15)
            }
            
            // 3. Filename (Overlay, Bottom)
            Text(item.fileURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: item.size.width)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
                .offset(y: item.size.height/2 + 15)
        }
        .scaleEffect(item.scale)
        .contentShape(Rectangle()) // Hit test area includes offsets? No, ZStack frame is determined by children.
        // If we want hit test to cover text, we need to be careful.
        // But for selection box alignment, the center of this ZStack MUST be the center of the Image.
        // Since Image is the first child and has explicit frame, and Text uses .offset (which doesn't affect layout),
        // the ZStack layout center will be the Image center.
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
        // 拖拽移动
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("Canvas")) // 使用 Canvas 坐标系
                .onChanged { value in
                    // 如果拖拽的是未选中的图片，先选中它
                    if !isSelected {
                        viewModel.selectedItemIds = [item.id]
                    }
                    
                    // 更新拖拽偏移
                    // value.translation 是屏幕像素单位，需要除以 canvasScale 转换为世界坐标单位
                    viewModel.currentDragOffset = CGSize(
                        width: value.translation.width / viewModel.canvasScale,
                        height: value.translation.height / viewModel.canvasScale
                    )
                }
                .onEnded { value in
                    // 提交移动
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
        OverviewView(appModel: AppModel(), viewModel: OverviewViewModel())
    }
}
