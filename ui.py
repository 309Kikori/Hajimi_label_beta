from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, 
    QFrame, QListWidget, QGraphicsView, QGraphicsScene, 
    QGraphicsPixmapItem, QSizePolicy, QFileDialog, QSplitter,
    QListWidgetItem
)
from PySide6.QtCore import Qt, Signal, QSize, QRectF
from PySide6.QtGui import QIcon, QPixmap, QAction, QBrush, QColor, QPainter

from localization import tr

class ActivityBar(QFrame):
    pageChanged = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ActivityBar")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 10, 0, 0)
        self.layout.setSpacing(0)

        # Using Unicode characters as icons
        self.btn_review = self.create_button("Review", "👁️") # Eye or Picture
        self.btn_overview = self.create_button("Overview", "🗺️") # Map
        self.btn_stats = self.create_button("Statistics", "📊") # Chart
        
        self.layout.addWidget(self.btn_review)
        self.layout.addWidget(self.btn_overview)
        self.layout.addWidget(self.btn_stats)
        self.layout.addStretch()
        
        # Settings Button at bottom
        self.btn_settings = self.create_button("Settings", "⚙️")
        self.layout.addWidget(self.btn_settings)

        self.btn_review.setChecked(True)
        
        # Default visibility
        self.btn_overview.setVisible(True)

    def create_button(self, name, text):
        btn = QPushButton(text)
        btn.setObjectName("ActivityButton")
        btn.setCheckable(True)
        btn.setFixedSize(48, 48)
        btn.setToolTip(tr(name.lower()))
        btn.clicked.connect(lambda: self.on_click(name, btn))
        return btn

    def on_click(self, name, btn):
        self.btn_review.setChecked(False)
        self.btn_overview.setChecked(False)
        self.btn_stats.setChecked(False)
        self.btn_settings.setChecked(False)
        
        btn.setChecked(True)
        self.pageChanged.emit(name)

class SideBar(QFrame):
    fileSelected = Signal(str)
    folderOpened = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("SideBar")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)
        self.layout.setSpacing(0)

        # Title Area
        self.title_label = QLabel(tr("explorer"))
        self.title_label.setObjectName("SideBarTitle")
        self.layout.addWidget(self.title_label)

        # Content Container
        self.content_widget = QWidget()
        self.content_layout = QVBoxLayout(self.content_widget)
        self.content_layout.setContentsMargins(0,0,0,0)
        self.content_layout.setSpacing(0)
        self.layout.addWidget(self.content_widget)

        # Initial State: No Folder
        self.show_no_folder()

    def show_no_folder(self):
        # Clear existing content
        self.clear_content()
        
        # Add "Open Folder" button prominently
        self.btn_open_big = QPushButton(tr("open_folder"))
        self.btn_open_big.setObjectName("ActionButton")
        self.btn_open_big.clicked.connect(self.open_folder)
        
        container = QWidget()
        vbox = QVBoxLayout(container)
        vbox.addStretch()
        vbox.addWidget(QLabel(tr("no_folder")))
        vbox.addWidget(self.btn_open_big)
        vbox.addStretch()
        
        self.content_layout.addWidget(container)

    def show_file_list(self):
        self.clear_content()
        
        # Section: Files
        self.files_header = QPushButton(f"▼ {tr('files')}")
        self.files_header.setObjectName("SectionHeader")
        self.content_layout.addWidget(self.files_header)

        # File List
        self.file_list = QListWidget()
        self.file_list.currentItemChanged.connect(self.on_file_change)
        self.content_layout.addWidget(self.file_list)

    def clear_content(self):
        while self.content_layout.count():
            item = self.content_layout.takeAt(0)
            widget = item.widget()
            if widget:
                widget.deleteLater()

    def open_folder(self):
        folder = QFileDialog.getExistingDirectory(self, tr("open_folder"))
        if folder:
            self.folderOpened.emit(folder)

    def set_files(self, files):
        self.show_file_list()
        self.file_list.clear()
        for f in files:
            item = QListWidgetItem(f)
            # Simple icon simulation
            if f.endswith('.png') or f.endswith('.jpg'):
                item.setText(f"🖼️ {f}")
            else:
                item.setText(f"📄 {f}")
            self.file_list.addItem(item)

    def on_file_change(self, current, previous):
        if current:
            # Strip icon
            filename = current.text().split(' ', 1)[1]
            self.fileSelected.emit(filename)


