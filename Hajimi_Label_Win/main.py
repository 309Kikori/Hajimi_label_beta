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
)

from PySide6.QtCore import QFile, QTextStream, Qt
from PySide6.QtGui import QAction, QIcon

from ui import ActivityBar, SideBar, EditorArea, StatsView
from overview import OverviewPage
from localization import tr  # 国际化函数: tr("key") 返回当前语言的翻译


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
        base_path = os.path.abspath(".")  # 开发环境
    return os.path.join(base_path, relative_path)


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
                border: 1px solid #3c3c3c; padding: 5px; margin: 10px;
            }
            QLineEdit:focus { border: 1px solid #007acc; }
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
        label.setStyleSheet("color: #cccccc;")
        
        if isinstance(widget, QLineEdit):
            widget.setStyleSheet("""
                QLineEdit {
                    background-color: #3c3c3c; color: #cccccc;
                    border: 1px solid #3c3c3c; padding: 4px;
                }
                QLineEdit:focus { border: 1px solid #007acc; }
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
        
        self.status_label = QLabel(tr("ready"))
        self.status_label.setObjectName("StatusLabel")  # 用于 QSS 选择器
        self.status_bar.addWidget(self.status_label)
        
        # addPermanentWidget: 添加到状态栏右侧
        self.stats_status_label = QLabel("")
        self.stats_status_label.setObjectName("StatusLabel")
        self.status_bar.addPermanentWidget(self.stats_status_label)
        
        self.status_bar.setStyleSheet("background-color: #007acc; color: white;")

        # 信号-槽连接: signal.connect(slot)
        self.activity_bar.pageChanged.connect(self.switch_page)
        self.side_bar.folderOpened.connect(self.load_folder)
        self.side_bar.fileSelected.connect(self.load_file)
        self.editor_area.decisionMade.connect(self.handle_decision)

        # 数据状态
        self.current_folder = ""
        self.current_file = ""
        self.results = {}  # {filename: "pass"/"fail"/"invalid"}
        self.files = []    # 图像文件名列表

        self.load_stylesheet()
        self.apply_config()

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
        
        self.status_label.setText(tr("loaded_images", len(self.files), folder_path))
        self.update_stats_status()
        
        if self.config.get("enable_overview", True):
            self.overview_page.load_images(folder_path, self.files)

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
