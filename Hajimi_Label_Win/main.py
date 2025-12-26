# MARK: - Module Documentation
# MARK: - 模块文档
"""
Hajimi Label - 图像标注审核工具

基于 PySide6 (Qt 6) 的图像审核桌面应用，仿 VS Code 风格。
用户可批量审核图像并将结果（pass/fail/invalid）保存为 JSON。

架构: MVC 模式
- Model: results 字典 + JSON 持久化
- View: Qt 组件构成的 GUI
- Controller: MainWindow 中的槽函数

主要组件:
- MainWindow: 主窗口，协调所有组件
- SettingsDialog: 设置对话框
- ActivityBar: 左侧导航栏 (来自 ui.py)
- SideBar: 文件列表 (来自 ui.py)
- EditorArea: 图像预览区 (来自 ui.py)
- OverviewPage: 缩略图网格 (来自 overview.py)
- StatsView: 统计视图 (来自 ui.py)
"""

# MARK: - Imports
# MARK: - 导入模块
import sys   # sys.argv: 命令行参数; sys.exit(): 退出程序; sys._MEIPASS: PyInstaller 临时目录
import os    # os.path: 路径操作; os.listdir(): 列目录
import json  # json.load/dump: JSON 读写

from PySide6.QtWidgets import (
    QApplication,    # Qt 应用入口，管理事件循环，每个程序只能有一个实例
    QMainWindow,     # 主窗口基类，内置菜单栏/状态栏/中央部件支持
    QWidget,         # 所有可视组件的基类
    QDialog,         # 对话框基类，支持模态(exec)/非模态(show)两种模式
    QHBoxLayout,     # 水平布局: 子组件从左到右排列
    QVBoxLayout,     # 垂直布局: 子组件从上到下排列
    QFormLayout,     # 表单布局: 标签-控件成对排列，适合设置页面
    QStackedWidget,  # 堆叠容器: 多页面堆叠，同时只显示一个，通过代码切换
    QSplitter,       # 分割器: 允许用户拖动调整子组件大小比例
    QScrollArea,     # 滚动区域: 内容超出时自动显示滚动条
    QMenuBar, QMenu, # 菜单栏和菜单
    QStatusBar,      # 状态栏
    QLabel,          # 标签: 显示文本/图像
    QLineEdit,       # 单行文本输入框
    QCheckBox,       # 复选框
    QPushButton,     # 按钮: 用于通知铃铛等交互元素
    QSizePolicy,     # 尺寸策略: 控制组件的伸缩行为
)

from PySide6.QtCore import QFile, QTextStream, Qt, QSize
from PySide6.QtGui import QAction, QIcon
import qtawesome as qta

from ui import ActivityBar, SideBar, EditorArea, StatsView
from overview import OverviewPage
from localization import tr  # 国际化函数: tr("key") 返回当前语言的翻译


# MARK: - Utility Functions
# MARK: - 工具函数
def resource_path(relative_path):
    """
    获取资源文件的绝对路径，兼容开发环境和 PyInstaller 打包环境。
    
    PyInstaller 打包后，资源文件被解压到临时目录 sys._MEIPASS。
    开发时资源在当前目录。此函数统一处理两种情况。
    
    Args:
        relative_path: 相对于项目根目录的路径，如 "assets/style.qss"
    
    Returns:
        资源文件的绝对路径
    """
    try:
        base_path = sys._MEIPASS  # PyInstaller 运行时自动设置
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))  # 开发环境
    return os.path.join(base_path, relative_path)


