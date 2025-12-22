import Foundation
import SwiftUI
import Combine

// MARK: - 应用标签页枚举

/// 定义应用程序的四个主要功能模块
/// 这个枚举用于在不同的视图间切换，类似于 VS Code 的侧边栏标签页
enum AppTab {
    case review      // 审核模式：逐张查看图片并标记
    case overview    // 总览模式：以无限画布形式显示所有图片
    case stats       // 统计模式：显示审核统计数据
    case settings    // 设置模式：配置应用参数
}

// MARK: - 应用主数据模型

/// 应用程序的核心数据模型类
/// 负责管理所有与业务逻辑相关的状态和操作
/// 使用 ObservableObject 协议使得 SwiftUI 视图能够自动响应数据变化
class AppModel: ObservableObject {
    
    // MARK: - Published Properties
    // 以下属性使用 @Published 修饰，当它们变化时会自动通知 SwiftUI 更新视图
    
    /// 当前激活的标签页，默认显示审核模式
    @Published var activeTab: AppTab = .review
    
    /// 当前打开的文件夹的 URL
    /// 使用 Optional 类型，因为应用启动时可能没有打开任何文件夹
    @Published var currentFolder: URL?
    
    /// 当前文件夹中的所有图片文件的 URL 数组
    /// 按文件名字典序排列，便于用户查找
    @Published var files: [URL] = []
    
    /// 当前选中的图片文件
    /// 在审核模式下，这是正在显示在编辑器中的图片
    @Published var selectedFile: URL?
    
    /// 审核结果字典，键为文件名，值为审核状态（"pass", "fail", "invalid"）
    /// 这个数据会保存到 review_results.json 文件中，实现持久化存储
    @Published var results: [String: String] = [:]
    
    /// 错误消息，用于向用户显示操作失败的原因
    /// Optional 类型，没有错误时为 nil
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    /// 计算得出的统计数据
    /// 返回一个元组，包含五个整数：总数、通过数、未通过数、无效数、未审核数
    /// 这是一个计算属性，每次访问时都会根据当前的 files 和 results 重新计算
    var stats: (total: Int, passed: Int, failed: Int, invalid: Int, unreviewed: Int) {
        // 总文件数 = 文件列表的长度
        let total = files.count
        
        // 通过数 = results 字典中值为 "pass" 的项目数
        let passed = results.values.filter { $0 == "pass" }.count
        
        // 未通过数 = results 字典中值为 "fail" 的项目数
        let failed = results.values.filter { $0 == "fail" }.count
        
        // 无效数 = results 字典中值为 "invalid" 的项目数
        let invalid = results.values.filter { $0 == "invalid" }.count
        
        // 未审核数 = 总数 - 已审核的所有项目
        // 这里使用减法而不是过滤，因为未审核的文件在 results 字典中不存在
        let unreviewed = total - passed - failed - invalid
        
        return (total, passed, failed, invalid, unreviewed)
    }
    
    // MARK: - File Operations
    
    /// 打开文件夹选择对话框，允许用户选择一个包含图片的文件夹
    /// 这个方法会：
    /// 1. 显示系统的文件夹选择对话框
    /// 2. 处理 macOS 沙盒化的安全访问权限
    /// 3. 加载选中文件夹中的所有图片文件
    /// 4. 创建或加载 review_results.json 文件
    func openFolder() {
        // 创建 NSOpenPanel 对话框实例
        // NSOpenPanel 是 macOS 特有的文件选择器，与 SwiftUI 的 fileImporter 相比更加灵活
        let panel = NSOpenPanel()
        
        // 配置对话框：不允许选择文件，只能选择文件夹
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        
        // 不允许多选，一次只能选择一个文件夹
        panel.allowsMultipleSelection = false
        
        // 显示对话框并等待用户操作
        // runModal() 会阻塞线程，直到用户点击“打开”或“取消”
        if panel.runModal() == .OK {
            // 用户点击了“打开”按钮
            if let url = panel.url {
                // 获取用户选择的文件夹 URL
                
                // 如果之前已经打开了一个文件夹，需要释放其安全作用域访问权限
                // 这是 macOS 沙监机制的要求，防止应用滥用文件访问权限
                if let oldUrl = self.currentFolder {
                    oldUrl.stopAccessingSecurityScopedResource()
                }
                
                // 请求对新文件夹的安全作用域访问权限
                // 这对于 App Sandbox 应用是必需的
                if url.startAccessingSecurityScopedResource() {
                    // 权限获取成功
                    self.currentFolder = url
                    loadFiles(from: url)
                    ensureResultsFileExists()
                    loadResults()
                } else {
                    // 权限获取失败，但仍然尝试加载
                    // 对于非沙监应用或用户自己的文件夹，可能不需要此权限
                    self.errorMessage = "Failed to obtain access permissions for the selected folder."
                    self.currentFolder = url
                    loadFiles(from: url)
                    ensureResultsFileExists()
                    loadResults()
                }
            }
        }
        // 如果用户点击了“取消”，什么也不做
    }
    
    func loadFiles(from url: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff"]
            self.files = fileURLs.filter { url in
                imageExtensions.contains(url.pathExtension.lowercased())
            }.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            
            if !files.isEmpty {
                selectedFile = files.first
            }
        } catch {
            print("Error loading files: \(error)")
        }
    }
    
    func loadResults() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")
        
        do {
            let data = try Data(contentsOf: resultsURL)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                self.results = json
            }
        } catch {
            print("No existing results or error loading: \(error)")
            self.results = [:]
        }
    }
    
    func saveResults() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
            try data.write(to: resultsURL)
        } catch {
            print("Error saving results: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to save results: \(error.localizedDescription)"
            }
        }
    }
    
    func labelCurrentFile(status: String) {
        guard let file = selectedFile else { return }
        let filename = file.lastPathComponent
        results[filename] = status
        saveResults()
        
        // Auto-advance to next file
        if let index = files.firstIndex(of: file), index + 1 < files.count {
            selectedFile = files[index + 1]
        }
    }
    
    func ensureResultsFileExists() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")

        // Always try to create if not exists, even if we just loaded
        if !FileManager.default.fileExists(atPath: resultsURL.path) {
            do {
                let emptyResults: [String: String] = [:]
                let data = try JSONSerialization.data(withJSONObject: emptyResults, options: .prettyPrinted)
                try data.write(to: resultsURL)
                print("Created empty review_results.json at \(resultsURL.path)")
            } catch {
                print("Error creating review_results.json: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create review_results.json: \(error.localizedDescription)"
                }
            }
        }
    }
}
