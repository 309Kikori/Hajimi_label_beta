# MARK: - Imports
# MARK: - 导入模块
import math
from PySide6.QtWidgets import (
    QGraphicsView, QGraphicsPixmapItem, QGraphicsItem, QStyleOptionGraphicsItem,
    QGraphicsScene, QWidget, QVBoxLayout, QPushButton, QHBoxLayout, QFrame, QLabel
)
from PySide6.QtCore import Qt, QPointF, QRectF, Signal, QTimer, QLineF
from PySide6.QtGui import QPixmap, QPainter, QColor, QPen, QBrush, QCursor
from PySide6.QtOpenGLWidgets import QOpenGLWidget
from rectpack import newPacker

from localization import tr

# MARK: - RefItem (Graphics Item)
# MARK: - 图片项（图形元素）
# --- Graphics Item (Ported from HajimiRef) ---
class RefItem(QGraphicsPixmapItem):
    def __init__(self, thumbnail_pixmap, full_path, filename):
        super().__init__(thumbnail_pixmap)
        self.filename = filename
        self.full_path = full_path
        self.thumbnail = thumbnail_pixmap
        self.high_res_pixmap = None
        self.is_high_res = False
        
        self.setFlags(QGraphicsItem.ItemIsMovable | QGraphicsItem.ItemIsSelectable | QGraphicsItem.ItemSendsGeometryChanges)
        self.setTransformationMode(Qt.SmoothTransformation)
        self.setShapeMode(QGraphicsPixmapItem.BoundingRectShape)
        self.setAcceptHoverEvents(True)
        
        # Center the origin
        # 将原点居中
        self.setOffset(-thumbnail_pixmap.width()/2, -thumbnail_pixmap.height()/2)

        # MARK: - Resize State
        # MARK: - 缩放状态
        # Resize state
        # 缩放状态
        self._resize_corner = None
        self._anchor_scene_pos = None
        self._is_resizing = False

    def load_high_res(self):
        if self.is_high_res: return
        # Load full image
        # 加载完整图像
        pix = QPixmap(self.full_path)
        if not pix.isNull():
            self.high_res_pixmap = pix
            self.is_high_res = True
            self.update()

    def unload_high_res(self):
        if not self.is_high_res: return
        self.high_res_pixmap = None
        self.is_high_res = False
        self.update()

    # MARK: - Rendering
    # MARK: - 渲染
    def paint(self, painter, option, widget=None):
        # Custom paint to handle high-res drawing within thumbnail bounds
        # 自定义绘制以处理缩略图边界内的高分辨率绘制
        if self.is_high_res and self.high_res_pixmap:
            # Draw high res pixmap scaled to fit the bounding rect (which is based on thumbnail)
            # 绘制缩放以适应边界矩形（基于缩略图）的高分辨率像素图
            painter.setRenderHint(QPainter.SmoothPixmapTransform)
            painter.drawPixmap(self.boundingRect().toRect(), self.high_res_pixmap)
        else:
            super().paint(painter, option, widget)
        
        # Always draw Filename Label
        # 始终绘制文件名标签
        lod = QStyleOptionGraphicsItem.levelOfDetailFromTransform(painter.worldTransform())
        if lod < 0.00001: lod = 1
        
        painter.setPen(QColor("white"))
        painter.setBrush(QColor(0, 0, 0, 150))
        font = painter.font()
        font.setPixelSize(int(14 / lod))
        painter.setFont(font)
        
        rect = self.boundingRect()
        text_rect = painter.fontMetrics().boundingRect(self.filename)
        text_rect.moveCenter(rect.center().toPoint())
        # Adjust to top
        # 调整到顶部
        text_rect.moveTop(rect.top() - text_rect.height() - 5)
        
        painter.drawRect(text_rect)
        painter.drawText(text_rect, Qt.AlignCenter, self.filename)

        if self.isSelected():
            # Draw selection border
            # 绘制选中边框
            pen = QPen(QColor("#007acc"))
            pen.setWidth(2)
            pen.setCosmetic(True)
            painter.setPen(pen)
            painter.setBrush(Qt.NoBrush)
            
            painter.drawRect(rect)
            
            # Draw handles
            # 绘制手柄
            painter.setBrush(QColor("white"))
            handle_dia = 10 / lod
            radius = handle_dia / 2
            
            corners = [rect.topLeft(), rect.topRight(), rect.bottomLeft(), rect.bottomRight()]
            for corner in corners:
                painter.drawEllipse(corner, radius, radius)

    # MARK: - Event Handling
    # MARK: - 事件处理
    def hoverMoveEvent(self, event):
        if self.isSelected():
            pos = event.pos()
            rect = self.boundingRect()
            views = self.scene().views()
            view_scale = views[0].transform().m11() if views else 1.0
            margin = 20 / (self.scale() * view_scale)
            
            tl, tr, bl, br = rect.topLeft(), rect.topRight(), rect.bottomLeft(), rect.bottomRight()
            
            if (pos - tl).manhattanLength() < margin:
                self.setCursor(Qt.SizeFDiagCursor)
                self._resize_corner = "tl"
            elif (pos - tr).manhattanLength() < margin:
                self.setCursor(Qt.SizeBDiagCursor)
                self._resize_corner = "tr"
            elif (pos - bl).manhattanLength() < margin:
                self.setCursor(Qt.SizeBDiagCursor)
                self._resize_corner = "bl"
            elif (pos - br).manhattanLength() < margin:
                self.setCursor(Qt.SizeFDiagCursor)
                self._resize_corner = "br"
            else:
                self.setCursor(Qt.OpenHandCursor)
                self._resize_corner = None
        else:
            self.setCursor(Qt.OpenHandCursor)
            
        super().hoverMoveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            if self._resize_corner:
                self._is_resizing = True
                self._start_mouse_pos = event.scenePos()
                self._start_scale = self.scale()
                
                selected_items = [item for item in self.scene().selectedItems() if isinstance(item, RefItem)]
                
                if len(selected_items) > 1:
                    # Multi-select: Calculate group bounding box
                    # 多选：计算组边界框
                    group_rect = None
                    for item in selected_items:
                        item_rect = item.sceneBoundingRect()
                        if group_rect is None:
                            group_rect = item_rect
                        else:
                            group_rect = group_rect.united(item_rect)
                    
                    # Determine anchor based on which corner of THIS item is being dragged
                    # The anchor should be the opposite corner of the GROUP bounding box
                    # 根据当前拖动的项目的哪个角来确定锚点
                    # 锚点应该是组边界框的对角
                    if self._resize_corner == "tl":
                        self._anchor_scene = group_rect.bottomRight()
                        self._drag_corner_scene_start = group_rect.topLeft()
                    elif self._resize_corner == "tr":
                        self._anchor_scene = group_rect.bottomLeft()
                        self._drag_corner_scene_start = group_rect.topRight()
                    elif self._resize_corner == "bl":
                        self._anchor_scene = group_rect.topRight()
                        self._drag_corner_scene_start = group_rect.bottomLeft()
                    elif self._resize_corner == "br":
                        self._anchor_scene = group_rect.topLeft()
                        self._drag_corner_scene_start = group_rect.bottomRight()
                else:
                    # Single item: use item's own corners
                    # 单个项目：使用项目自己的角
                    rect = self.boundingRect()
                    if self._resize_corner == "tl":
                        self._anchor_local = rect.bottomRight()
                        self._drag_corner_local = rect.topLeft()
                    elif self._resize_corner == "tr":
                        self._anchor_local = rect.bottomLeft()
                        self._drag_corner_local = rect.topRight()
                    elif self._resize_corner == "bl":
                        self._anchor_local = rect.topRight()
                        self._drag_corner_local = rect.bottomLeft()
                    elif self._resize_corner == "br":
                        self._anchor_local = rect.topLeft()
                        self._drag_corner_local = rect.bottomRight()
                    
                    # Convert to scene coordinates
                    # 转换为场景坐标
                    self._anchor_scene = self.mapToScene(self._anchor_local)
                    self._drag_corner_scene_start = self.mapToScene(self._drag_corner_local)
                
                # Store initial state for all selected items
                # 存储所有选中项目的初始状态
                self._selected_items_state = []
                for item in selected_items:
                    self._selected_items_state.append({
                        'item': item,
                        'start_scale': item.scale(),
                        'start_pos': item.pos()
                    })
                
                event.accept()
                return
            else:
                self.setCursor(Qt.ClosedHandCursor)
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if getattr(self, '_is_resizing', False):
            current_mouse_pos = event.scenePos()
            
            # Calculate scale factor based on the diagonal distance
            # Original diagonal distance (from anchor to drag corner)
            # 基于对角线距离计算缩放因子
            # 原始对角线距离（从锚点到拖动角）
            original_diagonal = QLineF(self._anchor_scene, self._drag_corner_scene_start).length()
            # New diagonal distance (from anchor to current mouse position)
            # 新对角线距离（从锚点到当前鼠标位置）
            new_diagonal = QLineF(self._anchor_scene, current_mouse_pos).length()
            
            if original_diagonal > 1:
                scale_factor = new_diagonal / original_diagonal
                
                # Apply to all selected items
                # 应用于所有选中项目
                if hasattr(self, '_selected_items_state') and len(self._selected_items_state) > 1:
                    # Multi-select: scale all items relative to the anchor of the dragged item
                    # 多选：相对于被拖动项目的锚点缩放所有项目
                    for state in self._selected_items_state:
                        item = state['item']
                        start_scale = state['start_scale']
                        start_pos = state['start_pos']
                        
                        new_scale = start_scale * scale_factor
                        if new_scale < 0.05:
                            new_scale = 0.05
                        
                        item.setScale(new_scale)
                        
                        # Adjust position: items move away/toward anchor proportionally
                        # 调整位置：项目按比例远离/靠近锚点
                        offset = start_pos - self._anchor_scene
                        new_offset = offset * scale_factor
                        item.setPos(self._anchor_scene + new_offset)
                else:
                    # Single item: scale with diagonal anchor locked
                    # 单个项目：锁定对角锚点进行缩放
                    new_scale = self._start_scale * scale_factor
                    
                    # Limit minimum scale
                    # 限制最小缩放
                    if new_scale < 0.05:
                        new_scale = 0.05
                    
                    self.setScale(new_scale)
                    
                    # Keep the anchor point fixed in scene coordinates
                    # 保持锚点在场景坐标中固定
                    new_anchor_scene_current = self.mapToScene(self._anchor_local)
                    diff = self._anchor_scene - new_anchor_scene_current
                    self.setPos(self.pos() + diff)
            
            event.accept()
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        self._is_resizing = False
        self.setCursor(Qt.OpenHandCursor)
        super().mouseReleaseEvent(event)


