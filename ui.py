from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, 
    QFrame, QListWidget, QGraphicsView, QGraphicsScene, 
    QGraphicsPixmapItem, QSizePolicy, QFileDialog, QSplitter
)
from PySide6.QtCore import Qt, Signal, QSize
from PySide6.QtGui import QIcon, QPixmap, QAction

class ActivityBar(QFrame):
    pageChanged = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ActivityBar")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 10, 0, 0)
        self.layout.setSpacing(10)

        self.btn_review = self.create_button("Review", "R")
        self.btn_stats = self.create_button("Statistics", "S")
        
        self.layout.addWidget(self.btn_review)
        self.layout.addWidget(self.btn_stats)
        self.layout.addStretch()

        self.btn_review.setChecked(True)

    def create_button(self, name, text):
        btn = QPushButton(text)
        btn.setObjectName("ActivityButton")
        btn.setCheckable(True)
        btn.setFixedSize(48, 48)
        btn.setToolTip(name)
        btn.clicked.connect(lambda: self.on_click(name, btn))
        return btn

    def on_click(self, name, btn):
        self.btn_review.setChecked(False)
        self.btn_stats.setChecked(False)
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

        # Title Area
        self.title_label = QLabel("EXPLORER")
        self.title_label.setObjectName("SideBarTitle")
        self.layout.addWidget(self.title_label)

        # Open Folder Button
        self.btn_open = QPushButton("Open Folder")
        self.btn_open.setObjectName("ActionButton")
        self.btn_open.clicked.connect(self.open_folder)
        self.layout.addWidget(self.btn_open)

        # File List
        self.file_list = QListWidget()
        self.file_list.currentItemChanged.connect(self.on_file_change)
        self.layout.addWidget(self.file_list)

    def open_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Folder")
        if folder:
            self.folderOpened.emit(folder)

    def set_files(self, files):
        self.file_list.clear()
        self.file_list.addItems(files)

    def on_file_change(self, current, previous):
        if current:
            self.fileSelected.emit(current.text())

class ImageViewer(QGraphicsView):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        self.setDragMode(QGraphicsView.ScrollHandDrag)
        self.setBackgroundBrush(Qt.black) # Or dark grey
        self._pixmap_item = None

    def load_image(self, path):
        self.scene.clear()
        pixmap = QPixmap(path)
        self._pixmap_item = self.scene.addPixmap(pixmap)
        self.setSceneRect(QRectF(pixmap.rect()))
        self.fitInView(self.scene.itemsBoundingRect(), Qt.KeepAspectRatio)
        
        # Placeholder for loading labels
        # self.load_labels(path)

    # def load_labels(self, image_path):
    #     # Implement label loading logic here (e.g., read corresponding .json or .txt)
    #     # and add QGraphicsRectItem or QGraphicsPolygonItem to the scene.
    #     pass

    def resizeEvent(self, event):
        if self._pixmap_item:
             self.fitInView(self.scene.itemsBoundingRect(), Qt.KeepAspectRatio)
        super().resizeEvent(event)

from PySide6.QtCore import QRectF

class EditorArea(QFrame):
    decisionMade = Signal(str) # "pass" or "fail"

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("EditorArea")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)

        # Toolbar / Tabs
        self.toolbar = QFrame()
        self.toolbar.setFixedHeight(35)
        self.toolbar.setStyleSheet("background-color: #2d2d2d;")
        self.toolbar_layout = QHBoxLayout(self.toolbar)
        self.toolbar_layout.setContentsMargins(10, 0, 10, 0)
        
        self.filename_label = QLabel("No file selected")
        self.toolbar_layout.addWidget(self.filename_label)
        self.toolbar_layout.addStretch()

        self.layout.addWidget(self.toolbar)

        # Image View
        self.viewer = ImageViewer()
        self.layout.addWidget(self.viewer)

        # Action Bar (Floating or Bottom)
        self.action_bar = QFrame()
        self.action_bar.setFixedHeight(50)
        self.action_bar_layout = QHBoxLayout(self.action_bar)
        
        self.btn_pass = QPushButton("Pass (P)")
        self.btn_pass.setObjectName("ActionButton")
        self.btn_pass.setShortcut("P")
        self.btn_pass.clicked.connect(lambda: self.decisionMade.emit("pass"))
        
        self.btn_fail = QPushButton("Fail (F)")
        self.btn_fail.setObjectName("FailButton")
        self.btn_fail.setShortcut("F")
        self.btn_fail.clicked.connect(lambda: self.decisionMade.emit("fail"))

        self.action_bar_layout.addStretch()
        self.action_bar_layout.addWidget(self.btn_fail)
        self.action_bar_layout.addWidget(self.btn_pass)
        self.action_bar_layout.addStretch()

        self.layout.addWidget(self.action_bar)

    def load_image(self, path):
        self.filename_label.setText(path)
        self.viewer.load_image(path)

class StatsView(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.layout = QVBoxLayout(self)
        self.label = QLabel("Statistics")
        self.label.setStyleSheet("font-size: 20px; font-weight: bold;")
        self.layout.addWidget(self.label)
        
        self.stats_label = QLabel("Total: 0\nPassed: 0\nFailed: 0")
        self.layout.addWidget(self.stats_label)
        self.layout.addStretch()

    def update_stats(self, total, passed, failed):
        self.stats_label.setText(f"Total Reviewed: {total}\nPassed: {passed}\nFailed: {failed}")