class ImageViewer(QGraphicsView):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        
        # Interaction Settings
        self.setTransformationAnchor(QGraphicsView.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.AnchorUnderMouse)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setFrameShape(QFrame.NoFrame)
        
        # Checkerboard background
        self.setBackgroundBrush(self.create_checkerboard_brush())
        self._pixmap_item = None
        
        # Panning State
        self._is_panning = False
        self._pan_start = None

    def create_checkerboard_brush(self):
        size = 20
        pixmap = QPixmap(size * 2, size * 2)
        pixmap.fill(QColor(30, 30, 30))
        painter = QPainter(pixmap)
        painter.fillRect(0, 0, size, size, QColor(40, 40, 40))
        painter.fillRect(size, size, size, size, QColor(40, 40, 40))
        painter.end()
        return QBrush(pixmap)

    def load_image(self, path):
        self.scene.clear()
        pixmap = QPixmap(path)
        self._pixmap_item = self.scene.addPixmap(pixmap)
        self.setSceneRect(QRectF(pixmap.rect()))
        
        # Reset view
        self.resetTransform()
        self.fitInView(self.scene.itemsBoundingRect(), Qt.KeepAspectRatio)

    def wheelEvent(self, event):
        zoom_factor = 1.1 if event.angleDelta().y() > 0 else 0.9
        self.scale(zoom_factor, zoom_factor)

    def mousePressEvent(self, event):
        if event.button() == Qt.MiddleButton or event.button() == Qt.LeftButton:
            self._is_panning = True
            self._pan_start = event.position()
            self.setCursor(Qt.ClosedHandCursor)
            event.accept()
        else:
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
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if self._is_panning:
            self._is_panning = False
            self.setCursor(Qt.ArrowCursor)
            event.accept()
        else:
            super().mouseReleaseEvent(event)

    # Removed resizeEvent to prevent auto-fit on window resize, allowing free movement


class EditorArea(QFrame):
    decisionMade = Signal(str) # "pass" or "fail"

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("EditorArea")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)
        self.layout.setSpacing(0)

        # Tab Bar
        self.tab_bar = QFrame()
        self.tab_bar.setObjectName("TabBar")
        self.tab_layout = QHBoxLayout(self.tab_bar)
        self.tab_layout.setContentsMargins(0, 0, 0, 0)
        self.tab_layout.setSpacing(1)
        
        self.tab_label = QLabel(tr("no_file_selected"))
        self.tab_label.setObjectName("TabLabel")
        self.tab_layout.addWidget(self.tab_label)
        self.tab_layout.addStretch()

        self.layout.addWidget(self.tab_bar)

        # Image View
        self.viewer = ImageViewer()
        self.layout.addWidget(self.viewer)

        # Action Bar (Bottom)
        self.action_bar = QFrame()
        self.action_bar.setObjectName("ActionBar")
        self.action_bar_layout = QHBoxLayout(self.action_bar)
        self.action_bar_layout.setContentsMargins(10, 5, 10, 5)
        
        self.btn_pass = QPushButton(f"{tr('pass')} (P)")
        self.btn_pass.setObjectName("ActionButton")
        self.btn_pass.setShortcut("P")
        self.btn_pass.clicked.connect(lambda: self.decisionMade.emit("pass"))
        
        self.btn_fail = QPushButton(f"{tr('fail')} (F)")
        self.btn_fail.setObjectName("FailButton")
        self.btn_fail.setShortcut("F")
        self.btn_fail.clicked.connect(lambda: self.decisionMade.emit("fail"))

        self.action_bar_layout.addStretch()
        self.action_bar_layout.addWidget(self.btn_fail)
        self.action_bar_layout.addWidget(self.btn_pass)

        self.layout.addWidget(self.action_bar)

    def load_image(self, path):
        filename = path.split("\\")[-1].split("/")[-1]
        self.tab_label.setText(f"🖼️ {filename}")
        self.viewer.load_image(path)

class StatsView(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0,0,0,0)
        
        self.title = QLabel(tr("stats_title"))
        self.title.setObjectName("StatsTitle")
        self.layout.addWidget(self.title)
        
        self.stats_label = QLabel(f"{tr('total')}: 0\n{tr('passed')}: 0\n{tr('failed')}: 0")
        self.stats_label.setObjectName("StatsText")
        self.layout.addWidget(self.stats_label)
        self.layout.addStretch()

    def update_stats(self, total, passed, failed):
        text = f"{tr('total')}: {total}\n{tr('passed')}: {passed}\n{tr('failed')}: {failed}"
        self.stats_label.setText(text)