# MARK: - Settings Dialog
# MARK: - 设置对话框
class SettingsDialog(QDialog):
    """
    设置对话框，VS Code 风格。
    
    特点:
    - 模态对话框: exec() 阻塞父窗口直到关闭
    - 自动保存: 关闭时自动将设置写入 config 字典（引用传递，直接生效）
    
    Attributes:
        config: 配置字典的引用，修改直接影响主窗口
        inp_grid_size/inp_grid_color/inp_bg_color/inp_max_width: 各设置项输入框
        cb_overview: 启用概览页面的复选框
    """
    
    def __init__(self, parent=None, config=None):
        """
        Args:
            parent: 父窗口，Qt 父子关系用于内存管理和窗口层次
            config: 配置字典引用，对话框直接修改此字典
        """
        super().__init__(parent)
        self.setWindowTitle(tr("settings_title"))
        self.resize(600, 400)
        self.config = config  # 保存引用，不是副本
        
        # 主布局
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)
        
        # 搜索栏（目前仅视觉元素）
        self.search_bar = QLineEdit()
        self.search_bar.setPlaceholderText("Search settings...")
        self.search_bar.setStyleSheet("""
            QLineEdit {
                background-color: #3c3c3c; color: #cccccc;
                border: 1px solid #3c3c3c; padding: 6px 10px;
                margin: 10px; border-radius: 6px;
            }
            QLineEdit:focus { 
                border: 1px solid #007acc;
                background-color: #464646;
            }
        """)
        self.layout.addWidget(self.search_bar)
        
        # 滚动区域（设置项可能很多）
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)  # 内容自动填充可用空间
        self.scroll.setStyleSheet("QScrollArea { border: none; background-color: #1e1e1e; }")
        
        self.content = QWidget()
        self.content.setStyleSheet("background-color: #1e1e1e;")
        
        # QFormLayout: 专为"标签-控件"配对设计
        self.form_layout = QFormLayout(self.content)
        self.form_layout.setLabelAlignment(Qt.AlignLeft)
        self.form_layout.setFormAlignment(Qt.AlignLeft | Qt.AlignTop)
        self.form_layout.setSpacing(15)
        self.form_layout.setContentsMargins(20, 10, 20, 10)
        
        # 外观设置组
        self.add_section_header(tr("appearance"))
        
        # dict.get(key, default): 安全获取，键不存在返回默认值
        self.inp_grid_size = QLineEdit(str(self.config.get("grid_size", 40)))
        self.add_setting_row(tr("grid_size"), self.inp_grid_size)
        
        self.inp_grid_color = QLineEdit(self.config.get("grid_color", "#333333"))
        self.add_setting_row(tr("grid_color"), self.inp_grid_color)
        
        self.inp_bg_color = QLineEdit(self.config.get("bg_color", "#1e1e1e"))
        self.add_setting_row(tr("bg_color"), self.inp_bg_color)

        self.inp_max_width = QLineEdit(str(self.config.get("max_image_width", 1600)))
        self.add_setting_row(tr("max_image_width"), self.inp_max_width)

        # 行为设置组
        self.add_section_header(tr("behavior"))
        
        self.cb_overview = QCheckBox()
        self.cb_overview.setChecked(self.config.get("enable_overview", True))
        self.add_setting_row(tr("enable_overview"), self.cb_overview)
        
        self.scroll.setWidget(self.content)
        self.layout.addWidget(self.scroll)

    def add_section_header(self, text):
        """添加设置分组标题"""
        label = QLabel(text)
        label.setStyleSheet("font-weight: bold; font-size: 14px; color: #ffffff; "
                           "margin-top: 10px; margin-bottom: 5px;")
        self.form_layout.addRow(label)

    def add_setting_row(self, label_text, widget):
        """添加一行设置项（标签 + 控件），统一样式"""
        label = QLabel(label_text)
        label.setStyleSheet("color: #cccccc; font-size: 13px;")
        
        if isinstance(widget, QLineEdit):
            widget.setStyleSheet("""
                QLineEdit {
                    background-color: #3c3c3c; color: #cccccc;
                    border: 1px solid #3c3c3c; padding: 6px 10px;
                    border-radius: 4px;
                }
                QLineEdit:focus { 
                    border: 1px solid #007acc;
                    background-color: #464646;
                }
            """)
        
        self.form_layout.addRow(label, widget)

    def closeEvent(self, event):
        """
        窗口关闭时自动保存设置。
        
        Qt 事件机制: 重写 xxxEvent 方法来处理特定事件。
        closeEvent 在窗口关闭前调用，可用于保存数据或取消关闭(event.ignore())。
        """
        self.config["enable_overview"] = self.cb_overview.isChecked()
        
        # 安全解析整数输入
        try:
            self.config["grid_size"] = int(self.inp_grid_size.text())
        except ValueError:
            pass  # 无效输入保持原值
        
        try:
            self.config["max_image_width"] = int(self.inp_max_width.text())
        except ValueError:
            pass
        
        self.config["grid_color"] = self.inp_grid_color.text()
        self.config["bg_color"] = self.inp_bg_color.text()
        
        super().closeEvent(event)  # 调用父类完成关闭


