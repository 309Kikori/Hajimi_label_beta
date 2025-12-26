# localization.py

class Translator:
    def __init__(self):
        self.current_lang = "zh_CN"
        self.translations = {
            "en_US": {
                "app_title": "hajimi Label Review -",
                "explorer": "EXPLORER",
                "open_folder": "OPEN FOLDER",
                "no_folder": "NO FOLDER OPENED",
                "review": "Review",
                "statistics": "Statistics",
                "pass": "Pass",
                "fail": "Fail",
                "ready": "",
                "loaded_images": "Loaded {} images from {}",
                "reviewing": "Reviewing: {} | Status: {}",
                "marked_as": "Marked {} as {}",
                "all_reviewed": "All files reviewed!",
                "total": "Total",
                "passed": "Passed",
                "failed": "Failed",
                "unreviewed": "Unreviewed",
                "no_file_selected": "No file selected",
                "stats_title": "Review Statistics",
                "files": "FILES",
                "settings": "Manage",
                "file_menu": "File",
                "close_folder": "Close Folder",
                "exit": "Exit",
                "welcome_title": "Visual Studio Code",
                "welcome_subtitle": "Editing evolved",
                "start": "Start",
                "recent": "Recent",
                "overview": "Overview",
                "overview_title": "Image Overview",
                "auto_arrange": "Auto Arrange",
                "enable_overview": "Enable Overview Page",
                "invalid": "Invalid",
                "grid_size": "Grid Size",
                "grid_color": "Grid Color",
                "bg_color": "Background Color",
                "max_image_width": "Max Image Width (px)",
                "settings_title": "Settings",
                "appearance": "Appearance",
                "behavior": "Behavior",
                "stats_status": "Total: {} | Pass: {} | Fail: {} | Invalid: {} | Unreviewed: {}"
            },
            "zh_CN": {
                "app_title": "🐱Hajimi Label  ",
                "explorer": "资源管理器",
                "open_folder": "打开文件夹",
                "no_folder": "未打开文件夹",
                "review": "验收",
                "statistics": "统计",
                "pass": "通过",
                "fail": "不通过",
                "ready": "",
                "loaded_images": "已加载 {} 张图片，路径：{}",
                "reviewing": "正在验收: {} | 状态: {}",
                "marked_as": "已标记 {} 为 {}",
                "all_reviewed": "所有文件已验收完毕！",
                "total": "总计",
                "passed": "通过",
                "failed": "不通过",
                "unreviewed": "未验收",
                "no_file_selected": "未选择文件",
                "stats_title": "验收统计数据",
                "files": "文件",
                "settings": "管理",
                "file_menu": "文件",
                "close_folder": "关闭文件夹",
                "exit": "退出",
                "welcome_title": "Visual Studio Code",
                "welcome_subtitle": "代码编辑，重新定义",
                "start": "开始",
                "recent": "最近",
                "overview": "总览",
                "overview_title": "图片总览看板",
                "auto_arrange": "自动排布",
                "enable_overview": "启用总览页面",
                "invalid": "无效数据",
                "grid_size": "网格间距",
                "grid_color": "网格颜色",
                "bg_color": "背景颜色",
                "max_image_width": "图片最大宽度 (px)",
                "settings_title": "设置",
                "appearance": "外观",
                "behavior": "行为",
                "stats_status": "总计: {} | 通过: {} | 不通过: {} | 无效: {} | 未验收: {}"
            }
        }

    def tr(self, key, *args):
        lang_dict = self.translations.get(self.current_lang, self.translations["en_US"])
        text = lang_dict.get(key, key)
        if args:
            return text.format(*args)
        return text

# Global instance
translator = Translator()
tr = translator.tr
