//
//  StatusBarView.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

// MARK: - Status Bar View
// MARK: - 状态栏视图

/// The status bar at the bottom of the window.
/// Displays current file info, review statistics, and system messages.
///
/// 窗口底部的状态栏。
/// 显示当前文件信息、审核统计数据和系统消息。
struct StatusBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        HStack(spacing: 15) {
            // Left Section: Current Context
            // 左侧区域：当前上下文
            HStack(spacing: 5) {
                Image(systemName: "folder")
                Text(appModel.currentFolder?.lastPathComponent ?? NSLocalizedString("no_folder", comment: ""))
            }
            
            // Display current file info if selected.
            // 如果选中了文件，显示当前文件信息。
            if let selected = appModel.selectedFile {
                HStack(spacing: 5) {
                    Image(systemName: "doc")
                    Text(selected.lastPathComponent)
                    
                    // Status of current file.
                    // 当前文件的状态。
                    if let status = appModel.results[selected.lastPathComponent] {
                        Text("[\(NSLocalizedString(status, comment: ""))]")
                            .foregroundColor(statusColor(status))
                    } else {
                        Text("[\(NSLocalizedString("unreviewed", comment: ""))]")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Right Section: Statistics and Notifications
            // 右侧区域：统计数据和通知
            
            // Access computed stats property.
            // 访问计算属性 stats。
            let stats = appModel.stats
            Text("\(NSLocalizedString("passed", comment: "")): \(stats.passed)")
            Text("\(NSLocalizedString("failed", comment: "")): \(stats.failed)")
            Text("\(NSLocalizedString("unreviewed", comment: "")): \(stats.unreviewed)")
            
            // Notification / Error Area.
            // 通知/错误区域。
            HStack(spacing: 5) {
                if let error = appModel.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .foregroundColor(.yellow)
                        .lineLimit(1) // Truncate if too long. (如果太长则截断)
                } else {
                    Image(systemName: "bell")
                    Text(NSLocalizedString("status_ready", comment: ""))
                }
            }
        }
        .font(.system(size: 11)) // Small font for status bar. (状态栏使用小字体)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundColor(.white)
        .background(Color(hex: "007acc")) // VS Code Blue background. (VS Code 蓝色背景)
    }
    
    /// Helper to determine color based on status string.
    ///
    /// 根据状态字符串确定颜色的辅助方法。
    func statusColor(_ status: String) -> Color {
        switch status {
        case "pass": return .green
        case "fail": return .red
        case "invalid": return .yellow
        default: return .gray
        }
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarView(appModel: AppModel())
    }
}
