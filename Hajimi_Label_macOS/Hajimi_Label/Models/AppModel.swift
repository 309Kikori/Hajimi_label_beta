import Foundation
import SwiftUI
import Combine

// MARK: - Notification Types
// MARK: - 通知类型

/// Notification level enumeration.
/// 通知级别枚举。
enum NotificationLevel: String {
    case info
    case warning
    case error
}

/// Notification item structure.
/// 通知项结构体。
struct NotificationItem: Identifiable {
    let id = UUID()
    let message: String
    let level: NotificationLevel
    let timestamp = Date()
}

// MARK: - Application Tab Enumeration
// MARK: - 应用标签页枚举

/// Defines the four main functional modules of the application.
/// This enum is used to switch between different views, similar to the sidebar tabs in VS Code.
///
/// 定义应用程序的四个主要功能模块。
/// 这个枚举用于在不同的视图间切换，类似于 VS Code 的侧边栏标签页。
enum AppTab {
    case review      // Review Mode: View images one by one and label them. (审核模式：逐张查看图片并标记)
    case overview    // Overview Mode: Display all images on an infinite canvas. (总览模式：以无限画布形式显示所有图片)
    case stats       // Statistics Mode: Display review statistics. (统计模式：显示审核统计数据)
    case settings    // Settings Mode: Configure application parameters. (设置模式：配置应用参数)
}

// MARK: - Application Main Data Model
// MARK: - 应用主数据模型

/// The core data model class of the application.
/// Responsible for managing all state and operations related to business logic.
/// Conforms to ObservableObject protocol so SwiftUI views can automatically react to data changes.
///
/// 应用程序的核心数据模型类。
/// 负责管理所有与业务逻辑相关的状态和操作。
/// 遵循 ObservableObject 协议，使得 SwiftUI 视图能够自动响应数据变化。
class AppModel: ObservableObject {
    
    // MARK: - Published Properties
    // Properties marked with @Published will automatically notify SwiftUI to update views when they change.
    // 以下属性使用 @Published 修饰，当它们变化时会自动通知 SwiftUI 更新视图。
    
    /// The currently active tab, defaults to Review mode.
    /// 当前激活的标签页，默认显示审核模式。
    @Published var activeTab: AppTab = .review
    
    /// The URL of the currently opened folder.
    /// Optional because no folder might be opened when the app starts.
    ///
    /// 当前打开的文件夹的 URL。
    /// 使用 Optional 类型，因为应用启动时可能没有打开任何文件夹。
    @Published var currentFolder: URL?
    
    /// Array of URLs for all image files in the current folder.
    /// Sorted lexicographically by filename for consistent ordering.
    ///
    /// 当前文件夹中的所有图片文件的 URL 数组。
    /// 按文件名字典序排列，便于用户查找。
    @Published var files: [URL] = []
    
    /// The currently selected image file.
    /// In Review mode, this is the image being displayed in the editor.
    ///
    /// 当前选中的图片文件。
    /// 在审核模式下，这是正在显示在编辑器中的图片。
    @Published var selectedFile: URL?
    
    /// Dictionary storing review results.
    /// Key: Filename, Value: Review status ("pass", "fail", "invalid").
    /// This data is persisted to the `review_results.json` file.
    ///
    /// 审核结果字典。
    /// 键为文件名，值为审核状态（"pass", "fail", "invalid"）。
    /// 这个数据会保存到 review_results.json 文件中，实现持久化存储。
    @Published var results: [String: String] = [:]
    
    /// Error message used to display operation failure reasons to the user.
    /// Optional, nil when there is no error.
    ///
    /// 错误消息，用于向用户显示操作失败的原因。
    /// Optional 类型，没有错误时为 nil。
    @Published var errorMessage: String?

    /// List of notifications.
    /// 通知列表。
    @Published var notifications: [NotificationItem] = []
    
    // MARK: - Computed Properties
    // MARK: - 计算属性
    
