import sys
import os
import json
from PySide6.QtWidgets import QApplication, QMainWindow, QWidget, QHBoxLayout, QStackedWidget, QStatusBar, QLabel
from PySide6.QtCore import QFile, QTextStream

from ui import ActivityBar, SideBar, EditorArea, StatsView

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Label Review - VS Code Style")
        self.resize(1200, 800)

        # Central Widget
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.main_layout = QHBoxLayout(self.central_widget)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.main_layout.setSpacing(0)

        # Components
        self.activity_bar = ActivityBar()
        self.side_bar = SideBar()
        
        # Content Area (Stacked for Review vs Stats)
        self.content_stack = QStackedWidget()
        
        self.editor_area = EditorArea()
        self.stats_view = StatsView()
        
        self.content_stack.addWidget(self.editor_area)
        self.content_stack.addWidget(self.stats_view)

        # Layout Assembly
        self.main_layout.addWidget(self.activity_bar)
        self.main_layout.addWidget(self.side_bar)
        self.main_layout.addWidget(self.content_stack)

        # Status Bar
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_label = QLabel("Ready")
        self.status_bar.addWidget(self.status_label)

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

    def load_stylesheet(self):
        style_file = QFile("assets/style.qss")
        if style_file.open(QFile.ReadOnly | QFile.Text):
            stream = QTextStream(style_file)
            self.setStyleSheet(stream.readAll())

    def switch_page(self, page_name):
        if page_name == "Review":
            self.content_stack.setCurrentWidget(self.editor_area)
            self.side_bar.setVisible(True)
        elif page_name == "Statistics":
            self.update_stats()
            self.content_stack.setCurrentWidget(self.stats_view)
            self.side_bar.setVisible(False)

    def load_folder(self, folder_path):
        self.current_folder = folder_path
        self.files = [f for f in os.listdir(folder_path) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
        self.side_bar.set_files(self.files)
        self.load_results()
        self.status_label.setText(f"Loaded {len(self.files)} images from {folder_path}")

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
        
        status = self.results.get(filename, "Unreviewed")
        self.status_label.setText(f"Reviewing: {filename} | Status: {status}")

    def handle_decision(self, decision):
        if not self.current_file:
            return
        
        self.results[self.current_file] = decision
        self.save_results()
        self.status_label.setText(f"Marked {self.current_file} as {decision}")
        
        # Auto-advance
        current_row = self.side_bar.file_list.currentRow()
        if current_row < self.side_bar.file_list.count() - 1:
            self.side_bar.file_list.setCurrentRow(current_row + 1)
        else:
            self.status_label.setText("All files reviewed!")

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
