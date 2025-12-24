import Foundation
import SwiftUI
import Combine
import QuickLookThumbnailing

struct OverviewItem: Identifiable, Equatable {
    let id = UUID()
    let fileURL: URL
    var position: CGPoint = .zero
    var size: CGSize = CGSize(width: 200, height: 200) // Default placeholder size
    var scale: CGFloat = 1.0 // Individual item scale
    var thumbnail: NSImage?
    
    // [性能优化] 自定义 Equatable，只比较影响布局的属性，忽略 NSImage 的指针比较
    static func == (lhs: OverviewItem, rhs: OverviewItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.position == rhs.position &&
        lhs.size == rhs.size &&
        lhs.scale == rhs.scale &&
        (lhs.thumbnail != nil) == (rhs.thumbnail != nil)
    }
}

class OverviewViewModel: ObservableObject {
    @Published var items: [OverviewItem] = []
    @Published var isLoading: Bool = false
    
    // Canvas State
    @Published var canvasOffset: CGSize = .zero
    @Published var canvasScale: CGFloat = 1.0
    @Published var selectedItemIds: Set<UUID> = []
    
    // [交互状态] 多选拖拽支持 - 完全模仿 HajimiRef
    @Published var currentDragOffset: CGSize = .zero
    
    // [交互状态] 多选缩放因子和锚点
    @Published var multiSelectScaleFactor: CGFloat = 1.0
    @Published var multiSelectAnchor: CGPoint = .zero
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Selection Helpers (from HajimiRef)
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
    
    // [性能优化] 视图剔除：计算可见区域内的项目
    func visibleItems(in viewportSize: CGSize) -> [OverviewItem] {
        // 如果图片数量少，直接返回全部，跳过剔除
        guard items.count > 50 else { return items }
        
        // 计算可见区域（屏幕空间 -> 世界空间）
        // marginRatio 是相对于视口尺寸的外扩比例，防止边缘图片突然出现/消失
        let marginRatio: CGFloat = 0.5 // 外扩50%的视口尺寸（相对边距）
        
        // 屏幕中心在世界坐标系中的位置
        // 公式：World = (Screen - Center) / Scale - Offset
        // 屏幕中心 Screen = Center，所以 World = 0 / Scale - Offset = -Offset
        let centerX = -canvasOffset.width
        let centerY = -canvasOffset.height
        
        // 屏幕可见区域的半宽和半高（世界空间）
        let halfWidth = viewportSize.width / 2 / canvasScale
        let halfHeight = viewportSize.height / 2 / canvasScale
        
        // 加上相对外扩边距（基于视口尺寸）
        let marginWidth = halfWidth * marginRatio
        let marginHeight = halfHeight * marginRatio
        let minX = centerX - halfWidth - marginWidth
        let maxX = centerX + halfWidth + marginWidth
        let minY = centerY - halfHeight - marginHeight
        let maxY = centerY + halfHeight + marginHeight
        
        return items.filter { item in
            let itemHalfSize = max(item.size.width, item.size.height) * item.scale / 2
            return item.position.x + itemHalfSize >= minX &&
                   item.position.x - itemHalfSize <= maxX &&
                   item.position.y + itemHalfSize >= minY &&
                   item.position.y - itemHalfSize <= maxY
        }
    }
    
    func loadImages(from files: [URL]) {
        self.items = []
        self.isLoading = true
        
        // Limit to 300 for performance, similar to Windows version
        let filesToLoad = Array(files.prefix(300))
        
        DispatchQueue.global(qos: .userInitiated).async {
            let newItems = filesToLoad.map { url -> OverviewItem in
                // Initial random position
                let randomX = CGFloat.random(in: -500...500)
                let randomY = CGFloat.random(in: -500...500)
                return OverviewItem(fileURL: url, position: CGPoint(x: randomX, y: randomY))
            }
            
            DispatchQueue.main.async {
                self.items = newItems
                self.generateThumbnails()
                self.autoArrange() // Auto arrange on load
                self.isLoading = false
            }
        }
    }
    
    func generateThumbnails() {
        let generator = QLThumbnailGenerator.shared
        // [高清支持] 使用更大的尺寸和2x scale支持Retina屏幕放大后依然清晰
        let size = CGSize(width: 800, height: 800) // Max thumbnail size
        
        // Capture the current items' IDs to ensure we update the correct ones
        let currentItems = items
        
        // [性能优化] 批量更新缩略图，减少 UI 重绘频率
        let updateLock = NSLock()
        var pendingUpdates: [(UUID, NSImage, CGSize)] = []
        var completedCount = 0
        let batchSize = 15 // 每批更新的数量
        
        for item in currentItems {
            let url = item.fileURL
            let id = item.id
            // [高清支持] scale设为2.0以获取Retina分辨率的缩略图
            let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 2.0, representationTypes: .thumbnail)
            
            generator.generateBestRepresentation(for: request) { (thumbnail, error) in
                if let thumbnail = thumbnail {
                    let aspectRatio = thumbnail.nsImage.size.width / thumbnail.nsImage.size.height
                    let itemSize: CGSize
                    if aspectRatio > 1 {
                        itemSize = CGSize(width: 200, height: 200 / aspectRatio)
                    } else {
                        itemSize = CGSize(width: 200 * aspectRatio, height: 200)
                    }
                    
                    updateLock.lock()
                    pendingUpdates.append((id, thumbnail.nsImage, itemSize))
                    completedCount += 1
                    let shouldUpdate = completedCount % batchSize == 0 || completedCount == currentItems.count
                    let updates = shouldUpdate ? pendingUpdates : []
                    if shouldUpdate { pendingUpdates.removeAll() }
                    updateLock.unlock()
                    
                    if shouldUpdate {
                        DispatchQueue.main.async {
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
    
    func autoArrange() {
        // Simple Shelf Algorithm - 完全照抄 HajimiRef 的坐标系
        // 图片坐标从 (0, 0) 开始，和 HajimiRef 一样
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        let gap: CGFloat = 20
        let maxWidth: CGFloat = 2000 // Virtual width for the layout
        
        var updatedItems = items
        
        for i in 0..<updatedItems.count {
            let item = updatedItems[i]
            
            if currentX + item.size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + gap + 40 // +40 for text label space
                rowHeight = 0
            }
            
            // .position() 把视图中心放到指定坐标
            // 所以要让左上角对齐到 (currentX, currentY)，需要加上 size/2
            updatedItems[i].position = CGPoint(
                x: currentX + item.size.width / 2,
                y: currentY + item.size.height / 2
            )
            
            currentX += item.size.width + gap
            rowHeight = max(rowHeight, item.size.height)
        }
        
        // 计算集群边界和中心 (和 HajimiRef 一样)
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        
        for item in updatedItems {
            let w = item.size.width * item.scale
            let h = item.size.height * item.scale
            
            let left = item.position.x - w/2
            let right = item.position.x + w/2
            let top = item.position.y - h/2
            let bottom = item.position.y + h/2
            
            if left < minX { minX = left }
            if right > maxX { maxX = right }
            if top < minY { minY = top }
            if bottom > maxY { maxY = bottom }
        }
        
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        // 设置 canvasOffset 使集群中心显示在屏幕中心 (和 HajimiRef 一样)
        canvasOffset = CGSize(width: -centerX, height: -centerY)
        
        self.items = updatedItems
    }
    
    func updatePosition(for id: UUID, newPosition: CGPoint) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].position = newPosition
        }
    }
}
