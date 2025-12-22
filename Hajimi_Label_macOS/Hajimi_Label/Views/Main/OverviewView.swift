import SwiftUI

// MARK: - Resize Handle
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
                            OverviewItemView(
                                item: item,
                                status: appModel.results[item.fileURL.lastPathComponent],
                                isSelected: viewModel.selectedItemIds.contains(item.id),
                                canvasScale: viewModel.canvasScale,
                                onDragEnd: { offset in
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
                            .scaleEffect(item.scale) // Apply individual item scale
                            .onTapGesture {
                                viewModel.selectedItemIds = [item.id]
                            }
                            .onTapGesture(count: 2) {
                                appModel.selectedFile = item.fileURL
                                appModel.activeTab = .review
                            }
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

struct OverviewItemView: View {
    let item: OverviewItem
    let status: String?
    let isSelected: Bool
    let canvasScale: CGFloat
    var onDragEnd: ((CGSize) -> Void)?
    var onScaleChange: ((CGFloat) -> Void)?
    
    @State private var dragOffset: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    
    // [性能优化] 缓存状态颜色计算
    private var cachedStatusColor: Color {
        guard let status = status else { return .gray }
        return statusColor(status)
    }
    
    // [视觉设计] 恒定屏幕空间手柄大小
    private var handleSize: CGFloat {
        12.0 / (item.scale * canvasScale)
    }
    
    private var borderWidth: CGFloat {
        3.0 / (item.scale * canvasScale)
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
                    .aspectRatio(contentMode: .fit)
                    .frame(width: item.size.width, height: item.size.height)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
                    .shadow(radius: isSelected ? 4 : 2)
                    .overlay(
                        ZStack {
                            // 选中边框
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isSelected ? borderWidth : 0)
                            
                            // 调整手柄（只在选中时显示）
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
        .drawingGroup() // [GPU 加速] 在单个项目级别应用，不影响手势坐标系
        .scaleEffect(zoomScale) // 应用触控板缩放的临时状态
        .offset(dragOffset)
        .gesture(
            SimultaneousGesture(
                // 拖拽移动
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
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
                // 触控板双指缩放
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
    
    // [交互逻辑] 调整手柄拖拽手势
    private func resizeGesture(corner: ResizeCorner) -> some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                // 拖拽手柄时的视觉反馈可以在这里实现
                // 为简化，我们直接在 onEnded 时处理
            }
            .onEnded { value in
                // 计算缩放因子
                let delta = value.translation
                let originalSize = item.size
                
                // 根据角落计算缩放变化
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
