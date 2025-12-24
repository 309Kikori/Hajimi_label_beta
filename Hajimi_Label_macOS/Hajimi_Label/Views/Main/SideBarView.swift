import SwiftUI

/// The sidebar view displaying the file explorer.
/// Shows the current folder content and file status.
///
/// 显示文件资源管理器的侧边栏视图。
/// 显示当前文件夹内容和文件状态。
struct SideBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header: "EXPLORER"
            // 区域标题：“资源管理器”
            HStack {
                Text("explorer")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            
            if let folder = appModel.currentFolder {
                // Folder Name Header
                // 文件夹名称标题
                HStack {
                    Text("📂 \(folder.lastPathComponent)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                
                // File List
                // Uses `id: \.self` because URLs are Hashable.
                // Binds selection to `appModel.selectedFile`.
                //
                // 文件列表。
                // 使用 `id: \.self` 因为 URL 是 Hashable 的。
                // 将选择绑定到 `appModel.selectedFile`。
                List(appModel.files, id: \.self, selection: $appModel.selectedFile) { file in
                    HStack {
                        // Status Icon (Checkmark, X, etc.)
                        // 状态图标（对号、叉号等）
                        StatusIcon(status: appModel.results[file.lastPathComponent] ?? "unreviewed")
                        
                        // Filename
                        // 文件名
                        Text(file.lastPathComponent)
                            .font(.system(size: 13))
                    }
                    .tag(file) // Tag is essential for selection to work in List. (Tag 对于列表中的选择功能至关重要)
                }
                .listStyle(SidebarListStyle()) // Use standard macOS sidebar styling. (使用标准 macOS 侧边栏样式)
            } else {
                // Empty State: Prompt user to open a folder.
                // 空状态：提示用户打开文件夹。
                VStack(spacing: 20) {
                    Spacer()
                    Text("no_folder")
                        .foregroundColor(.secondary)
                    Button("open_folder") {
                        appModel.openFolder()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Helper view to display a status icon based on the review result.
///
/// 基于审核结果显示状态图标的辅助视图。
struct StatusIcon: View {
    let status: String
    
    var body: some View {
        switch status {
        case "pass":
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case "fail":
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case "invalid":
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
        default:
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        }
    }
}

struct SideBarView_Previews: PreviewProvider {
    static var previews: some View {
        SideBarView(appModel: AppModel())
    }
}



