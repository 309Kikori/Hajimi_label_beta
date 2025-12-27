//
//  EditorView.swift
//  Hajimi_Label
//
//  Created by shinonome on 17/12/2025.
//

import SwiftUI

// MARK: - Editor View
// MARK: - 编辑器视图

/// The main editor view for reviewing images one by one.
/// Provides image zooming, panning, and labeling functionality.
///
/// 用于逐张审核图片的主编辑器视图。
/// 提供图片缩放、平移和标记功能。
struct EditorView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var settings: SettingsModel
    @Environment(\.colorScheme) var colorScheme
    
    // Local state for image manipulation.
    // 图片操作的本地状态。
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar / Title Header
            // 标签栏/标题头
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(Color(hex: "007acc"))
                Text(appModel.selectedFile?.lastPathComponent ?? NSLocalizedString("no_file_selected", comment: ""))
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Main Image Area
            // 主要图片区域
            GeometryReader { geometry in
                if let selectedFile = appModel.selectedFile,
                   let image = NSImage(contentsOf: selectedFile) {
                    ZStack {
                        // Checkerboard Background for transparency indication.
                        // 用于指示透明度的棋盘格背景。
                        CheckerboardView()
                        
                        // The Image itself.
                        // 图片本身。
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(settings.bgColor)
                    .clipped() // Clip content to bounds. (将内容裁剪到边界)
                    .overlay(
                        // Gesture Handling: Zoom (Scroll Wheel) and Pan (Drag).
                        // 手势处理：缩放（滚轮）和平移（拖拽）。
                        ScrollWheelHandler { zoomFactor in
                            let newScale = scale * zoomFactor
                            // Limit zoom level between 0.1x and 10x.
                            // 将缩放级别限制在 0.1x 到 10x 之间。
                            scale = max(0.1, min(newScale, 10.0))
                        }
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    // Update offset during drag.
                                    // 拖拽过程中更新偏移量。
                                    self.offset = CGSize(width: self.lastOffset.width + value.translation.width, height: self.lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in
                                    // Save offset after drag ends.
                                    // 拖拽结束后保存偏移量。
                                    self.lastOffset = self.offset
                                }
                        )
                    )
                    .overlay(
                        // Action Bar (Floating at bottom).
                        // 操作栏（底部悬浮）。
                        HStack(spacing: 20) {
                            Spacer()
                            
                            // Fail Button (Shortcut: F)
                            // 失败按钮（快捷键：F）
                            Button(action: { appModel.labelCurrentFile(status: "fail") }) {
                                Text("\(NSLocalizedString("fail", comment: "")) (F)")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(colorScheme == .dark ? Color(hex: "a10000") : Color(hex: "d32f2f"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("f", modifiers: [])
                            
                            // Invalid Button (Shortcut: I)
                            // 无效按钮（快捷键：I）
                            Button(action: { appModel.labelCurrentFile(status: "invalid") }) {
                                Text("\(NSLocalizedString("invalid", comment: "")) (I)")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(colorScheme == .dark ? Color(hex: "8e8e8e") : Color(hex: "757575"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("i", modifiers: [])
                            
                            // Pass Button (Shortcut: P)
                            // 通过按钮（快捷键：P）
                            Button(action: { appModel.labelCurrentFile(status: "pass") }) {
                                Text("\(NSLocalizedString("pass", comment: "")) (P)")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(colorScheme == .dark ? Color(hex: "0e639c") : Color(hex: "1976d2"))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("p", modifiers: [])
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                        , alignment: .bottom
                    )
                } else {
                    // Empty State
                    // 空状态
                    VStack {
                        Spacer()
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("no_file_selected")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Use system window background color for empty state to ensure text readability in all themes.
                    // 使用系统窗口背景色作为空状态背景，以确保在所有主题下文字的可读性。
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
            // Reset zoom and pan when file changes.
            // 当文件改变时重置缩放和平移。
            .onChange(of: appModel.selectedFile) { _, _ in
                scale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        }
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(appModel: AppModel(), settings: SettingsModel())
    }
}
