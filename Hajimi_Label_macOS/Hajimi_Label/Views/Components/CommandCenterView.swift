//
//  CommandCenterView.swift
//  Hajimi_Label
//
//  Created by shinonome on 27/12/2025.
//

import SwiftUI
import AppKit

/// A custom NSTextField wrapper that removes the focus ring.
/// 自定义 NSTextField 包装器，用于移除焦点环。
struct BorderlessTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.focusRingType = .none // Remove focus ring (移除焦点环)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: 13)
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BorderlessTextField
        
        init(_ parent: BorderlessTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            return false
        }
    }
}

/// A search bar component mimicking VS Code's Command Center.
/// It allows filtering files by name.
///
/// 模仿 VS Code 命令中心的搜索栏组件。
/// 允许按名称过滤文件。
struct CommandCenterView: View {
    @ObservedObject var appModel: AppModel
    
    // Focus state for the text field.
    // 文本框的焦点状态。
    @FocusState private var isFocused: Bool
    
    // Local state to track if we are in "Edit Mode".
    // 本地状态，用于跟踪是否处于“编辑模式”。
    @State private var isEditing: Bool = false
    
    // Hover state for display mode.
    // 显示模式的悬停状态。
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Search Icon (Always visible)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            
            // Input Field / Display Text
            if isEditing || !appModel.searchText.isEmpty {
                BorderlessTextField(text: $appModel.searchText, placeholder: "Search files...", onCommit: {})
                    .focused($isFocused)
            } else {
                Button(action: {
                    isEditing = true
                    isFocused = true
                }) {
                    HStack {
                        Text("Search files...")
                            .font(.system(size: 13))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Clear Button
            if !appModel.searchText.isEmpty {
                Button(action: {
                    appModel.searchText = ""
                    isFocused = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.8))
        )
        .frame(width: 380, height: 32)
        // Handle focus changes to exit edit mode.
        // 处理焦点变化以退出编辑模式。
        .onChange(of: isFocused) { _, focused in
            if !focused && appModel.searchText.isEmpty {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isEditing = false
                }
            }
        }
        // Ensure we enter edit mode if there is text (e.g. restored state).
        // 确保如果有文本（例如恢复状态），我们进入编辑模式。
        .onAppear {
            if !appModel.searchText.isEmpty {
                isEditing = true
            }
        }
    }
}

struct CommandCenterView_Previews: PreviewProvider {
    static var previews: some View {
        CommandCenterView(appModel: AppModel())
            .padding()
    }
}
