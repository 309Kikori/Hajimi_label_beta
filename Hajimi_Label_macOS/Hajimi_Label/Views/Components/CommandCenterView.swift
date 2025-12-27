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
        return appModel.allFiles.filter {
            $0.lastPathComponent.localizedCaseInsensitiveContains(searchText)
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
            }
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onAppear {
            // ESC 键关闭
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 && self.isOpen { // ESC key
                    DispatchQueue.main.async {
                        self.close()
                    }
                }
                return event
            }
        }
    }
    
    // MARK: - Dropdown Panel
    
    private var dropdownPanel: some View {
        VStack(spacing: 0) {
            // 命令选项
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
            
            // 文件列表
            if displayFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No files found")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(displayFiles.enumerated()), id: \.element) { index, fileURL in
                            Button(action: { selectFile(fileURL) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text(fileURL.lastPathComponent)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selectedIndex == index ? Color.accentColor.opacity(0.18) : Color.clear)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering { selectedIndex = index }
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
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
