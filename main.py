import sys
import os
import json
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QHBoxLayout, QStackedWidget, 
    QStatusBar, QLabel, QSplitter, QMenuBar, QMenu, QCheckBox, QDialog, QVBoxLayout
)
from PySide6.QtCore import QFile, QTextStream, Qt
from PySide6.QtGui import QAction

from ui import ActivityBar, SideBar, EditorArea, StatsView
from overview import OverviewPage
from localization import tr

class SettingsDialog(QDialog):
    def __init__(self, parent=None, config=None):
        super().__init__(parent)
        self.setWindowTitle(tr("settings"))
        self.resize(400, 300)
        self.config = config
        
        self.layout = QVBoxLayout(self)
        
        self.cb_overview = QCheckBox(tr("enable_overview"))
        self.cb_overview.setChecked(self.config.get("enable_overview", True))
        self.layout.addWidget(self.cb_overview)
        
        self.layout.addStretch()

    def closeEvent(self, event):
        self.config["enable_overview"] = self.cb_overview.isChecked()
        super().closeEvent(event)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(tr("app_title"))
        self.resize(1200, 800)
        
        # Config
        self.config = {"enable_overview": True}

        # Central Widget
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.main_layout = QHBoxLayout(self.central_widget)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.main_layout.setSpacing(0)

        # Components
        self.activity_bar = ActivityBar()
        self.side_bar = SideBar()
        
        # Menu Bar (Must be setup after side_bar is initialized)
        self.setup_menu()
        
        # Content Area (Stacked for Review vs Stats)
        self.content_stack = QStackedWidget()
        
        self.editor_area = EditorArea()
        self.overview_page = OverviewPage()
        self.stats_view = StatsView()
        
        self.content_stack.addWidget(self.editor_area)
        self.content_stack.addWidget(self.overview_page)
        self.content_stack.addWidget(self.stats_view)

        # Splitter for SideBar and Content
        self.splitter = QSplitter(Qt.Horizontal)
        self.splitter.addWidget(self.side_bar)
        self.splitter.addWidget(self.content_stack)
        self.splitter.setStretchFactor(1, 1) # Content takes more space
        self.splitter.setHandleWidth(1) # Thin splitter like VS Code

        # Layout Assembly
        self.main_layout.addWidget(self.activity_bar)
        self.main_layout.addWidget(self.splitter)

        # Status Bar
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_label = QLabel(tr("ready"))
        self.status_label.setObjectName("StatusLabel")
        self.status_bar.addWidget(self.status_label)
        
        # Initial Status Style
        self.status_bar.setStyleSheet("background-color: #007acc; color: white;")

        # Logic Connections
        self.activity_bar.pageChanged.connect(self.switch_page)
        self.side_bar.folderOpened.connect(self.load_folder)
        self.side_bar.fileSelected.connect(self.load_file)
        self.editor_area.decisionMade.connect(self.handle_decision)

        # Data
        self.current_folder = ""
        self.current_file = ""
        self.results = {}
        self.files = []

        # Load Style
        self.load_stylesheet()
        self.apply_config()

    def setup_menu(self):
        menubar = self.menuBar()
        
        # File Menu
        file_menu = menubar.addMenu(tr("file_menu"))
        
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
        self.current_folder = ""
        self.files = []
        self.results = {}
        self.side_bar.show_no_folder()
        self.editor_area.viewer.scene.clear()
        self.editor_area.tab_label.setText(tr("no_file_selected"))
        self.overview_page.canvas.scene.clear()
        self.status_label.setText(tr("ready"))
        self.setWindowTitle(tr("app_title"))

    def load_stylesheet(self):
        style_file = QFile("assets/style.qss")
        if style_file.open(QFile.ReadOnly | QFile.Text):
            stream = QTextStream(style_file)
            self.setStyleSheet(stream.readAll())

    def switch_page(self, page_name):
        if page_name == "Review":
            self.content_stack.setCurrentWidget(self.editor_area)
            self.side_bar.setVisible(True)
        elif page_name == "Overview":
            self.content_stack.setCurrentWidget(self.overview_page)
            self.side_bar.setVisible(False) # Overview usually needs more space
        elif page_name == "Statistics":
            self.update_stats()
            self.content_stack.setCurrentWidget(self.stats_view)
            self.side_bar.setVisible(False)
        elif page_name == "Settings":
            self.open_settings()

    def open_settings(self):
        dlg = SettingsDialog(self, self.config)
        dlg.exec()
        self.apply_config()
        # Reset to previous view or stay? Let's go back to Review for now
        self.activity_bar.btn_review.click()

    def apply_config(self):
        enabled = self.config.get("enable_overview", True)
        self.activity_bar.btn_overview.setVisible(enabled)

    def load_folder(self, folder_path):
        self.current_folder = folder_path
        self.files = [f for f in os.listdir(folder_path) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
        self.side_bar.set_files(self.files)
        self.load_results()
        self.status_label.setText(tr("loaded_images", len(self.files), folder_path))
        
        # Load Overview
        if self.config.get("enable_overview", True):
            self.overview_page.load_images(folder_path, self.files)

    def load_results(self):
        result_path = os.path.join(self.current_folder, "review_results.json")
        if os.path.exists(result_path):
            try:
                with open(result_path, 'r', encoding='utf-8') as f:
                    self.results = json.load(f)
            except:
                self.results = {}
        else:
            self.results = {}

    def save_results(self):
        if not self.current_folder:
            return
        result_path = os.path.join(self.current_folder, "review_results.json")
        with open(result_path, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, ensure_ascii=False)

    def load_file(self, filename):
        self.current_file = filename
        full_path = os.path.join(self.current_folder, filename)
        self.editor_area.load_image(full_path)
        
        status = self.results.get(filename, tr("unreviewed"))
        self.status_label.setText(tr("reviewing", filename, status))

    def handle_decision(self, decision):
        if not self.current_file:
            return
        
        self.results[self.current_file] = decision
        self.save_results()
        self.status_label.setText(tr("marked_as", self.current_file, tr(decision)))
        
        # Auto-advance
        current_row = self.side_bar.file_list.currentRow()
        if current_row < self.side_bar.file_list.count() - 1:
            self.side_bar.file_list.setCurrentRow(current_row + 1)
        else:
            self.status_label.setText(tr("all_reviewed"))

    def update_stats(self):
        total = len(self.results)
        passed = sum(1 for v in self.results.values() if v == "pass")
        failed = sum(1 for v in self.results.values() if v == "fail")
        self.stats_view.update_stats(total, passed, failed)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
