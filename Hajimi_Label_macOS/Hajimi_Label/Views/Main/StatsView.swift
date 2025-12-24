import SwiftUI
import UniformTypeIdentifiers

/// Displays review statistics and provides export functionality.
///
/// 显示审核统计数据并提供导出功能。
struct StatsView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            // 标题
            Text("stats_title")
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            // Access computed stats.
            // 访问计算出的统计数据。
            let stats = appModel.stats
            
            // Display statistics rows.
            // 显示统计行。
            Group {
                StatRow(label: "total", value: stats.total, color: .primary)
                StatRow(label: "passed", value: stats.passed, color: .green)
                StatRow(label: "failed", value: stats.failed, color: .red)
                StatRow(label: "invalid", value: stats.invalid, color: .yellow)
                StatRow(label: "unreviewed", value: stats.unreviewed, color: .gray)
            }
            
            Divider()
                .padding(.vertical)
            
            // Export Button
            // 导出按钮
            Button(action: exportJSON) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(NSLocalizedString("export_json", comment: "Export JSON button label"))
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// Exports the review results to a JSON file.
    /// Uses NSSavePanel to let the user choose the destination.
    ///
    /// 将审核结果导出为 JSON 文件。
    /// 使用 NSSavePanel 让用户选择保存位置。
    func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "review_results.json"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    // Serialize results to JSON data.
                    // 将结果序列化为 JSON 数据。
                    let data = try JSONSerialization.data(withJSONObject: appModel.results, options: .prettyPrinted)
                    try data.write(to: url)
                } catch {
                    print("Failed to export JSON: \(error)")
                    // Update error message on main thread.
                    // 在主线程上更新错误消息。
                    DispatchQueue.main.async {
                        appModel.errorMessage = "Export failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

/// A reusable row component for displaying a single statistic.
///
/// 用于显示单个统计数据的可重用行组件。
struct StatRow: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(NSLocalizedString(label, comment: ""))
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading) // Fixed width for alignment. (固定宽度以对齐)
            
            Text("\(value)")
                .font(.title2)
                .bold()
                .foregroundColor(color)
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView(appModel: AppModel())
    }
}
