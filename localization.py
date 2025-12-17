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
                "recent": "Recent"
            },
            "zh_CN": {
                "app_title": "hajimi标注验收工具 - ",
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
                "recent": "最近"
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
