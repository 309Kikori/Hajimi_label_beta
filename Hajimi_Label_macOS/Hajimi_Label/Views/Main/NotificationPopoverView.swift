import SwiftUI

// MARK: - Notification Popover View
// MARK: - 通知弹出视图

/// A popover view that displays a list of notifications.
/// Designed with an iOS Notification Center style aesthetic.
///
/// 显示通知列表的弹出视图。
/// 采用 iOS 通知中心风格的美学设计。
struct NotificationPopoverView: View {
    @ObservedObject var appModel: AppModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            // 头部
            HStack {
                Text("Notifications")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !appModel.notifications.isEmpty {
                    Button(action: {
                        withAnimation {
                            appModel.clearNotifications()
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear All")
                }
            }
            .padding()
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            
            Divider()
            
            // Notification List
            // 通知列表
            ScrollView {
                if appModel.notifications.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(appModel.notifications.reversed()) { notification in
                            NotificationCard(notification: notification)
                        }
                    }
                    .padding()
                }
            }
            .frame(maxHeight: 400) // Limit height
        }
        .frame(width: 320)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
    
    // Empty State View
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No notifications")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(height: 200)
    }
}

// MARK: - Notification Card
// MARK: - 通知卡片

/// A single notification card with iOS-style design.
/// iOS 风格的单个通知卡片。
struct NotificationCard: View {
    let notification: NotificationItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            // 图标
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                // Message
                // 消息内容
                Text(notification.message)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Timestamp
                // 时间戳
                Text(notification.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var iconName: String {
        switch notification.level {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Visual Effect View Helper
// MARK: - 视觉效果视图辅助类

/// Wraps NSVisualEffectView for SwiftUI.
/// 为 SwiftUI 封装 NSVisualEffectView。
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
