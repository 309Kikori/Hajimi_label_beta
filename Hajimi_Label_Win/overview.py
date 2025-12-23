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
        self.setOffset(-thumbnail_pixmap.width()/2, -thumbnail_pixmap.height()/2)

        # Resize state
        self._resize_corner = None
        self._anchor_scene_pos = None
        self._is_resizing = False

    def load_high_res(self):
        if self.is_high_res: return
        # Load full image
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

    def paint(self, painter, option, widget=None):
        # Custom paint to handle high-res drawing within thumbnail bounds
        if self.is_high_res and self.high_res_pixmap:
            # Draw high res pixmap scaled to fit the bounding rect (which is based on thumbnail)
            painter.setRenderHint(QPainter.SmoothPixmapTransform)
            painter.drawPixmap(self.boundingRect().toRect(), self.high_res_pixmap)
        else:
            super().paint(painter, option, widget)
        
        # Always draw Filename Label
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
        text_rect.moveTop(rect.top() - text_rect.height() - 5)
        
        painter.drawRect(text_rect)
        painter.drawText(text_rect, Qt.AlignCenter, self.filename)

        if self.isSelected():
            # Draw selection border
            pen = QPen(QColor("#007acc"))
            pen.setWidth(2)
            pen.setCosmetic(True)
            painter.setPen(pen)
            painter.setBrush(Qt.NoBrush)
            
            painter.drawRect(rect)
            
            # Draw handles
            painter.setBrush(QColor("white"))
            handle_dia = 10 / lod
            radius = handle_dia / 2
            
            corners = [rect.topLeft(), rect.topRight(), rect.bottomLeft(), rect.bottomRight()]
            for corner in corners:
                painter.drawEllipse(corner, radius, radius)

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
                
                # Determine anchor point (opposite to resize corner)
                rect = self.boundingRect()
                if self._resize_corner == "tl":
                    self._anchor_local = rect.bottomRight()
                elif self._resize_corner == "tr":
                    self._anchor_local = rect.bottomLeft()
                elif self._resize_corner == "bl":
                    self._anchor_local = rect.topRight()
                elif self._resize_corner == "br":
                    self._anchor_local = rect.topLeft()
                
                self._anchor_scene = self.mapToScene(self._anchor_local)
                
                event.accept()
                return
            else:
                self.setCursor(Qt.ClosedHandCursor)
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if getattr(self, '_is_resizing', False):
            current_pos = event.scenePos()
            
            # Calculate scale factor based on distance from anchor
            start_dist = QLineF(self._anchor_scene, self._start_mouse_pos).length()
            current_dist = QLineF(self._anchor_scene, current_pos).length()
            
            if start_dist > 1: 
                scale_factor = current_dist / start_dist
                new_scale = self._start_scale * scale_factor
                
                # Limit minimum scale
                if new_scale < 0.05: new_scale = 0.05
                
                self.setScale(new_scale)
                
                # Compensate position to keep anchor fixed
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