    /// Calculated statistics data.
    /// Returns a tuple containing five integers: total, passed, failed, invalid, and unreviewed.
    /// This is a computed property, recalculated every time it's accessed based on current `files` and `results`.
    ///
    /// 计算得出的统计数据。
    /// 返回一个元组，包含五个整数：总数、通过数、未通过数、无效数、未审核数。
    /// 这是一个计算属性，每次访问时都会根据当前的 files 和 results 重新计算。
    var stats: (total: Int, passed: Int, failed: Int, invalid: Int, unreviewed: Int) {
        // Total files count.
        // 总文件数。
        let total = files.count
        
        // Count of items marked as "pass".
        // 通过数 = results 字典中值为 "pass" 的项目数。
        let passed = results.values.filter { $0 == "pass" }.count
        
        // Count of items marked as "fail".
        // 未通过数 = results 字典中值为 "fail" 的项目数。
        let failed = results.values.filter { $0 == "fail" }.count
        
        // Count of items marked as "invalid".
        // 无效数 = results 字典中值为 "invalid" 的项目数。
        let invalid = results.values.filter { $0 == "invalid" }.count
        
        // Unreviewed count = Total - (Passed + Failed + Invalid).
        // Using subtraction is more efficient than filtering for missing keys.
        //
        // 未审核数 = 总数 - 已审核的所有项目。
        // 这里使用减法而不是过滤，因为未审核的文件在 results 字典中不存在。
        let unreviewed = total - passed - failed - invalid
        
        return (total, passed, failed, invalid, unreviewed)
    }
    
    // MARK: - Notification Management
    // MARK: - 通知管理
    
    /// Add a notification.
    /// 添加通知。
    func addNotification(_ message: String, level: NotificationLevel = .info) {
        let notification = NotificationItem(message: message, level: level)
        notifications.append(notification)
    }
    
    /// Clear all notifications.
    /// 清除所有通知。
    func clearNotifications() {
        notifications.removeAll()
    }

    // MARK: - File Operations
    // MARK: - 文件操作
    
    /// Opens a folder selection dialog, allowing the user to choose a folder containing images.
    /// This method handles:
    /// 1. Displaying the system folder picker.
    /// 2. Managing macOS App Sandbox security scoping.
    /// 3. Loading image files from the selected folder.
    /// 4. Creating or loading the `review_results.json` file.
    ///
    /// 打开文件夹选择对话框，允许用户选择一个包含图片的文件夹。
    /// 这个方法会：
    /// 1. 显示系统的文件夹选择对话框。
    /// 2. 处理 macOS 沙盒化的安全访问权限。
    /// 3. 加载选中文件夹中的所有图片文件。
    /// 4. 创建或加载 review_results.json 文件。
    func openFolder() {
        // Create an NSOpenPanel instance.
        // NSOpenPanel is a macOS-specific file chooser, offering more control than SwiftUI's fileImporter.
        //
        // 创建 NSOpenPanel 对话框实例。
        // NSOpenPanel 是 macOS 特有的文件选择器，与 SwiftUI 的 fileImporter 相比更加灵活。
        let panel = NSOpenPanel()
        
        // Configure the panel: allow directories only, no files.
        // 配置对话框：不允许选择文件，只能选择文件夹。
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        
        // Disable multiple selection.
        // 不允许多选，一次只能选择一个文件夹。
        panel.allowsMultipleSelection = false
        
        // Display the panel and wait for user action.
        // runModal() blocks the thread until the user clicks "Open" or "Cancel".
        //
        // 显示对话框并等待用户操作。
        // runModal() 会阻塞线程，直到用户点击“打开”或“取消”。
        if panel.runModal() == .OK {
            // User clicked "Open".
            // 用户点击了“打开”按钮。
            if let url = panel.url {
                // Release security scope for the previously opened folder, if any.
                // This is required by macOS App Sandbox to prevent resource leaks.
                //
                // 如果之前已经打开了一个文件夹，需要释放其安全作用域访问权限。
                // 这是 macOS 沙盒机制的要求，防止应用滥用文件访问权限。
                if let oldUrl = self.currentFolder {
                    oldUrl.stopAccessingSecurityScopedResource()
                }
                
                // Request security scoped access for the new folder.
                // Essential for App Sandbox apps to access user-selected folders.
                //
                // 请求对新文件夹的安全作用域访问权限。
                // 这对于 App Sandbox 应用是必需的。
                if url.startAccessingSecurityScopedResource() {
                    // Permission granted.
                    // 权限获取成功。
                    self.currentFolder = url
                    loadFiles(from: url)
                    ensureResultsFileExists()
                    loadResults()
                } else {
                    // Permission failed, but try loading anyway (might work for non-sandboxed builds).
                    // 权限获取失败，但仍然尝试加载（对于非沙盒应用或用户自己的文件夹，可能不需要此权限）。
                    let msg = "Failed to obtain access permissions for the selected folder."
                    self.errorMessage = msg
                    self.addNotification(msg, level: .error)
                    
                    self.currentFolder = url
                    loadFiles(from: url)
                    ensureResultsFileExists()
                    loadResults()
                }
            }
        }
        // If user clicked "Cancel", do nothing.
    }
    
