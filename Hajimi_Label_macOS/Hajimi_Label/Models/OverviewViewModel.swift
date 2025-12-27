//
//  OverviewViewModel.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import Foundation
import SwiftUI
import Combine
import QuickLookThumbnailing

// MARK: - Overview Item Model
// MARK: - 概览项目模型

/// Represents a single item (image) on the overview canvas.
/// Conforms to Identifiable for SwiftUI lists and Equatable for diffing.
///
/// 表示概览画布上的单个项目（图片）。
/// 遵循 Identifiable 协议以用于 SwiftUI 列表，遵循 Equatable 协议以用于差异比较。
struct OverviewItem: Identifiable, Equatable {
    let id = UUID()
    let fileURL: URL
    
    /// Position on the infinite canvas.
    /// 画布上的位置。
    var position: CGPoint = .zero
    
    /// Size of the item. Defaults to a placeholder size.
    /// 项目的大小。默认为占位符大小。
    var size: CGSize = CGSize(width: 200, height: 200)
    
    /// Individual scale factor for the item (currently unused, but reserved for future features).
    /// 项目的单独缩放因子（目前未使用，但为未来功能保留）。
    var scale: CGFloat = 1.0
    
    /// The generated thumbnail image.
    /// 生成的缩略图图像。
    var thumbnail: NSImage?
    
    /// Whether the image is loaded in high resolution.
    /// 图像是否已加载为高分辨率。
    var isHighRes: Bool = false
    
    // MARK: - Performance Optimization
    // MARK: - 性能优化
    
    /// Custom Equatable implementation.
    /// Only compares properties that affect layout and rendering.
    /// Crucially, it ignores the `NSImage` pointer comparison which can be expensive or misleading if the image object regenerates.
    ///
    /// 自定义 Equatable 实现。
    /// 只比较影响布局和渲染的属性。
    /// 关键在于，它忽略了 NSImage 指针比较，因为如果图像对象重新生成，指针比较可能会很昂贵或产生误导。
    static func == (lhs: OverviewItem, rhs: OverviewItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.position == rhs.position &&
        lhs.size == rhs.size &&
        lhs.scale == rhs.scale &&
        (lhs.thumbnail != nil) == (rhs.thumbnail != nil) && // Only compare existence, not content (只比较是否存在，不比较内容)
        lhs.isHighRes == rhs.isHighRes
    }
}

// MARK: - Overview View Model
// MARK: - 概览视图模型

/// View model for the Overview mode.
/// Manages the state of the infinite canvas, including item positions, selection, and thumbnail generation.
///
/// 概览模式的视图模型。
/// 管理无限画布的状态，包括项目位置、选择和缩略图生成。
class OverviewViewModel: ObservableObject {
    /// All items on the canvas.
    /// 画布上的所有项目。
    @Published var items: [OverviewItem] = []
    
    /// Loading state indicator.
    /// 加载状态指示器。
    @Published var isLoading: Bool = false
    
    // MARK: - Canvas State
    // MARK: - 画布状态
    
    /// Current offset of the canvas (panning).
    /// 画布的当前偏移量（平移）。
    @Published var canvasOffset: CGSize = .zero
    
    /// Current zoom scale of the canvas.
    /// 画布的当前缩放比例。
    @Published var canvasScale: CGFloat = 1.0
    
    /// Set of selected item IDs.
    /// 选定项目 ID 的集合。
    @Published var selectedItemIds: Set<UUID> = []
    
    // MARK: - Interaction State
    // MARK: - 交互状态
    
    /// Temporary drag offset during interaction.
    /// 交互过程中的临时拖动偏移量。
    @Published var currentDragOffset: CGSize = .zero
    
    // [Interaction State] Multi-selection scale factor and anchor point.
    // [交互状态] 多选缩放因子和锚点。
    @Published var multiSelectScaleFactor: CGFloat = 1.0
    @Published var multiSelectAnchor: CGPoint = .zero
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Selection Helpers (from HajimiRef)
    // MARK: - 选择辅助方法 (来自 HajimiRef)
    
