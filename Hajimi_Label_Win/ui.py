from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, 
    QFrame, QListWidget, QGraphicsView, QGraphicsScene, 
    QGraphicsPixmapItem, QSizePolicy, QFileDialog, QSplitter,
    QListWidgetItem
)
from PySide6.QtCore import Qt, Signal, QSize, QRectF
from PySide6.QtGui import QIcon, QPixmap, QAction, QBrush, QColor, QPainter
import qtawesome as qta

from localization import tr

# QtAwesome 图标颜色配置
ICON_COLOR = '#cccccc'
ICON_COLOR_ACTIVE = '#ffffff'
ICON_COLOR_PASS = '#4ec9b0'
ICON_COLOR_FAIL = '#f14c4c'
ICON_COLOR_WARNING = '#cca700'

# MARK: - Activity Bar
# MARK: - 活动栏
class ActivityBar(QFrame):
    pageChanged = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ActivityBar")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 10, 0, 0)
        self.layout.setSpacing(0)

        # MARK: - Navigation Buttons (Top)
        # MARK: - 导航按钮（顶部）
        self.btn_review = self.create_button("Review", "fa5s.eye")  # 审核视图
        self.btn_overview = self.create_button("Overview", "fa5s.th-large")  # 概览网格
        self.btn_stats = self.create_button("Statistics", "fa5s.chart-bar")  # 统计图表
        
        self.layout.addWidget(self.btn_review)
        self.layout.addWidget(self.btn_overview)
        self.layout.addWidget(self.btn_stats)
        self.layout.addStretch()
        
        # MARK: - System Buttons (Bottom)
        # MARK: - 系统按钮（底部）
        # Settings Button at bottom
        self.btn_settings = self.create_button("Settings", "fa5s.cog")  # 设置齿轮
        self.layout.addWidget(self.btn_settings)

        self.btn_review.setChecked(True)
        
        # Default visibility
        self.btn_overview.setVisible(True)

    # MARK: - Helper Methods
    # MARK: - 辅助方法
    def create_button(self, name, icon_name):
        btn = QPushButton()
        btn.setObjectName("ActivityButton")
        btn.setCheckable(True)
        btn.setFixedSize(48, 48)
        btn.setToolTip(tr(name.lower()))
        btn.setIcon(qta.icon(icon_name, color=ICON_COLOR))
        btn.setIconSize(QSize(24, 24))
        btn.clicked.connect(lambda: self.on_click(name, btn))
        return btn

    def on_click(self, name, btn):
        self.btn_review.setChecked(False)
        self.btn_overview.setChecked(False)
        self.btn_stats.setChecked(False)
        self.btn_settings.setChecked(False)
        
        btn.setChecked(True)
        self.pageChanged.emit(name)

# MARK: - Side Bar (Explorer)
# MARK: - 侧边栏（资源管理器）
class SideBar(QFrame):
    fileSelected = Signal(str)
    folderOpened = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("SideBar")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)
        self.layout.setSpacing(0)

        # MARK: - UI Initialization
        # MARK: - 界面初始化
        # Title Bar with Refresh Button
        self.title_bar = QFrame()
        self.title_bar.setObjectName("SideBarTitleBar")
        title_layout = QHBoxLayout(self.title_bar)
        title_layout.setContentsMargins(20, 10, 10, 10)
        title_layout.setSpacing(0)
        
        self.title_label = QLabel(tr("explorer"))
        self.title_label.setObjectName("SideBarTitle")
        title_layout.addWidget(self.title_label)
        title_layout.addStretch()
        
        # Refresh Button
        self.btn_refresh = QPushButton()
        self.btn_refresh.setIcon(qta.icon('fa5s.sync-alt', color=ICON_COLOR))
        self.btn_refresh.setIconSize(QSize(14, 14))
        self.btn_refresh.setObjectName("IconButton")
        self.btn_refresh.setToolTip(tr("refresh"))
        self.btn_refresh.setFixedSize(24, 24)
        title_layout.addWidget(self.btn_refresh)
        
        self.layout.addWidget(self.title_bar)

        # Content Container
        self.content_widget = QWidget()
        self.content_layout = QVBoxLayout(self.content_widget)
        self.content_layout.setContentsMargins(0,0,0,0)
        self.content_layout.setSpacing(0)
        self.layout.addWidget(self.content_widget, 1)

        # Initial State: No Folder
        self.show_no_folder()

    # MARK: - Content Management
    # MARK: - 内容管理
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

    def show_file_list(self, folder_name=""):
        self.clear_content()
        
        # Workspace Folder Header (VS Code Style - Collapsible)
        if folder_name:
            self.folder_name = folder_name.upper()  # 保存文件夹名称
            self.folder_header = QPushButton(self.folder_name)
            self.folder_header.setIcon(qta.icon('fa5s.chevron-down', color=ICON_COLOR))
            self.folder_header.setIconSize(QSize(12, 12))
            self.folder_header.setObjectName("WorkspaceHeader")
            self.folder_header.setCheckable(True)
            self.folder_header.setChecked(True)  # Expanded by default
            self.folder_header.clicked.connect(self.toggle_folder_content)
            self.folder_header.setLayoutDirection(Qt.LeftToRight)  # 确保图标在左侧
            self.content_layout.addWidget(self.folder_header)
        
        # File List
        self.file_list = QListWidget()
        self.file_list.currentItemChanged.connect(self.on_file_change)
        self.file_list.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self.content_layout.addWidget(self.file_list, 1)  # stretch factor 1, 让文件列表填充剩余空间

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

    def set_files(self, files, results=None, folder_name=""):
        self.show_file_list(folder_name)
        self.file_list.clear()
        results = results or {}
        for f in files:
            item = QListWidgetItem()
            item.setData(Qt.UserRole, f) # Store filename
            status = results.get(f, "unreviewed")
            self.update_item_display(item, f, status)
            self.file_list.addItem(item)

    def update_file_status(self, filename, status):
        # Find item
        for i in range(self.file_list.count()):
            item = self.file_list.item(i)
            if item.data(Qt.UserRole) == filename:
                self.update_item_display(item, filename, status)
                break

    def toggle_folder_content(self):
        """切换文件夹内容的显示/隐藏"""
        is_expanded = self.folder_header.isChecked()
        self.file_list.setVisible(is_expanded)
        
        # 更新箭头图标
        if is_expanded:
            self.folder_header.setIcon(qta.icon('fa5s.chevron-down', color=ICON_COLOR))
        else:
            self.folder_header.setIcon(qta.icon('fa5s.chevron-right', color=ICON_COLOR))

    def update_item_display(self, item, filename, status):
        # 使用 QtAwesome 图标表示文件状态
        if status == "pass":
            icon = qta.icon('fa5s.check-circle', color=ICON_COLOR_PASS)
        elif status == "fail":
            icon = qta.icon('fa5s.times-circle', color=ICON_COLOR_FAIL)
        elif status == "invalid":
            icon = qta.icon('fa5s.exclamation-triangle', color=ICON_COLOR_WARNING)
        else:  # unreviewed
            icon = qta.icon('fa5s.circle', color='#6e6e6e')
        
        item.setIcon(icon)
        item.setText(f"  {filename}")

    # MARK: - Event Handling
    # MARK: - 事件处理
    def on_file_change(self, current, previous):
        if current:
            filename = current.data(Qt.UserRole)
            self.fileSelected.emit(filename)


