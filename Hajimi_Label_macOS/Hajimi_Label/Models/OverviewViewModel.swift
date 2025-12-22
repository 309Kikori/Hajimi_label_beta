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
    
    // Interaction State
    @Published var currentDragOffset: CGSize = .zero
    
    private var cancellables = Set<AnyCancellable>()
    
    // [性能优化] 视图剔除：计算可见区域内的项目
    func visibleItems(in viewportSize: CGSize) -> [OverviewItem] {
        // 计算可见区域（屏幕空间 -> 世界空间）
        // 世界坐标 = (屏幕坐标 - offset) / scale
        let margin: CGFloat = 600 // 额外边距，确保边缘项目不会突然出现/消失
        
        // 屏幕中心在世界坐标系中的位置
        let centerX = -canvasOffset.width
        let centerY = -canvasOffset.height
        
        // 可见区域的半宽和半高（世界空间）
        let halfWidth = (viewportSize.width / 2 + margin) / canvasScale
        let halfHeight = (viewportSize.height / 2 + margin) / canvasScale
        
        let minX = centerX - halfWidth
        let maxX = centerX + halfWidth
        let minY = centerY - halfHeight
        let maxY = centerY + halfHeight
        
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
        let size = CGSize(width: 300, height: 300) // Max thumbnail size
        
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
            let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 1.0, representationTypes: .thumbnail)
            
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
        // Simple Shelf Algorithm
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        let gap: CGFloat = 20
        let maxWidth: CGFloat = 2000 // Virtual width for the layout
        
        // Sort items by name to keep order
        // items.sort { $0.fileURL.lastPathComponent < $1.fileURL.lastPathComponent }
        // Actually, let's keep the order from the file list
        
        var updatedItems = items
        
        for i in 0..<updatedItems.count {
            let item = updatedItems[i]
            
            if currentX + item.size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + gap + 40 // +40 for text label space
                rowHeight = 0
            }
            
            updatedItems[i].position = CGPoint(x: currentX, y: currentY)
            
            currentX += item.size.width + gap
            rowHeight = max(rowHeight, item.size.height)
        }
        
        // Center the whole cluster
        let totalHeight = currentY + rowHeight
        let offsetX = maxWidth / 2
        let offsetY = totalHeight / 2
        
        for i in 0..<updatedItems.count {
            updatedItems[i].position.x -= offsetX
            updatedItems[i].position.y -= offsetY
        }
        
        self.items = updatedItems
    }
    
    func updatePosition(for id: UUID, newPosition: CGPoint) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].position = newPosition
        }
    }
}
