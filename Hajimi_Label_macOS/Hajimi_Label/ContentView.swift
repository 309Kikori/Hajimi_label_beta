//
//  ContentView.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var settings: SettingsModel
    @StateObject private var overviewViewModel = OverviewViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Activity Bar (Fixed Width)
                ActivityBarView(appModel: appModel)
                
                // Main Content Area with Split View
                HSplitView {
                    // Sidebar (Only visible in Review mode)
                    if appModel.activeTab == .review {
                        SideBarView(appModel: appModel)
                            .frame(minWidth: 200, idealWidth: 250, maxWidth: 500)
                    }
                    
                    // Editor / Main View
                    ZStack {
                        settings.bgColor.ignoresSafeArea()
                        
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Status Bar
            StatusBarView(appModel: appModel)
                .frame(height: 22)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
