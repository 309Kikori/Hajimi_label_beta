import math
from PySide6.QtWidgets import (
    QGraphicsView, QGraphicsPixmapItem, QGraphicsItem, QStyleOptionGraphicsItem,
    QGraphicsScene, QWidget, QVBoxLayout, QPushButton, QHBoxLayout, QFrame, QLabel
)
from PySide6.QtCore import Qt, QPointF, QRectF, Signal
from PySide6.QtGui import QPixmap, QPainter, QColor, QPen, QBrush, QCursor
from PySide6.QtOpenGLWidgets import QOpenGLWidget
from rectpack import newPacker

from localization import tr

# --- Graphics Item (Ported from HajimiRef) ---
class RefItem(QGraphicsPixmapItem):
    def __init__(self, pixmap, filename):
        super().__init__(pixmap)
        self.filename = filename
        self.setFlags(QGraphicsItem.ItemIsMovable | QGraphicsItem.ItemIsSelectable | QGraphicsItem.ItemSendsGeometryChanges)
        self.setTransformationMode(Qt.SmoothTransformation)
        self.setShapeMode(QGraphicsPixmapItem.BoundingRectShape)
        self.setAcceptHoverEvents(True)
        
        # Center the origin
        self.setOffset(-pixmap.width()/2, -pixmap.height()/2)

        # Resize state
        self._resize_corner = None
        self._anchor_scene_pos = None

    def paint(self, painter, option, widget=None):
        super().paint(painter, option, widget)
        
        if self.isSelected():
            # Draw selection border
            pen = QPen(QColor("#007acc"))
            pen.setWidth(2)
            pen.setCosmetic(True)
            painter.setPen(pen)
            painter.setBrush(Qt.NoBrush)
            
            rect = self.boundingRect()
            painter.drawRect(rect)
            
            # Draw handles
            painter.setBrush(QColor("white"))
            lod = QStyleOptionGraphicsItem.levelOfDetailFromTransform(painter.worldTransform())
            if lod < 0.00001: lod = 1
            handle_dia = 10 / lod
            radius = handle_dia / 2
            
            corners = [rect.topLeft(), rect.topRight(), rect.bottomLeft(), rect.bottomRight()]
            for corner in corners:
                painter.drawEllipse(corner, radius, radius)
            
            # Draw Filename Label
            painter.setPen(QColor("white"))
            painter.setBrush(QColor(0, 0, 0, 150))
            font = painter.font()
            font.setPixelSize(int(14 / lod))
            painter.setFont(font)
            
            text_rect = painter.fontMetrics().boundingRect(self.filename)
            text_rect.moveCenter(rect.center().toPoint())
            # Adjust to top
            text_rect.moveTop(rect.top() - text_rect.height() - 5)
            
            painter.drawRect(text_rect)
            painter.drawText(text_rect, Qt.AlignCenter, self.filename)

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
                self._anchor_scene_pos = self.mapToScene(self.boundingRect().center()) # Simplified anchor
                # Real resizing logic is complex, for now just allow moving or simple scaling
                # Implementing full resize logic requires storing start pos/scale etc.
                # For this demo, we'll stick to moving and wheel scaling.
                pass
            else:
                self.setCursor(Qt.ClosedHandCursor)
        super().mousePressEvent(event)

    def mouseReleaseEvent(self, event):
        self.setCursor(Qt.OpenHandCursor)
        super().mouseReleaseEvent(event)


# --- Overview Canvas (Ported from HajimiRef RefView) ---
class OverviewCanvas(QGraphicsView):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        
        # Enable GPU Acceleration
        self.setViewport(QOpenGLWidget())
        self.setRenderHint(QPainter.Antialiasing)
        self.setRenderHint(QPainter.SmoothPixmapTransform)
        
        self.setViewportUpdateMode(QGraphicsView.FullViewportUpdate)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setTransformationAnchor(QGraphicsView.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.AnchorUnderMouse)
        self.setDragMode(QGraphicsView.RubberBandDrag)
        
        self.setBackgroundBrush(QColor(30, 30, 30))
        
        self._is_panning = False
        self._pan_start = QPointF()
        self._space_pressed = False

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
        for item in items:
            if not isinstance(item, RefItem): continue
            r = item.sceneBoundingRect()
            w = max(1, int(math.ceil(r.width())))
            h = max(1, int(math.ceil(r.height())))
            rects.append((w, h, item))
            total_area += w * h

        if not rects: return

        approx_side = int(math.ceil(math.sqrt(total_area)))
        bin_width = max(approx_side, max(w for w, h, it in rects)) * 1.5 # Add some breathing room
        bin_height = int(math.ceil(total_area / bin_width)) * 2

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
                target_y = start_y + float(rect.y)
                
                # Align top-left
                cur_rect = item.sceneBoundingRect()
                cur_tl = cur_rect.topLeft()
                dx = target_x - cur_tl.x()
                dy = target_y - cur_tl.y()
                item.setPos(item.pos() + QPointF(dx, dy))


class OverviewPage(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
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
        self.canvas = OverviewCanvas()
        self.layout.addWidget(self.canvas)

    def load_images(self, folder_path, files):
        self.canvas.scene.clear()
        import os
        
        # Limit to avoid freezing if too many files, or load async (simplified here)
        # For demo, load first 50 or all if small
        count = 0
        for f in files:
            full_path = os.path.join(folder_path, f)
            pixmap = QPixmap(full_path)
            if not pixmap.isNull():
                # Scale down if huge
                if pixmap.width() > 1000:
                    pixmap = pixmap.scaledToWidth(1000, Qt.SmoothTransformation)
                
                item = RefItem(pixmap, f)
                # Random scatter initially
                import random
                item.setPos(random.randint(-500, 500), random.randint(-500, 500))
                self.canvas.scene.addItem(item)
                count += 1
                if count > 100: break # Safety limit
        
        self.auto_arrange()

    def auto_arrange(self):
        self.canvas.organize_items()
        self.canvas.fitInView(self.canvas.scene.itemsBoundingRect(), Qt.KeepAspectRatio)
