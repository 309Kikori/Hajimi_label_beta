import SwiftUI

struct ActivityBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(spacing: 0) {
            ActivityButton(icon: "eye", title: "review", tab: .review, activeTab: $appModel.activeTab)
            ActivityButton(icon: "map", title: "overview", tab: .overview, activeTab: $appModel.activeTab)
            ActivityButton(icon: "chart.bar", title: "stats_title", tab: .stats, activeTab: $appModel.activeTab)
            
            Spacer()
            
            ActivityButton(icon: "gear", title: "settings_title", tab: .settings, activeTab: $appModel.activeTab)
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
    let tab: AppTab
    @Binding var activeTab: AppTab
    
    var body: some View {
        Button(action: { activeTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
            }
            .frame(width: 50, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(activeTab == tab ? .accentColor : .secondary)
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundColor(activeTab == tab ? .accentColor : .clear)
                .padding(.vertical, 2),
            alignment: .leading
        )
        .help(NSLocalizedString(title, comment: ""))
    }
}

struct ActivityBarView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityBarView(appModel: AppModel())
    }
}