# --- Overview Canvas (Ported from HajimiRef RefView) ---
class OverviewCanvas(QGraphicsView):
    def __init__(self, parent=None, config=None):
        super().__init__(parent)
        self.config = config if config else {}
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        
        # Enable GPU Acceleration
        self.setViewport(QOpenGLWidget())
        self.setRenderHint(QPainter.Antialiasing)
        self.setRenderHint(QPainter.SmoothPixmapTransform)
        
        # Optimization: SmartViewportUpdate is often better than FullViewportUpdate for large scenes
        self.setViewportUpdateMode(QGraphicsView.SmartViewportUpdate)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setTransformationAnchor(QGraphicsView.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.AnchorUnderMouse)
        self.setDragMode(QGraphicsView.RubberBandDrag)
        
        # Infinite Canvas: Set a massive scene rect
        self.scene.setSceneRect(-100000, -100000, 200000, 200000)
        
        # Background handled in drawBackground
        
        self._is_panning = False
        self._pan_start = QPointF()
        self._space_pressed = False
        
        # LOD Timer
        self.lod_timer = QTimer()
        self.lod_timer.setSingleShot(True)
        self.lod_timer.setInterval(200) # 200ms debounce
        self.lod_timer.timeout.connect(self.update_lod)
        
        # Connect scroll bars to LOD update
        self.horizontalScrollBar().valueChanged.connect(self.schedule_lod_update)
        self.verticalScrollBar().valueChanged.connect(self.schedule_lod_update)

    def schedule_lod_update(self):
        self.lod_timer.start()

    def update_lod(self):
        # Calculate visible rect
        view_rect = self.mapToScene(self.viewport().rect()).boundingRect()
        scale = self.transform().m11()
        
        # Threshold: If scale > 0.5 (zoomed in), load high res
        should_load_high_res = scale > 0.5
        
        items = self.scene.items(view_rect)
        
        # Unload invisible items first (simple approach: iterate all items in scene? No, too slow)
        # Better: Keep track of loaded items? 
        # For now, let's just iterate visible items and load them if needed.
        # Unloading invisible ones is tricky without a list.
        # Let's iterate all RefItems in scene if count is manageable (<1000)
        # Or just rely on visible items logic.
        
        # Optimization: Only iterate visible items to LOAD.
        # To UNLOAD, we need to know which ones are loaded.
        # Let's add a static list to RefItem or manage it here.
        
        # Let's just iterate visible items for now.
        for item in items:
            if isinstance(item, RefItem):
                if should_load_high_res:
                    item.load_high_res()
                else:
                    item.unload_high_res()
        
        # To properly unload invisible items that were previously loaded:
        # We can iterate scene.items() but that might be slow.
        # A better way is to have a set of 'high_res_items' in the scene or view.
        # But for < 500 items, iterating scene.items() is fast enough.
        if should_load_high_res:
             # If we are zoomed in, we might have panned away from some high-res items.
             # We should unload them to save memory.
             all_items = self.scene.items()
             for item in all_items:
                 if isinstance(item, RefItem) and item.is_high_res:
                     if not item.collidesWithItem(self.scene.itemAt(view_rect.center(), self.transform())): # Rough check? No.
                        # Check intersection with view_rect
                        if not item.sceneBoundingRect().intersects(view_rect):
                            item.unload_high_res()

    def drawBackground(self, painter, rect):
        # Fill background
        bg_color = self.config.get("bg_color", "#1e1e1e")
        painter.fillRect(rect, QColor(bg_color))
        
        # Draw Grid/Dots
        grid_size = int(self.config.get("grid_size", 40))
        grid_color = QColor(self.config.get("grid_color", "#333333"))
        
        # LOD Check: Don't draw grid if zoomed out too far to prevent lag
        lod = QStyleOptionGraphicsItem.levelOfDetailFromTransform(painter.worldTransform())
        if lod < 0.2: # If zoomed out to 20% or less, skip grid
            return

        if grid_size > 0:
            # Optimize: Use drawLines instead of drawPoints for better performance
            # Or even better, use a larger step if zoomed out
            
            left = int(rect.left()) - (int(rect.left()) % grid_size)
            top = int(rect.top()) - (int(rect.top()) % grid_size)
            
            # Limit the number of points drawn
            width = int(rect.width())
            height = int(rect.height())
            
            # If too many points would be drawn, skip or increase step
            if (width / grid_size) * (height / grid_size) > 10000:
                 grid_size *= 2
            
            points = []
            for x in range(left, int(rect.right()) + grid_size, grid_size):
                for y in range(top, int(rect.bottom()) + grid_size, grid_size):
                    points.append(QPointF(x, y))
            
            painter.setPen(QPen(grid_color, 2))
            painter.drawPoints(points)

    def wheelEvent(self, event):
        if event.modifiers() & Qt.ControlModifier:
            items = self.scene.selectedItems()
            if items:
                factor = 1.1 if event.angleDelta().y() > 0 else 0.9
                for item in items:
                    item.setScale(item.scale() * factor)
            return

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
            rects.append((w, h + text_padding, item))
            total_area += w * (h + text_padding)

        if not rects: return

        # Calculate total area and max dimensions
        max_w = max(w for w, h, it in rects)
        
        # Estimate a square-ish bin
        approx_side = int(math.ceil(math.sqrt(total_area * 1.2))) # 20% extra space
        bin_width = max(approx_side, max_w)
        # Allow height to grow as needed
        bin_height = int(total_area / bin_width * 2) + 2000 

        packer = newPacker()
        packer.add_bin(bin_width, bin_height)
        for w, h, it in rects:
            packer.add_rect(w, h, rid=id(it))
        packer.pack()

        id_map = {id(it): it for _, _, it in rects}
        
        # Center around 0,0
        start_x = -bin_width / 2
        start_y = -bin_height / 2

        for bin in packer:
            for rect in bin:
                item = id_map.get(rect.rid)
                if item is None: continue
                
                target_x = start_x + float(rect.x)
                # Offset y by text_padding because the packed rect includes the text space at the top
                target_y = start_y + float(rect.y) + text_padding
                
                # Align top-left
                cur_rect = item.sceneBoundingRect()
                cur_tl = cur_rect.topLeft()
                dx = target_x - cur_tl.x()
                dy = target_y - cur_tl.y()
                item.setPos(item.pos() + QPointF(dx, dy))
        
        # Ensure scene rect is large enough (infinite canvas feel)
        # self.scene.setSceneRect(self.scene.itemsBoundingRect().adjusted(-1000, -1000, 1000, 1000))
        pass # We use a fixed massive scene rect now


class OverviewPage(QWidget):
    def __init__(self, parent=None, config=None):
        super().__init__(parent)
        self.config = config
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0,0,0,0)
        self.layout.setSpacing(0)

        # Toolbar
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
                # Use configured max width for the THUMBNAIL
                max_w = int(self.config.get("max_image_width", 1600))
                thumbnail = pixmap
                if max_w > 0 and pixmap.width() > max_w:
                    thumbnail = pixmap.scaledToWidth(max_w, Qt.SmoothTransformation)
                
                # Pass both thumbnail and full path
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