# MARK: - Main Window
# MARK: - 主窗口
class MainWindow(QMainWindow):
    """
    主窗口，VS Code 风格布局。
    
    布局结构:
    ┌─────────────────────────────────────────┐
    │              Menu Bar                   │
    ├────┬────────┬───────────────────────────┤
    │ A  │ Side   │       Content Area        │
    │ c  │ Bar    │    (Editor/Overview/      │
    │ t  │        │        Stats)             │
    │ i  │        │                           │
    │ v  │        │                           │
    │ i  │        │                           │
    │ t  │        │                           │
    │ y  │        │                           │
    ├────┴────────┴───────────────────────────┤
    │            Status Bar                   │
    └─────────────────────────────────────────┘
    
    信号-槽连接 (Qt 的观察者模式实现):
    - activity_bar.pageChanged -> switch_page
    - side_bar.folderOpened -> load_folder
    - side_bar.fileSelected -> load_file
    - editor_area.decisionMade -> handle_decision
    """
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle(tr("app_title"))
        self.resize(1200, 800)
        
        # 配置默认值
        self.config = {
            "enable_overview": True,
            "grid_size": 40,
            "grid_color": "#333333",
            "bg_color": "#1e1e1e",
            "max_image_width": 1600
        }

        # QMainWindow 必须设置中央部件才能使用布局
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        
        self.main_layout = QHBoxLayout(self.central_widget)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.main_layout.setSpacing(0)

        # 创建组件
        self.activity_bar = ActivityBar()
        self.side_bar = SideBar()
        self.setup_menu()  # 必须在 side_bar 之后，菜单引用其方法
        
        # QStackedWidget: 多页面堆叠，setCurrentWidget() 切换显示
        self.content_stack = QStackedWidget()
        self.editor_area = EditorArea()
        self.overview_page = OverviewPage(config=self.config)
        self.stats_view = StatsView()
        
        self.content_stack.addWidget(self.editor_area)
        self.content_stack.addWidget(self.overview_page)
        self.content_stack.addWidget(self.stats_view)

        # QSplitter: 可拖动调整大小的分割区域
        self.splitter = QSplitter(Qt.Horizontal)
        self.splitter.addWidget(self.side_bar)
        self.splitter.addWidget(self.content_stack)
        self.splitter.setStretchFactor(1, 1)  # 索引1(content)占据更多空间
        self.splitter.setHandleWidth(1)  # 细分割线，VS Code 风格

        self.main_layout.addWidget(self.activity_bar)
        self.main_layout.addWidget(self.splitter)

        # 状态栏
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        
        # 左侧：状态标签
        self.status_label = QLabel(tr("ready"))
        self.status_label.setObjectName("StatusLabel")
        self.status_bar.addWidget(self.status_label)
        
        # 左侧：错误/警告指示器（参考 VS Code）
        self.error_warning_widget = QWidget()
        self.error_warning_layout = QHBoxLayout(self.error_warning_widget)
        self.error_warning_layout.setContentsMargins(10, 0, 10, 0)
        self.error_warning_layout.setSpacing(8)
        
        # 错误图标 + 数字（使用 QtAwesome）
        self.error_icon = QLabel()
        error_pixmap = qta.icon('fa5s.times-circle', color='#f48771').pixmap(14, 14)
        self.error_icon.setPixmap(error_pixmap)
        self.error_count = QLabel("0")
        self.error_count.setStyleSheet("color: white;")
        
        # 警告图标 + 数字（使用 QtAwesome）
        self.warning_icon = QLabel()
        warning_pixmap = qta.icon('fa5s.exclamation-triangle', color='#cca700').pixmap(14, 14)
        self.warning_icon.setPixmap(warning_pixmap)
        self.warning_count = QLabel("0")
        self.warning_count.setStyleSheet("color: white;")
        
        self.error_warning_layout.addWidget(self.error_icon)
        self.error_warning_layout.addWidget(self.error_count)
        self.error_warning_layout.addWidget(self.warning_icon)
        self.error_warning_layout.addWidget(self.warning_count)
        
        # 设置鼠标悬停样式
        self.error_warning_widget.setCursor(Qt.PointingHandCursor)
        self.error_warning_widget.setToolTip("点击查看问题详情")
        
        self.status_bar.addWidget(self.error_warning_widget)
        
        # 左侧：统计信息
        self.stats_status_label = QLabel("")
        self.stats_status_label.setObjectName("StatusLabel")
        self.status_bar.addWidget(self.stats_status_label)
        
        # 添加弹性空间（把右侧元素推到最右边）
        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        self.status_bar.addWidget(spacer)
        
        # 最右侧：通知铃铛（使用 QtAwesome）
        self.notification_btn = QPushButton()
        self.notification_btn.setIcon(qta.icon('fa5s.bell', color='white'))
        self.notification_btn.setIconSize(QSize(16, 16))
        self.notification_btn.setObjectName("NotificationButton")
        self.notification_btn.setFixedSize(30, 22)
        self.notification_btn.setCursor(Qt.PointingHandCursor)
        self.notification_btn.setToolTip("通知")
        self.notification_btn.setStyleSheet("""
            QPushButton#NotificationButton {
                background: transparent;
                border: none;
                padding: 0;
            }
            QPushButton#NotificationButton:hover {
                background: rgba(255, 255, 255, 0.1);
                border-radius: 3px;
            }
        """)
        self.notification_btn.clicked.connect(self.show_notifications)
        self.status_bar.addPermanentWidget(self.notification_btn)
        
        # 通知列表（存储通知消息）
        self.notifications = []
        
        self.status_bar.setStyleSheet("background-color: #007acc; color: white;")

        # 信号-槽连接: signal.connect(slot)
        self.activity_bar.pageChanged.connect(self.switch_page)
        self.side_bar.folderOpened.connect(self.load_folder)
        self.side_bar.fileSelected.connect(self.load_file)
        self.side_bar.btn_refresh.clicked.connect(self.refresh_folder)
        self.editor_area.decisionMade.connect(self.handle_decision)

        # 数据状态
        self.current_folder = ""
        self.current_file = ""
        self.results = {}  # {filename: "pass"/"fail"/"invalid"}
        self.files = []    # 图像文件名列表

        self.load_stylesheet()
        self.apply_config()

    # MARK: - Menu Setup
    # MARK: - 菜单设置
    def setup_menu(self):
        """设置菜单栏"""
        menubar = self.menuBar()
        
        file_menu = menubar.addMenu(tr("file_menu"))
        
        # QAction: 可复用的动作，可同时添加到菜单和工具栏
        open_action = QAction(tr("open_folder"), self)
        open_action.triggered.connect(self.side_bar.open_folder)
        file_menu.addAction(open_action)
        
        close_action = QAction(tr("close_folder"), self)
        close_action.triggered.connect(self.close_folder)
        file_menu.addAction(close_action)
        
        file_menu.addSeparator()
        
        exit_action = QAction(tr("exit"), self)
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)

    # MARK: - Folder Management
    # MARK: - 文件夹管理
    def close_folder(self):
        """关闭文件夹，重置所有状态"""
        self.current_folder = ""
        self.files = []
        self.results = {}
        
        self.side_bar.show_no_folder()
        self.editor_area.viewer.scene.clear()
        self.editor_area.tab_label.setText(tr("no_file_selected"))
        self.overview_page.canvas.scene.clear()
        
        self.status_label.setText(tr("ready"))
        self.stats_status_label.setText("")
        self.setWindowTitle(tr("app_title"))

    # MARK: - Styling
    # MARK: - 样式管理
    def load_stylesheet(self):
        """加载外部 QSS 样式表"""
        style_path = resource_path("assets/style.qss")
        style_file = QFile(style_path)
        
        # QFile.ReadOnly | QFile.Text: 位标志组合
        if style_file.open(QFile.ReadOnly | QFile.Text):
            stream = QTextStream(style_file)
            self.setStyleSheet(stream.readAll())
        else:
            print(f"Warning: Could not load stylesheet from {style_path}")

    # MARK: - Page Navigation
    # MARK: - 页面导航
    def switch_page(self, page_name):
        """
        切换内容页面。
        
        Args:
            page_name: "Review"/"Overview"/"Statistics"/"Settings"
        """
        if page_name == "Review":
            self.content_stack.setCurrentWidget(self.editor_area)
            self.side_bar.setVisible(True)
        elif page_name == "Overview":
            self.content_stack.setCurrentWidget(self.overview_page)
            self.side_bar.setVisible(False)  # 隐藏侧边栏腾出空间
        elif page_name == "Statistics":
            self.update_stats()
            self.content_stack.setCurrentWidget(self.stats_view)
            self.side_bar.setVisible(False)
        elif page_name == "Settings":
            self.open_settings()

    def open_settings(self):
        """打开设置对话框"""
        dlg = SettingsDialog(self, self.config)
        dlg.exec()  # 模态: 阻塞直到对话框关闭
        self.apply_config()
        self.activity_bar.btn_review.click()  # 返回审核视图

    def apply_config(self):
        """将配置应用到 UI"""
        self.activity_bar.btn_overview.setVisible(self.config.get("enable_overview", True))
        self.overview_page.update_config()

    # MARK: - Image Loading
    # MARK: - 图片加载
    def load_folder(self, folder_path):
        """
        加载文件夹中的图像文件。
        
        支持格式: .png, .jpg, .jpeg, .bmp
        """
        self.current_folder = folder_path
        
        # 列表推导式 + endswith 元组: 筛选多种扩展名
        self.files = [f for f in os.listdir(folder_path) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
        
        self.load_results()
        
        folder_name = os.path.basename(folder_path)
        self.side_bar.set_files(self.files, self.results, folder_name)
        
        # 添加加载通知
        self.add_notification(f"已加载 {len(self.files)} 张图片：{folder_name}", "info")
        self.status_label.setText(tr("ready"))
        self.update_stats_status()
        
        if self.config.get("enable_overview", True):
            self.overview_page.load_images(folder_path, self.files)

    def refresh_folder(self):
        """
        刷新当前文件夹，重新加载文件列表。
        
        用于检测文件夹中新增或删除的图片文件。
        """
        if not self.current_folder:
            self.add_notification("没有打开的文件夹", "warning")
            return
        
        # 保存当前选中的文件
        current_file = self.current_file
        
        # 重新扫描文件列表（不重新加载 overview，避免卡顿）
        old_files = set(self.files)
        self.files = [f for f in os.listdir(self.current_folder) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
        new_files = set(self.files)
        
        # 检测变化
        added = new_files - old_files
        removed = old_files - new_files
        
        # 重新加载结果
        self.load_results()
        
        # 更新侧边栏
        folder_name = os.path.basename(self.current_folder)
        self.side_bar.set_files(self.files, self.results, folder_name)
        
        # 更新统计
        self.update_stats_status()
        
        # 尝试恢复之前选中的文件
        if current_file and current_file in self.files:
            self.load_file(current_file)
        elif len(self.files) > 0:
            # 如果之前的文件不存在了，选择第一个
            self.load_file(self.files[0])
        
        # 显示刷新通知
        if added or removed:
            msg = f"文件夹已刷新"
            if added:
                msg += f"，新增 {len(added)} 个文件"
            if removed:
                msg += f"，删除 {len(removed)} 个文件"
            self.add_notification(msg, "info")
        else:
            self.add_notification("文件夹已刷新，无变化", "info")

    def load_results(self):
        """从 JSON 加载已有的审核结果"""
        result_path = os.path.join(self.current_folder, "review_results.json")
        
        if os.path.exists(result_path):
            try:
                with open(result_path, 'r', encoding='utf-8') as f:
                    self.results = json.load(f)
            except (json.JSONDecodeError, IOError):
                self.results = {}
        else:
            self.results = {}

    def save_results(self):
        """保存审核结果到 JSON（每次决定后立即保存）"""
        if not self.current_folder:
            return
        
        result_path = os.path.join(self.current_folder, "review_results.json")
        with open(result_path, 'w', encoding='utf-8') as f:
            # indent: 缩进美化; ensure_ascii=False: 允许中文直接输出
            json.dump(self.results, f, indent=2, ensure_ascii=False)

    def load_file(self, filename):
        """加载并显示指定图像"""
        self.current_file = filename
        full_path = os.path.join(self.current_folder, filename)
        self.editor_area.load_image(full_path)
        
        status = self.results.get(filename, tr("unreviewed"))
        self.status_label.setText(tr("reviewing", filename, status))

    # MARK: - Review Decision Handling
    # MARK: - 审核决策处理
    def handle_decision(self, decision):
        """
        处理审核决定，保存结果并自动前进到下一张。
        
        Args:
            decision: "pass"/"fail"/"invalid"
        """
        if not self.current_file:
            return
        
        self.results[self.current_file] = decision
        self.save_results()
        self.side_bar.update_file_status(self.current_file, decision)
        self.status_label.setText(tr("marked_as", self.current_file, tr(decision)))
        self.update_stats_status()
        
        # 自动前进
        current_row = self.side_bar.file_list.currentRow()
        if current_row < self.side_bar.file_list.count() - 1:
            self.side_bar.file_list.setCurrentRow(current_row + 1)
        else:
            self.status_label.setText(tr("all_reviewed"))

    # MARK: - Statistics
    # MARK: - 统计功能
    def update_stats(self):
        """更新统计页面数据"""
        # set(): O(1) 查找; 字典推导式: 过滤只统计当前存在的文件
        current_files = set(self.files)
        valid_results = {k: v for k, v in self.results.items() if k in current_files}
        
        total_files = len(self.files)
        # sum(1 for x in ... if cond): 统计满足条件的数量
        passed = sum(1 for v in valid_results.values() if v == "pass")
        failed = sum(1 for v in valid_results.values() if v == "fail")
        invalid = sum(1 for v in valid_results.values() if v == "invalid")
        unreviewed = total_files - len(valid_results)
        
        self.stats_view.update_stats(total_files, passed, failed, invalid, unreviewed)

    def update_stats_status(self):
        """更新状态栏中的统计摘要"""
        current_files = set(self.files)
        valid_results = {k: v for k, v in self.results.items() if k in current_files}
        
        total_files = len(self.files)
        passed = sum(1 for v in valid_results.values() if v == "pass")
        failed = sum(1 for v in valid_results.values() if v == "fail")
        invalid = sum(1 for v in valid_results.values() if v == "invalid")
        unreviewed = total_files - len(valid_results)
        
        self.stats_status_label.setText(tr("stats_status", total_files, passed, failed, invalid, unreviewed))
        
        # 更新错误/警告计数（示例：失败=错误，无效=警告）
        self.error_count.setText(str(failed))
        self.warning_count.setText(str(invalid))

    # MARK: - Notification Management
    # MARK: - 通知管理
    def add_notification(self, message, level="info"):
        """添加通知消息
        
        Args:
            message: 通知内容
            level: 通知级别 "info"/"warning"/"error"
        """
        self.notifications.append({"message": message, "level": level})
        # 更新铃铛图标（如果有未读通知可以改变样式）
        if len(self.notifications) > 0:
            self.notification_btn.setIcon(qta.icon('fa5s.bell', color='#4daafc'))
    
    def show_notifications(self):
        """显示通知面板（VS Code 风格）"""
        from PySide6.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QScrollArea, QPushButton, QLabel
        
        # 创建通知面板对话框
        dialog = QDialog(self)
        dialog.setWindowTitle("通知")
        dialog.setWindowFlags(Qt.Popup | Qt.FramelessWindowHint)  # 无边框弹出窗口
        dialog.resize(400, 300)
        
        # 定位到状态栏右下角
        status_bar_pos = self.status_bar.mapToGlobal(self.status_bar.rect().bottomRight())
        dialog.move(status_bar_pos.x() - dialog.width(), status_bar_pos.y() - dialog.height())
        
        # 主布局
        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # 头部
        header = QWidget()
        header.setStyleSheet("background-color: #2d2d2d; padding: 10px;")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(10, 5, 10, 5)
        
        title = QLabel("通知")
        title.setStyleSheet("color: #cccccc; font-weight: bold; font-size: 13px;")
        header_layout.addWidget(title)
        header_layout.addStretch()
        
        # 清除所有按钮
        clear_btn = QPushButton("清除所有")
        clear_btn.setStyleSheet("""
            QPushButton {
                background: transparent;
                color: #cccccc;
                border: none;
                padding: 4px 8px;
                font-size: 12px;
            }
            QPushButton:hover {
                background: rgba(255, 255, 255, 0.1);
                border-radius: 3px;
            }
        """)
        clear_btn.clicked.connect(lambda: self.clear_notifications(dialog))
        header_layout.addWidget(clear_btn)
        
        layout.addWidget(header)
        
        # 通知列表（滚动区域）
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background-color: #252526; }")
        
        content = QWidget()
        content.setStyleSheet("background-color: #252526;")
        content_layout = QVBoxLayout(content)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(1)
        
        # 添加通知项
        if not self.notifications:
            no_notif = QLabel("暂无通知")
            no_notif.setStyleSheet("color: #969696; padding: 20px; font-size: 13px;")
            no_notif.setAlignment(Qt.AlignCenter)
            content_layout.addWidget(no_notif)
        else:
            for notif in self.notifications:
                notif_item = self.create_notification_item(notif)
                content_layout.addWidget(notif_item)
        
        content_layout.addStretch()
        scroll.setWidget(content)
        layout.addWidget(scroll)
        
        # 应用样式
        dialog.setStyleSheet("""
            QDialog {
                background-color: #252526;
                border: 1px solid #2b2b2b;
            }
        """)
        
        dialog.exec()
    
    def create_notification_item(self, notif):
        """创建单个通知项"""
        item = QWidget()
        item.setStyleSheet("""
            QWidget {
                background-color: #2d2d2d;
                padding: 10px;
            }
            QWidget:hover {
                background-color: #37373d;
            }
        """)
        
        layout = QHBoxLayout(item)
        layout.setContentsMargins(10, 8, 10, 8)
        
        # 图标
        icon_map = {
            "info": ('fa5s.info-circle', "#59a4f9"),
            "warning": ('fa5s.exclamation-triangle', "#cca700"),
            "error": ('fa5s.times-circle', "#f14c4c")
        }
        icon_name, icon_color = icon_map.get(notif["level"], ('fa5s.info-circle', "#59a4f9"))
        
        icon = QLabel()
        icon_pixmap = qta.icon(icon_name, color=icon_color).pixmap(16, 16)
        icon.setPixmap(icon_pixmap)
        icon.setFixedWidth(30)
        layout.addWidget(icon)
        
        # 消息文本
        message = QLabel(notif["message"])
        message.setStyleSheet("color: #cccccc; font-size: 13px;")
        message.setWordWrap(True)
        layout.addWidget(message, 1)
        
        return item
    
    def clear_notifications(self, dialog):
        """清除所有通知"""
        self.notifications.clear()
        # 恢复铃铛默认样式
        self.notification_btn.setIcon(qta.icon('fa5s.bell', color='white'))
        dialog.close()


# MARK: - Application Entry Point
# MARK: - 应用程序入口
if __name__ == "__main__":
    # QApplication: Qt 程序入口，管理事件循环，必须在创建任何窗口前实例化
    app = QApplication(sys.argv)
    
    # 设置应用图标
    icon_path = resource_path("icon.ico")
    if not os.path.exists(icon_path):
        icon_path = resource_path("Hajimi_Label_icon.png")
    if os.path.exists(icon_path):
        app.setWindowIcon(QIcon(icon_path))

    window = MainWindow()
    window.show()  # Qt 窗口默认隐藏，必须显式调用
    
    # exec(): 启动事件循环，阻塞直到程序退出
    # sys.exit(): 将 Qt 返回码传递给操作系统
    sys.exit(app.exec())
