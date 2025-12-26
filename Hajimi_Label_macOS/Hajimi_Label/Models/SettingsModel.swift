//
//  SettingsModel.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Settings Model
// MARK: - 设置模型

/// Manages application settings and persists them using UserDefaults.
///
/// 管理应用程序设置并使用 UserDefaults 进行持久化。
class SettingsModel: ObservableObject {
    // MARK: - Persistent Settings
    // MARK: - 持久化设置
    
    /// Grid size for the overview background.
    /// Persisted with key "gridSize".
    ///
    /// 概览背景的网格大小。
    /// 使用键 "gridSize" 进行持久化。
    @AppStorage("gridSize") var gridSize: Double = 40.0
    
    /// Hex string for the grid line color.
    /// Persisted with key "gridColor".
    ///
    /// 网格线颜色的十六进制字符串。
    /// 使用键 "gridColor" 进行持久化。
    @AppStorage("gridColor") var gridColorHex: String = "#333333"
    
    /// Hex string for the application background color.
    /// Persisted with key "bgColor".
    ///
    /// 应用程序背景颜色的十六进制字符串。
    /// 使用键 "bgColor" 进行持久化。
    @AppStorage("bgColor") var bgColorHex: String = "#1e1e1e"
    
    /// Maximum width for images in the editor view.
    /// Persisted with key "maxImageWidth".
    ///
    /// 编辑器视图中图像的最大宽度。
    /// 使用键 "maxImageWidth" 进行持久化。
    @AppStorage("maxImageWidth") var maxImageWidth: Double = 1600.0
    
    /// Toggle to enable/disable the Overview feature.
    /// Persisted with key "enableOverview".
    ///
    /// 启用/禁用概览功能的开关。
    /// 使用键 "enableOverview" 进行持久化。
    @AppStorage("enableOverview") var enableOverview: Bool = true
    
    // MARK: - Computed Colors
    // MARK: - 计算颜色
    
    /// Returns a SwiftUI Color object from the stored hex string.
    ///
    /// 从存储的十六进制字符串返回 SwiftUI Color 对象。
    var gridColor: Color {
        Color(hex: gridColorHex) ?? .gray
    }
    
    /// Returns a SwiftUI Color object from the stored hex string.
    ///
    /// 从存储的十六进制字符串返回 SwiftUI Color 对象。
    var bgColor: Color {
        Color(hex: bgColorHex) ?? .black
    }
}

// MARK: - Color Extension
// MARK: - Color 扩展

extension Color {
    /// Initializes a Color from a hex string (e.g., "#RRGGBB" or "RRGGBB").
    /// Supports 6-digit (RGB) and 8-digit (RGBA) formats.
    ///
    /// 从十六进制字符串（例如 "#RRGGBB" 或 "RRGGBB"）初始化 Color。
    /// 支持 6 位 (RGB) 和 8 位 (RGBA) 格式。
    init?(hex: String) {
        // Clean the string: remove whitespace and '#' prefix.
        // 清理字符串：移除空格和 '#' 前缀。
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        // Scan the hex string into a 64-bit integer.
        // 将十六进制字符串扫描为 64 位整数。
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            // Format: RRGGBB
            // Bitwise operations to extract components.
            //
            // 格式：RRGGBB
            // 位运算提取分量。
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            // Format: RRGGBBAA
            //
            // 格式：RRGGBBAA
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Converts the Color back to a hex string.
    /// Note: This relies on `cgColor` which might not be available for all Color instances (e.g., system colors).
    ///
    /// 将 Color 转换回十六进制字符串。
    /// 注意：这依赖于 `cgColor`，它可能不适用于所有 Color 实例（例如系统颜色）。
    func toHex() -> String? {
        guard let components = cgColor?.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
