//
//  ActivityBarView.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

// MARK: - Activity Bar View
// MARK: - 活动栏视图

/// The vertical navigation bar on the far left, inspired by VS Code.
/// Allows switching between the main functional modes of the application.
///
/// 最左侧的垂直导航栏，灵感来自 VS Code。
/// 允许在应用程序的主要功能模式之间进行切换。
struct ActivityBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Buttons
            // 导航按钮
            ActivityButton(icon: "eye", title: "review", tab: .review, activeTab: $appModel.activeTab)
            ActivityButton(icon: "map", title: "overview", tab: .overview, activeTab: $appModel.activeTab)
            ActivityButton(icon: "chart.bar", title: "stats_title", tab: .stats, activeTab: $appModel.activeTab)
            
            // Spacer pushes the settings button to the bottom.
            // 占位符将设置按钮推到底部。
            Spacer()
            
            ActivityButton(icon: "gear", title: "settings_title", tab: .settings, activeTab: $appModel.activeTab)
        }
        .frame(width: 50) // Fixed width for the activity bar. (活动栏的固定宽度)
        .background(Color(nsColor: .windowBackgroundColor))
        // Add a separator line on the right.
        // 在右侧添加一条分隔线。
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .trailing
        )
    }
}

// MARK: - Activity Button
// MARK: - 活动栏按钮

/// A single button in the Activity Bar.
/// Displays an icon and handles tab switching.
///
/// 活动栏中的单个按钮。
/// 显示图标并处理标签页切换。
struct ActivityButton: View {
    let icon: String
    let title: String
    let tab: AppTab
    
    /// Binding to the active tab state, allowing the button to update the global state.
    /// 绑定到活动标签页状态，允许按钮更新全局状态。
    @Binding var activeTab: AppTab
    
    var body: some View {
        Button(action: { activeTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
            }
            .frame(width: 50, height: 50)
            .contentShape(Rectangle()) // Ensure the entire area is clickable. (确保整个区域都可点击)
        }
        .buttonStyle(.plain) // Remove standard button styling. (移除标准按钮样式)
        // Highlight color based on selection state.
        // 根据选中状态设置高亮颜色。
        .foregroundColor(activeTab == tab ? .accentColor : .secondary)
        // Add a selection indicator bar on the left.
        // 在左侧添加选中指示条。
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundColor(activeTab == tab ? .accentColor : .clear)
                .padding(.vertical, 2),
            alignment: .leading
        )
        // Tooltip on hover.
        // 悬停时的工具提示。
        .help(NSLocalizedString(title, comment: ""))
    }
}

struct ActivityBarView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityBarView(appModel: AppModel())
    }
}
