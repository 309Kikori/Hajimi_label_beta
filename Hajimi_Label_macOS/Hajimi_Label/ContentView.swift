//
//  ContentView.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

// MARK: - Content View
// MARK: - 内容视图

/// The root view of the application, orchestrating the overall layout.
/// It uses a combination of Stacks and SplitViews to create a responsive interface.
///
/// 应用程序的根视图，负责协调整体布局。
/// 它结合使用了堆栈（Stacks）和分割视图（SplitViews）来创建响应式界面。
struct ContentView: View {
    // Observe changes in the shared data models.
    // When these models change, the view re-renders automatically.
    //
    // 观察共享数据模型的变化。
    // 当这些模型发生变化时，视图会自动重新渲染。
    @ObservedObject var appModel: AppModel
    @ObservedObject var settings: SettingsModel
    
    // Local state for the overview view model, owned by this view.
    // 概览视图模型的本地状态，由当前视图拥有。
    @StateObject private var overviewViewModel = OverviewViewModel()
    
    var body: some View {
        // Vertical stack to arrange the main content and the status bar.
        // 垂直堆栈，用于排列主要内容区域和底部的状态栏。
        VStack(spacing: 0) {
            // Horizontal stack for the Activity Bar and the rest of the content.
            // 水平堆栈，用于放置左侧的活动栏和右侧的内容区域。
            HStack(spacing: 0) {
                // Activity Bar (Fixed Width) - The leftmost navigation strip.
                // 活动栏（固定宽度）- 最左侧的导航条。
                ActivityBarView(appModel: appModel)
                
                // Main Content Area with Split View.
                // HSplitView allows the user to resize the sidebar and editor area.
                //
                // 带分割视图的主要内容区域。
                // HSplitView 允许用户调整侧边栏和编辑器区域的大小。
                HSplitView {
                    // Sidebar (Only visible in Review mode).
                    // Conditionally render the sidebar based on the active tab.
                    //
                    // 侧边栏（仅在审核模式下可见）。
                    // 根据当前激活的标签页有条件地渲染侧边栏。
                    if appModel.activeTab == .review {
                        SideBarView(appModel: appModel)
                            .frame(minWidth: 200, idealWidth: 250, maxWidth: 500)
                    }
                    
                    // Editor / Main View Area.
                    // ZStack allows layering the background color behind the content.
                    //
                    // 编辑器/主视图区域。
                    // ZStack 允许将背景颜色分层放置在内容后面。
                    ZStack {
                        // Apply the configured background color, ignoring safe areas to fill the screen.
                        // 应用配置的背景颜色，忽略安全区域以填充整个屏幕。
                        settings.bgColor.ignoresSafeArea()
                        
                        // Switch content based on the active tab.
                        // This acts as a router for the application's main views.
                        //
                        // 根据当前激活的标签页切换内容。
                        // 这充当了应用程序主视图的路由器。
                        switch appModel.activeTab {
                        case .review:
                            EditorView(appModel: appModel, settings: settings)
                        case .overview:
                            OverviewView(appModel: appModel, viewModel: overviewViewModel)
                        case .stats:
                            StatsView(appModel: appModel)
                        case .settings:
                            SettingsView(settings: settings)
                        }
                    }
                    // Ensure the main content takes up all remaining space.
                    // 确保主要内容区域占据所有剩余空间。
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Status Bar - Displays information at the bottom of the window.
            // 状态栏 - 在窗口底部显示信息。
            StatusBarView(appModel: appModel)
                .frame(height: 22)
        }
        // Set the window background color to the system default.
        // 将窗口背景颜色设置为系统默认值。
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
