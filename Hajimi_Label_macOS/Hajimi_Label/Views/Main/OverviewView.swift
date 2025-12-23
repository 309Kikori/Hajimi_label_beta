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
    
    class Coordinator {
        var viewModel: OverviewViewModel
        private var monitor: Any?
        private weak var window: NSWindow?
        
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
            self.window = window
            removeMonitor()
            
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
                    // Reset view to center
                    viewModel.canvasScale = 1.0
                    viewModel.canvasOffset = .zero
                }) {
                    Label(NSLocalizedString("auto_arrange", comment: "Auto Arrange"), systemImage: "square.grid.3x3")
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor)), alignment: .bottom)
            
            // Canvas
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
                    
                    // 2.5. [拉框多选] 交互层：捕获拖拽事件和点击事件
                    Color.black.opacity(0.001)
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .local)
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
                                        selectItems(in: rect, geometry: geometry)
                                    }
                                    selectionRect = nil
                                    selectionStart = nil
                                }
                        )
                        .onTapGesture {
                            // 点击空白区域清空选中
                            viewModel.selectedItemIds.removeAll()
                        }
                    
                    // 3. Infinite Canvas Content
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
                    }
                    .offset(viewModel.canvasOffset)
                    .scaleEffect(viewModel.canvasScale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // Center the ZStack content at the center of GeometryReader
                    
                    // 3.5. [拉框多选] 显示框选矩形
                    if let rect = selectionRect {
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 2)
                            .background(Color.blue.opacity(0.1))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .allowsHitTesting(false)
                    }
                    
                    // 4. Loading Indicator
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
    
    // [拉框多选] 将屏幕空间的框选矩形转换为世界空间，并选中相交的项目
    private func selectItems(in rect: CGRect, geometry: GeometryProxy) {
        let frameWidth = geometry.size.width
        let frameHeight = geometry.size.height
        let offset = viewModel.canvasOffset
        let scale = viewModel.canvasScale
        
        // 将屏幕矩形的四个角转换到世界空间
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]
        
        let worldCorners = corners.map { p -> CGPoint in
            // 逆变换：屏幕坐标 -> 世界坐标
            // Screen = Center + (World * Scale + Offset)
            // World = (Screen - Center) / Scale - Offset
            
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
        
        // 查找与 worldRect 相交的项目
        var newSelection = Set<UUID>()
        for item in viewModel.items {
            if worldRect.contains(CGPoint(x: item.position.x, y: item.position.y)) {
                newSelection.insert(item.id)
            }
        }
        
        viewModel.selectedItemIds = newSelection
    }
}

// MARK: - Overview Item View - 完全基于 HajimiRef 的 ImageView 逻辑
struct OverviewItemView_Optimized: View {
    @ObservedObject var viewModel: OverviewViewModel
    var item: OverviewItem
    let status: String?
    
    // Local state for gestures
    @State private var zoomScale: CGFloat = 1.0
    @State private var initialSelectionBounds: CGRect? = nil
    
    var isSelected: Bool {
        viewModel.selectedItemIds.contains(item.id)
    }
    
    // [交互逻辑] 计算显示位置 - 完全模仿 HajimiRef
    private var displayPosition: CGPoint {
        let currentOffset = isSelected ? viewModel.currentDragOffset : .zero
        
        var x = item.position.x + currentOffset.width
        var y = item.position.y + currentOffset.height
        
        // 应用多选缩放 (相对于锚点)
        if isSelected && viewModel.multiSelectScaleFactor != 1.0 {
            let anchor = viewModel.multiSelectAnchor
            x = anchor.x + (item.position.x - anchor.x) * viewModel.multiSelectScaleFactor
            y = anchor.y + (item.position.y - anchor.y) * viewModel.multiSelectScaleFactor
        }
        
        return CGPoint(x: x, y: y)
    }
    
    // [视觉设计] 恒定屏幕空间尺寸
    private var handleSize: CGFloat {
        let totalScale = max(item.scale * zoomScale * viewModel.canvasScale, 0.01)
        return 12.0 / totalScale
    }
    
    private var borderWidth: CGFloat {
        let totalScale = max(item.scale * zoomScale * viewModel.canvasScale, 0.01)
        return 3.0 / totalScale
    }
    
    private var cachedStatusColor: Color {
        guard let status = status else { return .gray }
        return statusColor(status)
    }
    