# MARK: - Overview Canvas
# MARK: - 总览画布
# --- Overview Canvas (Ported from HajimiRef RefView) ---
class OverviewCanvas(QGraphicsView):
    def __init__(self, parent=None, config=None):
        super().__init__(parent)
        self.config = config if config else {}
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        
        # Enable GPU Acceleration
        # 启用 GPU 加速
        self.setViewport(QOpenGLWidget())
        self.setRenderHint(QPainter.Antialiasing)
        self.setRenderHint(QPainter.SmoothPixmapTransform)
        
        # Optimization: SmartViewportUpdate is often better than FullViewportUpdate for large scenes
        # 优化：对于大型场景，SmartViewportUpdate 通常优于 FullViewportUpdate
        self.setViewportUpdateMode(QGraphicsView.SmartViewportUpdate)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setTransformationAnchor(QGraphicsView.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.AnchorUnderMouse)
        self.setDragMode(QGraphicsView.RubberBandDrag)
        
        # Infinite Canvas: Set a massive scene rect
        # 无限画布：设置巨大的场景矩形
        self.scene.setSceneRect(-100000, -100000, 200000, 200000)
        
        # Background handled in drawBackground
        # 背景在 drawBackground 中处理
        
        self._is_panning = False
        self._pan_start = QPointF()
        self._space_pressed = False
        
        # LOD Timer
        # LOD 计时器
        self.lod_timer = QTimer()
        self.lod_timer.setSingleShot(True)
        self.lod_timer.setInterval(200) # 200ms debounce
        self.lod_timer.timeout.connect(self.update_lod)
        
        # Connect scroll bars to LOD update
        # 连接滚动条到 LOD 更新
        self.horizontalScrollBar().valueChanged.connect(self.schedule_lod_update)
        self.verticalScrollBar().valueChanged.connect(self.schedule_lod_update)

    # MARK: - LOD (Level of Detail) Management
    # MARK: - 细节级别管理
    def schedule_lod_update(self):
        self.lod_timer.start()

    def update_lod(self):
        # Calculate visible rect
        # 计算可见矩形
        view_rect = self.mapToScene(self.viewport().rect()).boundingRect()
        scale = self.transform().m11()
        
        # Threshold: If scale > 0.5 (zoomed in), load high res
        # 阈值：如果缩放 > 0.5（放大），加载高分辨率
        should_load_high_res = scale > 0.5
        
        # Iterate all items to manage memory efficiently
        # For typical usage (<1000 items), iterating all items is acceptable.
        # 遍历所有项目以有效管理内存
        # 对于典型用法（<1000 个项目），遍历所有项目是可以接受的。
        all_items = self.scene.items()
        
        for item in all_items:
            if isinstance(item, RefItem):
                if should_load_high_res:
                    # Check if item is visible
                    # 检查项目是否可见
                    if item.sceneBoundingRect().intersects(view_rect):
                        item.load_high_res()
                    else:
                        # Unload if not visible to save memory
                        # 如果不可见则卸载以节省内存
                        if item.is_high_res:
                            item.unload_high_res()
                else:
                    # Zoomed out: Unload everything to save memory
                    # 缩小：卸载所有内容以节省内存
                    if item.is_high_res:
                        item.unload_high_res()

    # MARK: - Background Drawing
    # MARK: - 背景绘制
    def drawBackground(self, painter, rect):
        # Fill background
        # 填充背景
        bg_color = self.config.get("bg_color", "#1e1e1e")
        painter.fillRect(rect, QColor(bg_color))
        
        # Draw Grid/Dots
        # 绘制网格/点
        grid_size = int(self.config.get("grid_size", 40))
        grid_color = QColor(self.config.get("grid_color", "#333333"))
        
        # LOD Check: Don't draw grid if zoomed out too far to prevent lag
        # LOD 检查：如果缩小太远不要绘制网格以防止卡顿
        lod = QStyleOptionGraphicsItem.levelOfDetailFromTransform(painter.worldTransform())
        if lod < 0.2: # If zoomed out to 20% or less, skip grid
            return

        if grid_size > 0:
            left = int(rect.left()) - (int(rect.left()) % grid_size)
            top = int(rect.top()) - (int(rect.top()) % grid_size)
            
            # Limit the number of points drawn
            # 限制绘制的点数
            width = int(rect.width())
            height = int(rect.height())
            
            # If too many points would be drawn, skip or increase step
            # 如果绘制的点太多，跳过或增加步长
            if (width / grid_size) * (height / grid_size) > 10000:
                 grid_size *= 2
            
            points = []
            for x in range(left, int(rect.right()) + grid_size, grid_size):
                for y in range(top, int(rect.bottom()) + grid_size, grid_size):
                    points.append(QPointF(x, y))
            
            painter.setPen(QPen(grid_color, 2))
            painter.drawPoints(points)

    # MARK: - Mouse & Keyboard Events
    # MARK: - 鼠标与键盘事件
    def wheelEvent(self, event):
        # Simple zoom: always zoom the view, not individual items
        # 简单缩放：始终缩放视图，而不是单个项目
        zoom_factor = 1.1 if event.angleDelta().y() > 0 else 0.9
        self.scale(zoom_factor, zoom_factor)
        self.schedule_lod_update()

    def mousePressEvent(self, event):
        if event.button() == Qt.MiddleButton or (event.button() == Qt.LeftButton and self._space_pressed):
            self._is_panning = True
            self._pan_start = event.position()
            self.setCursor(Qt.ClosedHandCursor)
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._is_panning:
            delta = event.position() - self._pan_start
            self._pan_start = event.position()
            hs = self.horizontalScrollBar()
            vs = self.verticalScrollBar()
            hs.setValue(hs.value() - delta.x())
            vs.setValue(vs.value() - delta.y())
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if self._is_panning:
            self._is_panning = False
            self.setCursor(Qt.ArrowCursor)
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Space:
            self._space_pressed = True
            if not self._is_panning:
                self.setCursor(Qt.OpenHandCursor)
        super().keyPressEvent(event)

    def keyReleaseEvent(self, event):
        if event.key() == Qt.Key_Space:
            self._space_pressed = False
            if not self._is_panning:
                self.setCursor(Qt.ArrowCursor)
        super().keyReleaseEvent(event)

    # MARK: - Layout Organization
    # MARK: - 布局组织
    def organize_items(self):
        items = self.scene.items()
        if not items: return

        rects = []
        total_area = 0
        text_padding = 40 # Space for text label above image
        
        for item in items:
            if not isinstance(item, RefItem): continue
            r = item.sceneBoundingRect()
            w = max(1, int(math.ceil(r.width())))
            h = max(1, int(math.ceil(r.height())))
            # Add vertical space for the label so it doesn't get covered
            # 为标签添加垂直空间，以免被覆盖
            rects.append((w, h + text_padding, item))
            total_area += w * (h + text_padding)

        if not rects: return

        # Calculate total area and max dimensions
        # 计算总面积和最大尺寸
        max_w = max(w for w, h, it in rects)
        
        # Estimate a square-ish bin
        # 估计一个近似方形的容器
        approx_side = int(math.ceil(math.sqrt(total_area * 1.2))) # 20% extra space
        bin_width = max(approx_side, max_w)
        # Allow height to grow as needed
        # 允许高度根据需要增长
        bin_height = int(total_area / bin_width * 2) + 2000 

        packer = newPacker()
        packer.add_bin(bin_width, bin_height)
        for w, h, it in rects:
            packer.add_rect(w, h, rid=id(it))
        packer.pack()

        id_map = {id(it): it for _, _, it in rects}
        
        # Center around 0,0
        # 围绕 0,0 居中
        start_x = -bin_width / 2
        start_y = -bin_height / 2

        for bin in packer:
            for rect in bin:
                item = id_map.get(rect.rid)
                if item is None: continue
                
                target_x = start_x + float(rect.x)
                # Offset y by text_padding because the packed rect includes the text space at the top
                # 将 y 偏移 text_padding，因为打包的矩形包含顶部的文本空间
                target_y = start_y + float(rect.y) + text_padding
                
                # Align top-left
                # 左上对齐
                cur_rect = item.sceneBoundingRect()
                cur_tl = cur_rect.topLeft()
                dx = target_x - cur_tl.x()
                dy = target_y - cur_tl.y()
                item.setPos(item.pos() + QPointF(dx, dy))