# MARK: - Image Viewer
# MARK: - 图片查看器
class ImageViewer(QGraphicsView):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        
        # MARK: - View Configuration
        # MARK: - 视图配置
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

    # MARK: - Helper Methods
    # MARK: - 辅助方法
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
        
        # Set a large scene rect to allow panning past image edges
        rect = QRectF(pixmap.rect())
        w, h = rect.width(), rect.height()
        # Add margin equal to image size on all sides
        self.setSceneRect(rect.adjusted(-w, -h, w, h))
        
        # Reset view
        self.resetTransform()
        self.fitInView(self.scene.itemsBoundingRect(), Qt.KeepAspectRatio)

    # MARK: - Event Handling
    # MARK: - 事件处理
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


# MARK: - Editor Area
# MARK: - 编辑区域
class EditorArea(QFrame):
    decisionMade = Signal(str) # "pass", "fail", "invalid", etc.

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("EditorArea")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)
        self.layout.setSpacing(0)

        # MARK: - Layout Setup
        # MARK: - 布局设置
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

        # MARK: - Action Bar (Bottom)
        # MARK: - 底部操作栏
        # Action Bar (Bottom)
        self.action_bar = QFrame()
        self.action_bar.setObjectName("ActionBar")
        self.action_bar_layout = QHBoxLayout(self.action_bar)
        self.action_bar_layout.setContentsMargins(10, 5, 10, 5)
        
        # Dynamic Buttons Configuration
        # You can add more buttons here easily
        self.buttons_config = [
            {"id": "fail", "label": "fail", "shortcut": "F", "color": "#a10000", "hover": "#bd0000"},
            {"id": "invalid", "label": "invalid", "shortcut": "I", "color": "#8e8e8e", "hover": "#a0a0a0"}, # Grey for invalid
            {"id": "pass", "label": "pass", "shortcut": "P", "color": "#0e639c", "hover": "#1177bb"},
        ]
        
        self.action_bar_layout.addStretch()
        
        for btn_cfg in self.buttons_config:
            btn = QPushButton(f"{tr(btn_cfg['label'])} ({btn_cfg['shortcut']})")
            # Custom styling for each button (面板风格)
            # 计算按下状态的颜色（比悬停状态更深）
            pressed_color = self._darken_color(btn_cfg['hover'], 0.85)
            btn.setStyleSheet(f"""
                QPushButton {{
                    background-color: {btn_cfg['color']};
                    color: #ffffff;
                    border: none;
                    padding: 6px 18px;
                    border-radius: 3px;
                    font-size: 12px;
                    font-weight: 500;
                }}
                QPushButton:hover {{
                    background-color: {btn_cfg['hover']};
                }}
                QPushButton:pressed {{
                    background-color: {pressed_color};
                }}
            """)
            btn.setShortcut(btn_cfg['shortcut'])
            # Use default argument to capture current config
            btn.clicked.connect(lambda checked=False, cid=btn_cfg['id']: self.decisionMade.emit(cid))
            self.action_bar_layout.addWidget(btn)
            # Add spacing
            self.action_bar_layout.addSpacing(10)

        self.action_bar_layout.addStretch()

        self.layout.addWidget(self.action_bar)

    def _darken_color(self, hex_color, factor=0.85):
        """将十六进制颜色加深（用于按下状态）"""
        hex_color = hex_color.lstrip('#')
        r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
        r, g, b = int(r * factor), int(g * factor), int(b * factor)
        return f"#{r:02x}{g:02x}{b:02x}"

    def load_image(self, path):
        filename = path.split("\\")[-1].split("/")[-1]
        # 使用 QtAwesome 图标作为文件标签图标
        self.tab_label.setText(f"  {filename}")
        self.viewer.load_image(path)

# MARK: - Statistics View
# MARK: - 统计视图
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

    def update_stats(self, total, passed, failed, invalid=0, unreviewed=0):
        text = f"{tr('total')}: {total}\n{tr('passed')}: {passed}\n{tr('failed')}: {failed}\n{tr('invalid')}: {invalid}\n{tr('unreviewed')}: {unreviewed}"
        self.stats_label.setText(text)