    func calculateSelectionBounds() -> CGRect? {
        let selectedItems = items.filter { selectedItemIds.contains($0.id) }
        guard !selectedItems.isEmpty else { return nil }
        
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        
        for item in selectedItems {
            let w = item.size.width * item.scale
            let h = item.size.height * item.scale
            
            // 考虑当前的拖拽偏移
            let posX = item.position.x + currentDragOffset.width
            let posY = item.position.y + currentDragOffset.height
            
            let left = posX - w/2
            let right = posX + w/2
            let top = posY - h/2
            let bottom = posY + h/2
            
            if left < minX { minX = left }
            if right > maxX { maxX = right }
            if top < minY { minY = top }
            if bottom > maxY { maxY = bottom }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // MARK: - View Culling (Performance Optimization)
    // MARK: - 视图剔除（性能优化）
    
    /// Calculates which items are currently visible in the viewport.
    /// This is a classic "Frustum Culling" technique used in game development and graphics.
    /// By only rendering visible items, we significantly reduce the load on the SwiftUI layout engine.
    ///
    /// 计算当前视口中可见的项目。
    /// 这是游戏开发和图形学中经典的“视锥体剔除”技术。
    /// 通过仅渲染可见项目，我们显著减轻了 SwiftUI 布局引擎的负载。
    ///
    /// - Parameter viewportSize: The size of the visible area. (可见区域的大小)
    /// - Returns: An array of items that intersect with the viewport. (与视口相交的项目数组)
    func visibleItems(in viewportSize: CGSize) -> [OverviewItem] {
        // Calculate visible area in World Space (coordinate system of the items).
        // Formula: World = (Screen - Center) / Scale - Offset
        //
        // 计算世界空间（项目的坐标系）中的可见区域。
        // 公式：世界坐标 = (屏幕坐标 - 中心) / 缩放比例 - 偏移量
        
        let margin: CGFloat = 600 // Extra margin to prevent items from "popping" in at the edges. (额外边距，防止项目在边缘突然出现)
        
        // Screen bounds (0,0 to W,H)
        let screenMinX: CGFloat = -margin
        let screenMinY: CGFloat = -margin
        let screenMaxX: CGFloat = viewportSize.width + margin
        let screenMaxY: CGFloat = viewportSize.height + margin
        
        // Convert to World Space
        // World = (Screen - Center) / Scale - Offset
        let centerX = viewportSize.width / 2
        let centerY = viewportSize.height / 2
        
        let minX = (screenMinX - centerX) / canvasScale - canvasOffset.width
        let maxX = (screenMaxX - centerX) / canvasScale - canvasOffset.width
        let minY = (screenMinY - centerY) / canvasScale - canvasOffset.height
        let maxY = (screenMaxY - centerY) / canvasScale - canvasOffset.height
        
        // Filter items based on bounding box intersection.
        // 基于边界框相交过滤项目。
        return items.filter { item in
            let itemHalfWidth = item.size.width * item.scale / 2
            let itemHalfHeight = item.size.height * item.scale / 2
            
            return item.position.x + itemHalfWidth >= minX &&
                   item.position.x - itemHalfWidth <= maxX &&
                   item.position.y + itemHalfHeight >= minY &&
                   item.position.y - itemHalfHeight <= maxY
        }
    }
    
    /// Loads images from a list of URLs and initializes them on the canvas.
    ///
    /// 从 URL 列表加载图像并在画布上初始化它们。
    func loadImages(from files: [URL]) {
        self.items = []
        self.isLoading = true
        
        // Limit to 300 for performance, similar to Windows version.
        // Ideally, this should be handled by dynamic loading / pagination.
        //
        // 为了性能限制为 300 个，类似于 Windows 版本。
        // 理想情况下，这应该由动态加载/分页处理。
        let filesToLoad = Array(files.prefix(300))
        
        // Perform heavy lifting on a background thread.
        // 在后台线程上执行繁重的工作。
        DispatchQueue.global(qos: .userInitiated).async {
            let newItems = filesToLoad.map { url -> OverviewItem in
                // Initial random position to avoid stacking all items at (0,0).
                // 初始随机位置，避免所有项目堆叠在 (0,0)。
                let randomX = CGFloat.random(in: -500...500)
                let randomY = CGFloat.random(in: -500...500)
                return OverviewItem(fileURL: url, position: CGPoint(x: randomX, y: randomY))
            }
            
            // Update UI on main thread.
            // 在主线程上更新 UI。
            DispatchQueue.main.async {
                self.items = newItems
                self.generateThumbnails()
                self.autoArrange() // Auto arrange on load for a clean start. (加载时自动排列，以便有一个整洁的开始)
                self.isLoading = false
            }
        }
    }
    
    /// Generates thumbnails for all items using QuickLookThumbnailing.
    /// This process is asynchronous and batched to maintain UI responsiveness.
    ///
    /// 使用 QuickLookThumbnailing 为所有项目生成缩略图。
    /// 此过程是异步和分批的，以保持 UI 响应能力。
    func generateThumbnails() {
        let generator = QLThumbnailGenerator.shared
        let size = CGSize(width: 300, height: 300) // Max thumbnail size request. (最大缩略图尺寸请求)
        
        // Capture the current items' IDs to ensure we update the correct ones even if the array changes.
        // 捕获当前项目的 ID，以确保即使数组发生变化，我们也更新正确的项目。
        let currentItems = items
        
        // [Performance Optimization] Batch UI updates.
        // Updating @Published `items` triggers a full view re-evaluation.
        // Doing this for every single thumbnail would freeze the UI.
        // Instead, we collect updates and apply them in batches.
        //
        // [性能优化] 批量 UI 更新。
        // 更新 @Published `items` 会触发完整的视图重新评估。
        // 对每个缩略图都这样做会冻结 UI。
        // 相反，我们收集更新并分批应用它们。
        let updateLock = NSLock()
        var pendingUpdates: [(UUID, NSImage, CGSize)] = []
        var completedCount = 0
        let batchSize = 15 // Number of thumbnails to process before updating UI. (更新 UI 前处理的缩略图数量)
        
        for item in currentItems {
            let url = item.fileURL
            let id = item.id
            let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 1.0, representationTypes: .thumbnail)
            
            generator.generateBestRepresentation(for: request) { (thumbnail, error) in
                if let thumbnail = thumbnail {
                    // Calculate aspect ratio to maintain image proportions.
                    // 计算纵横比以保持图像比例。
                    let aspectRatio = thumbnail.nsImage.size.width / thumbnail.nsImage.size.height
                    let itemSize: CGSize
                    if aspectRatio > 1 {
                        itemSize = CGSize(width: 200, height: 200 / aspectRatio)
                    } else {
                        itemSize = CGSize(width: 200 * aspectRatio, height: 200)
                    }
                    
                    // Thread-safe access to the pending updates list.
                    // 对待处理更新列表的线程安全访问。
                    updateLock.lock()
                    pendingUpdates.append((id, thumbnail.nsImage, itemSize))
                    completedCount += 1
                    
                    // Check if we should flush the batch.
                    // 检查是否应该刷新批次。
                    let shouldUpdate = completedCount % batchSize == 0 || completedCount == currentItems.count
                    let updates = shouldUpdate ? pendingUpdates : []
                    if shouldUpdate { pendingUpdates.removeAll() }
                    updateLock.unlock()
                    
                    if shouldUpdate {
                        DispatchQueue.main.async {
                            // Apply the batch of updates.
                            // 应用批次更新。
                            for (updateId, image, updateSize) in updates {
                                if let index = self.items.firstIndex(where: { $0.id == updateId }) {
                                    self.items[index].thumbnail = image
                                    self.items[index].size = updateSize
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Automatically arranges items in a grid/shelf layout.
    ///
    /// 自动将项目排列在网格/架子布局中。
    func autoArrange() {
        // Simple Shelf Algorithm (Bin Packing variant).
        // Items are placed in rows. When a row is full, a new row starts.
        //
        // 简单的架子算法（装箱算法变体）。
        // 项目被放置在行中。当一行满时，开始新的一行。
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        let gap: CGFloat = 20
        let maxWidth: CGFloat = 2000 // Virtual width for the layout. (布局的虚拟宽度)
        
        // Track actual content bounds for centering
        var actualMaxX: CGFloat = 0
        
        // Create a copy to modify.
        // 创建副本以进行修改。
        var updatedItems = items
        
        for i in 0..<updatedItems.count {
            let item = updatedItems[i]
            
            // Check if item fits in current row.
            // 检查项目是否适合当前行。
            if currentX + item.size.width > maxWidth {
                // Move to next row.
                // 移动到下一行。
                currentX = 0
                currentY += rowHeight + gap + 40 // +40 for text label space. (+40 用于文本标签空间)
                rowHeight = 0
            }
            
            updatedItems[i].position = CGPoint(x: currentX, y: currentY)
            
            // Advance X position.
            // 前进 X 位置。
            currentX += item.size.width + gap
            rowHeight = max(rowHeight, item.size.height)
            
            // Update bounds
            if currentX > actualMaxX {
                actualMaxX = currentX
            }
        }
        
        // Center the whole cluster around (0,0).
        // 将整个集群以 (0,0) 为中心对齐。
        let totalHeight = currentY + rowHeight
        // Use actual width for centering, not the virtual maxWidth
        let offsetX = actualMaxX / 2
        let offsetY = totalHeight / 2
        
        for i in 0..<updatedItems.count {
            updatedItems[i].position.x -= offsetX
            updatedItems[i].position.y -= offsetY
        }
        
        self.items = updatedItems
    }
    
    /// Updates the position of a specific item.
    ///
    /// 更新特定项目的位置。
    func updatePosition(for id: UUID, newPosition: CGPoint) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].position = newPosition
        }
    }
    
    // MARK: - High Resolution Loading
    // MARK: - 高分辨率加载
    
    /// Checks visible items and loads high-resolution images if the count is small (<= 5).
    ///
    /// 检查可见项目，如果数量较少（<= 5），则加载高分辨率图像。
    func checkAndLoadHighRes(viewportSize: CGSize) {
        let visible = visibleItems(in: viewportSize)
        
        // If visible items are few, load high res.
        // 如果可见项目很少，加载高分辨率。
        if visible.count <= 5 {
            for item in visible {
                if !item.isHighRes {
                    loadHighRes(for: item.id)
                }
            }
        }
    }
    
    /// Loads the full resolution image for a specific item.
    ///
    /// 为特定项目加载全分辨率图像。
    func loadHighRes(for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        
        // Avoid reloading if already high res.
        // 如果已经是高分辨率，避免重新加载。
        if item.isHighRes { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOf: item.fileURL) {
                DispatchQueue.main.async {
                    if let idx = self.items.firstIndex(where: { $0.id == id }) {
                        self.items[idx].thumbnail = image
                        self.items[idx].isHighRes = true
                        // Update size if needed, but usually we keep the layout size.
                        // However, if the thumbnail aspect ratio was wrong, we might want to update it.
                        // But for now, let's assume thumbnail AR was correct.
                    }
                }
            }
        }
    }
}
