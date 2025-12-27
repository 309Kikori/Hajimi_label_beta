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
    @State private var showNotifications = false
    
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
            Button(action: {
                showNotifications.toggle()
            }) {
                HStack(spacing: 5) {
                    // Icon
                    // 图标
                    Image(systemName: notificationIconName)
                        .foregroundColor(notificationIconColor)
                    
                    // Text (Latest notification or Ready)
                    // 文本（最新通知或就绪）
                    if let message = appModel.statusMessage {
                        Text(message)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 200, alignment: .leading)
                    } else {
                        Text(NSLocalizedString("status_ready", comment: ""))
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showNotifications, arrowEdge: .bottom) {
                NotificationPopoverView(appModel: appModel, isPresented: $showNotifications)
            }
        }
        .font(.system(size: 11)) // Small font for status bar. (状态栏使用小字体)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundColor(.white)
        .background(Color(hex: "007acc")) // VS Code Blue background. (VS Code 蓝色背景)
    }
    
    // MARK: - Computed Properties
    
    private var notificationIconName: String {
        // If there is a status message (active notification), show badge
        // 如果有状态消息（活动通知），显示徽章
        if appModel.statusMessage != nil {
            return "bell.badge"
        }
        // Otherwise, if there are unread notifications in history, maybe show badge?
        // Or just show normal bell if status message is gone.
        // User requested "revert to default state", which implies normal bell.
        // 否则，如果状态消息已消失，用户要求“恢复默认状态”，这意味着显示普通铃铛。
        return "bell"
    }
    
    private var notificationIconColor: Color {
        // If the active status message corresponds to an error, show red bell
        // 如果活动状态消息对应错误，显示红色铃铛
        if appModel.statusMessage != nil, let last = appModel.notifications.last, last.level == .error {
            return .red
        }
        return .white
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