    var body: some View {
        VStack(spacing: 5) {
            // Status Indicator
            if let status = status {
                Text(NSLocalizedString(status, comment: ""))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(cachedStatusColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            // Image
            if let nsImage = item.thumbnail {
                Image(nsImage: nsImage)
                    .resizable()
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: item.size.width, height: item.size.height)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
                    .shadow(radius: isSelected ? 4 : 2)
                    .overlay(
                        ZStack {
                            // 选中边框
                            if isSelected {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.blue, lineWidth: borderWidth)
                                
                                // Resize Handles - 使用相同的borderWidth保持视觉一致性
                                ResizeHandle(size: handleSize, borderWidth: borderWidth)
                                    .position(x: 0, y: 0)
                                    .highPriorityGesture(resizeGesture(handle: .topLeading, originalSize: item.size))
                                
                                ResizeHandle(size: handleSize, borderWidth: borderWidth)
                                    .position(x: item.size.width, y: 0)
                                    .highPriorityGesture(resizeGesture(handle: .topTrailing, originalSize: item.size))
                                
                                ResizeHandle(size: handleSize, borderWidth: borderWidth)
                                    .position(x: 0, y: item.size.height)
                                    .highPriorityGesture(resizeGesture(handle: .bottomLeading, originalSize: item.size))
                                
                                ResizeHandle(size: handleSize, borderWidth: borderWidth)
                                    .position(x: item.size.width, y: item.size.height)
                                    .highPriorityGesture(resizeGesture(handle: .bottomTrailing, originalSize: item.size))
                            }
                        }
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: item.size.width, height: item.size.height)
                    .overlay(ProgressView())
            }
            
            // Filename
            Text(item.fileURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: item.size.width)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
        }
        .padding(5)
        .scaleEffect(item.scale * zoomScale * (isSelected ? viewModel.multiSelectScaleFactor : 1.0))
        .position(displayPosition)
        .gesture(
            SimultaneousGesture(
                // [交互逻辑] 拖拽移动 - 完全模仿 HajimiRef
                DragGesture(coordinateSpace: .named("Canvas"))
                    .onChanged { value in
                        // 1. 如果拖拽的是未选中的图片，则选中它
                        if !isSelected {
                            if !NSEvent.modifierFlags.contains(.shift) {
                                viewModel.selectedItemIds = [item.id]
                            } else {
                                viewModel.selectedItemIds.insert(item.id)
                            }
                        }
                        
                        // 2. 更新全局拖拽偏移
                        viewModel.currentDragOffset = CGSize(
                            width: value.translation.width / viewModel.canvasScale,
                            height: value.translation.height / viewModel.canvasScale
                        )
                    }
                    .onEnded { value in
                        // 3. 提交移动
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
                        
                        // 4. 重置
                        viewModel.currentDragOffset = .zero
                    }
                ,
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomScale = value
                        }
                        .onEnded { value in
                            if let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
                                viewModel.items[index].scale *= value
                            }
                            zoomScale = 1.0
                        }
                    ,
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in }
                )
            )
        )
        .onTapGesture {
            // [交互逻辑] 单击选中 - 放在手势外面确保纯点击也能触发
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
    }
    
    // [交互逻辑] 调整大小手势 (对角缩放) - 完全模仿 HajimiRef
    // 支持多选缩放：所有选中的图片会一起缩放，位置也会相对锚点调整
    private func resizeGesture(handle: Alignment, originalSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("Canvas"))
            .onChanged { value in
                // 1. 初始化：计算初始边界和锚点
                if initialSelectionBounds == nil {
                    // 如果有多个选中项，使用整体边界；否则使用单个项的边界
                    if let bounds = viewModel.calculateSelectionBounds() {
                        initialSelectionBounds = bounds
                        
                        // 根据手柄位置确定对角锚点
                        switch handle {
                        case .bottomTrailing: // 拖右下 -> 锚点左上
                            viewModel.multiSelectAnchor = CGPoint(x: bounds.minX, y: bounds.minY)
                        case .topLeading: // 拖左上 -> 锚点右下
                            viewModel.multiSelectAnchor = CGPoint(x: bounds.maxX, y: bounds.maxY)
                        case .topTrailing: // 拖右上 -> 锚点左下
                            viewModel.multiSelectAnchor = CGPoint(x: bounds.minX, y: bounds.maxY)
                        case .bottomLeading: // 拖左下 -> 锚点右上
                            viewModel.multiSelectAnchor = CGPoint(x: bounds.maxX, y: bounds.minY)
                        default:
                            viewModel.multiSelectAnchor = CGPoint(x: bounds.midX, y: bounds.midY)
                        }
                    }
                }
                
                guard let bounds = initialSelectionBounds else { return }
                let anchor = viewModel.multiSelectAnchor
                
                // 2. 计算缩放倍率
                var startHandlePoint: CGPoint = .zero
                switch handle {
                case .bottomTrailing: startHandlePoint = CGPoint(x: bounds.maxX, y: bounds.maxY)
                case .topLeading:     startHandlePoint = CGPoint(x: bounds.minX, y: bounds.minY)
                case .topTrailing:    startHandlePoint = CGPoint(x: bounds.maxX, y: bounds.minY)
                case .bottomLeading:  startHandlePoint = CGPoint(x: bounds.minX, y: bounds.maxY)
                default: break
                }
                
                let deltaX = value.translation.width / viewModel.canvasScale
                let deltaY = value.translation.height / viewModel.canvasScale
                
                let currentHandlePoint = CGPoint(x: startHandlePoint.x + deltaX,
                                                 y: startHandlePoint.y + deltaY)
                
                // 计算距离比率
                let startDistX = abs(startHandlePoint.x - anchor.x)
                let currentDistX = abs(currentHandlePoint.x - anchor.x)
                
                let startDistY = abs(startHandlePoint.y - anchor.y)
                let currentDistY = abs(currentHandlePoint.y - anchor.y)
                
                var k: CGFloat = 1.0
                
                if startDistX > 10 {
                    k = currentDistX / startDistX
                } else if startDistY > 10 {
                    k = currentDistY / startDistY
                }
                
                k = max(0.1, k)
                
                // 3. 实时预览缩放 - 所有选中的图片都会实时预览
                viewModel.multiSelectScaleFactor = k
            }
            .onEnded { value in
                // 4. 提交更改 - 应用到所有选中的图片
                let anchor = viewModel.multiSelectAnchor
                let k = viewModel.multiSelectScaleFactor
                
                for id in viewModel.selectedItemIds {
                    if let index = viewModel.items.firstIndex(where: { $0.id == id }) {
                        // 更新缩放
                        viewModel.items[index].scale *= k
                        
                        // 更新位置 (相对于锚点缩放)
                        let oldX = viewModel.items[index].position.x
                        let oldY = viewModel.items[index].position.y
                        
                        viewModel.items[index].position.x = anchor.x + (oldX - anchor.x) * k
                        viewModel.items[index].position.y = anchor.y + (oldY - anchor.y) * k
                    }
                }
                
                // 重置临时状态
                zoomScale = 1.0
                viewModel.multiSelectScaleFactor = 1.0
                initialSelectionBounds = nil
            }
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
