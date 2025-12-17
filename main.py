import sys
import os
import json
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QHBoxLayout, QStackedWidget, 
    QStatusBar, QLabel, QSplitter, QMenuBar, QMenu, QCheckBox, QDialog, QVBoxLayout,
    QLineEdit, QFormLayout, QScrollArea
)
from PySide6.QtCore import QFile, QTextStream, Qt
from PySide6.QtGui import QAction

from ui import ActivityBar, SideBar, EditorArea, StatsView
from overview import OverviewPage
from localization import tr

class SettingsDialog(QDialog):
    def __init__(self, parent=None, config=None):
        super().__init__(parent)
        self.setWindowTitle(tr("settings_title"))
        self.resize(600, 400)
        self.config = config
        
        # VS Code Style Layout
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0,0,0,0)
        
        # Search Bar (Visual only for now)
        self.search_bar = QLineEdit()
        self.search_bar.setPlaceholderText("Search settings...")
        self.search_bar.setStyleSheet("""
            QLineEdit {
                background-color: #3c3c3c;
                color: #cccccc;
                border: 1px solid #3c3c3c;
                padding: 5px;
                margin: 10px;
            }
            QLineEdit:focus {
                border: 1px solid #007acc;
            }
        """)
        self.layout.addWidget(self.search_bar)
        
        # Scroll Area
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setStyleSheet("QScrollArea { border: none; background-color: #1e1e1e; }")
        self.content = QWidget()
        self.content.setStyleSheet("background-color: #1e1e1e;")
        self.form_layout = QFormLayout(self.content)
        self.form_layout.setLabelAlignment(Qt.AlignLeft)
        self.form_layout.setFormAlignment(Qt.AlignLeft | Qt.AlignTop)
        self.form_layout.setSpacing(15)
        self.form_layout.setContentsMargins(20, 10, 20, 10)
        
        # --- Settings Items ---
        
        # Section: Appearance
        self.add_section_header(tr("appearance"))
        
        self.inp_grid_size = QLineEdit(str(self.config.get("grid_size", 40)))
        self.add_setting_row(tr("grid_size"), self.inp_grid_size)
        
        self.inp_grid_color = QLineEdit(self.config.get("grid_color", "#333333"))
        self.add_setting_row(tr("grid_color"), self.inp_grid_color)
        
        self.inp_bg_color = QLineEdit(self.config.get("bg_color", "#1e1e1e"))
        self.add_setting_row(tr("bg_color"), self.inp_bg_color)

        self.inp_max_width = QLineEdit(str(self.config.get("max_image_width", 1600)))
        self.add_setting_row(tr("max_image_width"), self.inp_max_width)

        # Section: Behavior
        self.add_section_header(tr("behavior"))
        
        self.cb_overview = QCheckBox()
        self.cb_overview.setChecked(self.config.get("enable_overview", True))
        self.add_setting_row(tr("enable_overview"), self.cb_overview)
        
        self.scroll.setWidget(self.content)
        self.layout.addWidget(self.scroll)

    def add_section_header(self, text):
        label = QLabel(text)
        label.setStyleSheet("font-weight: bold; font-size: 14px; color: #ffffff; margin-top: 10px; margin-bottom: 5px;")
        self.form_layout.addRow(label)

    def add_setting_row(self, label_text, widget):
        label = QLabel(label_text)
        label.setStyleSheet("color: #cccccc;")
        
        if isinstance(widget, QLineEdit):
            widget.setStyleSheet("""
                QLineEdit {
                    background-color: #3c3c3c;
                    color: #cccccc;
                    border: 1px solid #3c3c3c;
                    padding: 4px;
                }
                QLineEdit:focus {
                    border: 1px solid #007acc;
                }
            """)
        
        self.form_layout.addRow(label, widget)

    def closeEvent(self, event):
        # Save config
        self.config["enable_overview"] = self.cb_overview.isChecked()
        try:
            self.config["grid_size"] = int(self.inp_grid_size.text())
        except:
            pass
        try:
            self.config["max_image_width"] = int(self.inp_max_width.text())
        except:
            pass
        self.config["grid_color"] = self.inp_grid_color.text()
        self.config["bg_color"] = self.inp_bg_color.text()
        
        super().closeEvent(event)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(tr("app_title"))
        self.resize(1200, 800)
        
        # Config Defaults
        self.config = {
            "enable_overview": True,
            "grid_size": 40,
            "grid_color": "#333333",
            "bg_color": "#1e1e1e",
            "max_image_width": 1600
        }

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
        self.overview_page = OverviewPage(config=self.config)
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
        
        self.stats_status_label = QLabel("")
        self.stats_status_label.setObjectName("StatusLabel")
        self.status_bar.addPermanentWidget(self.stats_status_label)
        
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
        self.stats_status_label.setText("")
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
        self.overview_page.update_config()

    def load_folder(self, folder_path):
        self.current_folder = folder_path
        self.files = [f for f in os.listdir(folder_path) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
        self.load_results()
        
        folder_name = os.path.basename(folder_path)
        self.side_bar.set_files(self.files, self.results, folder_name)
        
        self.status_label.setText(tr("loaded_images", len(self.files), folder_path))
        self.update_stats_status()
        
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
        self.side_bar.update_file_status(self.current_file, decision)
        self.status_label.setText(tr("marked_as", self.current_file, tr(decision)))
        self.update_stats_status()
        
        # Auto-advance
        current_row = self.side_bar.file_list.currentRow()
        if current_row < self.side_bar.file_list.count() - 1:
            self.side_bar.file_list.setCurrentRow(current_row + 1)
        else:
            self.status_label.setText(tr("all_reviewed"))

    def update_stats(self):
        current_files = set(self.files)
        valid_results = {k: v for k, v in self.results.items() if k in current_files}
        
        total_files = len(self.files)
        passed = sum(1 for v in valid_results.values() if v == "pass")
        failed = sum(1 for v in valid_results.values() if v == "fail")
        invalid = sum(1 for v in valid_results.values() if v == "invalid")
        unreviewed = total_files - len(valid_results)
        
        self.stats_view.update_stats(total_files, passed, failed, invalid, unreviewed)

    def update_stats_status(self):
        current_files = set(self.files)
        valid_results = {k: v for k, v in self.results.items() if k in current_files}
        
        total_files = len(self.files)
        passed = sum(1 for v in valid_results.values() if v == "pass")
        failed = sum(1 for v in valid_results.values() if v == "fail")
        invalid = sum(1 for v in valid_results.values() if v == "invalid")
        unreviewed = total_files - len(valid_results)
        
        self.stats_status_label.setText(tr("stats_status", total_files, passed, failed, invalid, unreviewed))

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
