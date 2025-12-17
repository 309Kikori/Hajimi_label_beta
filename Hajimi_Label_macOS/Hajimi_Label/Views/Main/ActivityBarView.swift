import SwiftUI

struct ActivityBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(spacing: 0) {
            ActivityButton(icon: "photo", title: "Review", isSelected: appModel.activeTab == .review) {
                appModel.activeTab = .review
            }
            
            ActivityButton(icon: "square.grid.2x2", title: "Overview", isSelected: appModel.activeTab == .overview) {
                appModel.activeTab = .overview
            }
            
            ActivityButton(icon: "chart.bar", title: "Statistics", isSelected: appModel.activeTab == .stats) {
                appModel.activeTab = .stats
            }
            
            Spacer()
            
            ActivityButton(icon: "gear", title: "Settings", isSelected: appModel.activeTab == .settings) {
                appModel.activeTab = .settings
            }
        }
        .frame(width: 50)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .trailing
        )
    }
}

struct ActivityButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 48, height: 48)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundColor(isSelected ? .accentColor : .clear),
            alignment: .leading
        )
    }
}