# MARK: - Overview Page
# MARK: - 总览页面
class OverviewPage(QWidget):
    def __init__(self, parent=None, config=None):
        super().__init__(parent)
        self.config = config
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0,0,0,0)
        self.layout.setSpacing(0)

        # Toolbar
        # 工具栏
        self.toolbar = QFrame()
        self.toolbar.setFixedHeight(40)
        self.toolbar.setStyleSheet("background-color: #252526; border-bottom: 1px solid #333333;")
        self.tb_layout = QHBoxLayout(self.toolbar)
        self.tb_layout.setContentsMargins(10, 0, 10, 0)
        
        self.title = QLabel(tr("overview_title"))
        self.title.setStyleSheet("font-weight: bold; font-size: 14px;")
        self.tb_layout.addWidget(self.title)
        
        self.tb_layout.addStretch()
        
        self.btn_arrange = QPushButton(tr("auto_arrange"))
        self.btn_arrange.setObjectName("ActionButton")
        self.btn_arrange.clicked.connect(self.auto_arrange)
        self.tb_layout.addWidget(self.btn_arrange)

        self.layout.addWidget(self.toolbar)

        # Canvas
        # 画布
        self.canvas = OverviewCanvas(config=self.config)
        self.layout.addWidget(self.canvas)

    def load_images(self, folder_path, files):
        self.canvas.scene.clear()
        import os
        
        count = 0
        for f in files:
            full_path = os.path.join(folder_path, f)
            pixmap = QPixmap(full_path)
            if not pixmap.isNull():
                # Create a thumbnail for initial view and zoomed-out state
                # 为初始视图和缩小状态创建缩略图
                # Use configured max width for the THUMBNAIL
                # 使用配置的缩略图最大宽度
                max_w = int(self.config.get("max_image_width", 1600))
                thumbnail = pixmap
                if max_w > 0 and pixmap.width() > max_w:
                    thumbnail = pixmap.scaledToWidth(max_w, Qt.SmoothTransformation)
                
                # Pass both thumbnail and full path
                # 传递缩略图和完整路径
                item = RefItem(thumbnail, full_path, f)
                import random
                item.setPos(random.randint(-500, 500), random.randint(-500, 500))
                self.canvas.scene.addItem(item)
                count += 1
                if count > 300: break 
        
        self.auto_arrange()

    def update_config(self):
        self.canvas.viewport().update() # Redraw background

    def auto_arrange(self):
        self.canvas.organize_items()
        self.canvas.fitInView(self.canvas.scene.itemsBoundingRect(), Qt.KeepAspectRatio)