    /// Loads all image files from the specified directory URL.
    /// Filters for common image extensions and sorts them alphabetically.
    ///
    /// 从指定的目录 URL 加载所有图片文件。
    /// 过滤常见的图片扩展名并按字母顺序排序。
    ///
    /// - Parameter url: The URL of the directory to load files from. (要加载文件的目录 URL)
    func loadFiles(from url: URL) {
        do {
            // Get all file URLs in the directory.
            // 获取目录中的所有文件 URL。
            let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            
            // Define supported image extensions.
            // 定义支持的图片扩展名。
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff"]
            
            // Filter and sort the files.
            // 过滤并排序文件。
            self.files = fileURLs.filter { url in
                imageExtensions.contains(url.pathExtension.lowercased())
            }.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            
            // Automatically select the first file if the list is not empty.
            // 如果列表不为空，自动选中第一个文件。
            if !files.isEmpty {
                selectedFile = files.first
            }
            
            // Add notification.
            // 添加通知。
            let folderName = url.lastPathComponent
            addNotification("Loaded \(files.count) images: \(folderName)", level: .info)
            
        } catch {
            print("Error loading files: \(error)")
            // Ideally, we should set errorMessage here too.
            self.errorMessage = "Failed to load files: \(error.localizedDescription)"
            addNotification("Failed to load files: \(error.localizedDescription)", level: .error)
        }
    }
    
    /// Loads review results from the `review_results.json` file in the current folder.
    /// If the file doesn't exist or fails to load, initializes an empty results dictionary.
    ///
    /// 从当前文件夹中的 review_results.json 文件加载审核结果。
    /// 如果文件不存在或加载失败，则初始化一个空的结果字典。
    func loadResults() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")
        
        do {
            let data = try Data(contentsOf: resultsURL)
            // Deserialize JSON data into a dictionary.
            // 将 JSON 数据反序列化为字典。
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                self.results = json
            }
        } catch {
            print("No existing results or error loading: \(error)")
            self.results = [:]
        }
    }
    
    /// Saves the current review results to `review_results.json`.
    /// Uses `JSONSerialization` with pretty printing for human-readable output.
    ///
    /// 将当前的审核结果保存到 review_results.json。
    /// 使用 JSONSerialization 并开启美化输出，以便于人类阅读。
    func saveResults() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
            try data.write(to: resultsURL)
        } catch {
            print("Error saving results: \(error)")
            // Update UI on the main thread since this might be called from a background context.
            // 在主线程上更新 UI，因为此方法可能从后台上下文调用。
            DispatchQueue.main.async {
                let msg = "Failed to save results: \(error.localizedDescription)"
                self.errorMessage = msg
                self.addNotification(msg, level: .error)
            }
        }
    }
    
    /// Labels the currently selected file with a specific status.
    /// Updates the results dictionary, saves to disk, and auto-advances to the next file.
    ///
    /// 将当前选中的文件标记为特定状态。
    /// 更新结果字典，保存到磁盘，并自动跳转到下一个文件。
    ///
    /// - Parameter status: The status string ("pass", "fail", "invalid"). (状态字符串)
    func labelCurrentFile(status: String) {
        guard let file = selectedFile else { return }
        let filename = file.lastPathComponent
        
        // Update result.
        // 更新结果。
        results[filename] = status
        
        // Persist changes.
        // 持久化更改。
        saveResults()
        
        // Auto-advance logic: Find current index and move to next if available.
        // 自动跳转逻辑：查找当前索引，如果存在下一个文件则移动到下一个。
        if let index = files.firstIndex(of: file), index + 1 < files.count {
            selectedFile = files[index + 1]
        }
    }
    
    /// Ensures that `review_results.json` exists in the current folder.
    /// If not, it creates an empty JSON object `{}`.
    ///
    /// 确保当前文件夹中存在 review_results.json。
    /// 如果不存在，则创建一个空的 JSON 对象 {}。
    func ensureResultsFileExists() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")

        // Check if file exists.
        // 检查文件是否存在。
        if !FileManager.default.fileExists(atPath: resultsURL.path) {
            do {
                let emptyResults: [String: String] = [:]
                let data = try JSONSerialization.data(withJSONObject: emptyResults, options: .prettyPrinted)
                try data.write(to: resultsURL)
                print("Created empty review_results.json at \(resultsURL.path)")
            } catch {
                print("Error creating review_results.json: \(error)")
                DispatchQueue.main.async {
                    let msg = "Failed to create review_results.json: \(error.localizedDescription)"
                    self.errorMessage = msg
                    self.addNotification(msg, level: .error)
                }
            }
        }
    }
}
