//
//  SettingsView.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

// MARK: - Settings View
// MARK: - 设置视图

/// The settings configuration view.
/// Allows users to customize appearance and behavior.
///
/// 设置配置视图。
/// 允许用户自定义外观和行为。
struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    
    var body: some View {
        // Form provides a standard settings UI layout.
        // Form 提供标准的设置 UI 布局。
        Form {
            // Appearance Section
            // 外观部分
            Section(header: Text(NSLocalizedString("appearance", comment: "Settings section header for appearance"))) {
                // Theme Picker
                // 主题选择器
                Picker(NSLocalizedString("theme", comment: "Theme setting label"), selection: $settings.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.localizedName).tag(theme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // Use segmented control for better UX
                
                // Grid Size Input
                // 网格大小输入
                TextField(NSLocalizedString("grid_size", comment: "Grid size setting label"), value: $settings.gridSize, formatter: NumberFormatter())
                
                // Grid Color Picker
                // Uses a custom binding to convert between Color and Hex String.
                //
                // 网格颜色选择器。
                // 使用自定义绑定在 Color 和十六进制字符串之间进行转换。
                ColorPicker(NSLocalizedString("grid_color", comment: "Grid color setting label"), selection: Binding(
                    get: { settings.gridColor },
                    set: { settings.gridColorHex = $0.toHex() ?? "#333333" }
                ))
                
                // Background Color Picker
                // 背景颜色选择器
                ColorPicker(NSLocalizedString("bg_color", comment: "Background color setting label"), selection: Binding(
                    get: { settings.bgColor },
                    set: { settings.bgColorHex = $0.toHex() ?? "#1e1e1e" }
                ))
                
                // Max Image Width Input
                // 最大图片宽度输入
                TextField(NSLocalizedString("max_image_width", comment: "Max image width setting label"), value: $settings.maxImageWidth, formatter: NumberFormatter())
            }
            
            // Behavior Section
            // 行为部分
            Section(header: Text(NSLocalizedString("behavior", comment: "Settings section header for behavior"))) {
                // Overview Toggle
                // 概览开关
                Toggle(NSLocalizedString("enable_overview", comment: "Enable overview toggle label"), isOn: $settings.enableOverview)
            }
        }
        .padding()
        .frame(maxWidth: 500) // Limit width for better readability on large screens. (限制宽度以在宽屏上获得更好的可读性)
        .background(Color(nsColor: .windowBackgroundColor)) // Ensure correct background in Light Mode
    }
}


#Preview {
    SettingsView(settings: SettingsModel())
}
