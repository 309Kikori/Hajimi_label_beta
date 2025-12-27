//
//  CommandCenterView.swift
//  Hajimi_Label
//
//  Created by shinonome on 27/12/2025.
//

import SwiftUI
import AppKit

// MARK: - Command Option

enum CommandOption: String, CaseIterable, Identifiable {
    case goToFile = "Go to File"
    case recentFiles = "Recent Files"
    case settings = "Settings"
    case showAllCommands = "Show All Commands"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .goToFile: return "arrow.right"
        case .recentFiles: return "clock"
        case .settings: return "gearshape"
        case .showAllCommands: return "command"
        }
    }
}

// MARK: - Command Center View

struct CommandCenterView: View {
    @ObservedObject var appModel: AppModel
    @State private var isOpen = false
    @State private var selectedIndex = 0
    @State private var activeOption: CommandOption = .goToFile
    @State private var searchText = ""
    
    private var displayFiles: [URL] {
        if searchText.isEmpty {
            return Array(appModel.allFiles.prefix(30))
        }
        // Fuzzy search logic
        return appModel.allFiles.filter { url in
            let filename = url.lastPathComponent.lowercased()
            let query = searchText.lowercased()
            
            // 1. Exact match or substring match (priority)
            if filename.contains(query) { return true }
            
            // 2. Fuzzy match (characters in order)
            var remainder = query[...]
            for char in filename {
                if let first = remainder.first, char == first {
                    remainder.removeFirst()
                    if remainder.isEmpty { return true }
                }
            }
            return false
        }.prefix(30).map { $0 }
    }
    
    var body: some View {
        // 搜索栏
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            
            if isOpen {
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        if !displayFiles.isEmpty {
                            selectFile(displayFiles[selectedIndex])
                        }
                    }
            } else {
                Button(action: { isOpen = true }) {
                    HStack {
                        Text("Search files...")
                            .font(.system(size: 13))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    selectedIndex = 0
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
        .overlay(alignment: .top) {
            if isOpen {
                dropdownPanel
                    .offset(y: 40)
                    .zIndex(100) // Ensure it's on top
            }
        }
        .zIndex(100) // Ensure the search bar itself is high in z-index
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onAppear {
            // Global Event Monitor for Navigation
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard self.isOpen else { return event }
                
                switch event.keyCode {
                case 53: // ESC
                    DispatchQueue.main.async { self.close() }
                    return nil
                case 126: // Up Arrow
                    if selectedIndex > 0 {
                        selectedIndex -= 1
                    }
                    return nil
                case 125: // Down Arrow
                    if selectedIndex < displayFiles.count - 1 {
                        selectedIndex += 1
                    }
                    return nil
                case 36: // Enter
                    if !displayFiles.isEmpty {
                        selectFile(displayFiles[selectedIndex])
                        return nil
                    }
                default:
                    break
                }
                return event
            }
        }
    }
    
    // MARK: - Dropdown Panel
    
    private var dropdownPanel: some View {
        VStack(spacing: 0) {
            // 命令选项 (仅当未搜索时显示)
            if searchText.isEmpty {
                VStack(spacing: 2) {
                    ForEach(CommandOption.allCases) { option in
                        Button(action: { activeOption = option }) {
                            HStack(spacing: 8) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(activeOption == option ? .accentColor : .secondary)
                                Text(option.rawValue)
                                    .font(.system(size: 13, weight: activeOption == option ? .semibold : .regular))
                                    .foregroundColor(activeOption == option ? .primary : .secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(activeOption == option ? Color.accentColor.opacity(0.12) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
                
                Divider()
            }
            
            // 文件列表
            if appModel.allFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No folder opened")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if displayFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No matching files")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Searched \(appModel.allFiles.count) files")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Found \(displayFiles.count) matches")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    // Use VStack directly for small number of items to ensure visibility
                    // If list is long, ScrollView is fine, but let's be safe with frame
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(displayFiles.enumerated()), id: \.element) { index, fileURL in
                                Button(action: { selectFile(fileURL) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 12))
                                            .foregroundColor(selectedIndex == index ? .white : .secondary)
                                        Text(fileURL.lastPathComponent)
                                            .font(.system(size: 13))
                                            .foregroundColor(selectedIndex == index ? .white : .primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedIndex == index ? Color.accentColor : Color.clear)
                                            .padding(.horizontal, 4)
                                    )
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                                .id(index) // For ScrollViewReader if needed later
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: min(CGFloat(displayFiles.count * 32 + 10), 320)) // Dynamic height
                }
            }
            
            // 底部关闭按钮
            Divider()
            Button(action: { close() }) {
                HStack {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 11))
                    Text("Close")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
        .frame(width: 380)
    }
    
    // MARK: - Actions
    
    private func selectFile(_ fileURL: URL) {
        appModel.selectedFile = fileURL
        close()
    }
    
    private func close() {
        isOpen = false
        searchText = ""
        selectedIndex = 0
    }
}

// MARK: - Preview

#Preview {
    CommandCenterView(appModel: AppModel())
        .padding()
}
