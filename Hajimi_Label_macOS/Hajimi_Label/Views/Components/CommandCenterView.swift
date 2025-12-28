//
//  CommandCenterView.swift
//  Hajimi_Label
//
//  Created by shinonome on 27/12/2025.
//

import SwiftUI
import AppKit

// MARK: - Command Center View (Toolbar Item)

struct CommandCenterView: View {
    @ObservedObject var appModel: AppModel
    @State private var localSearchText = ""
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            
            // Always show TextField to avoid layout shifts
            TextField("Search files...", text: $localSearchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onChange(of: localSearchText) { newValue, _ in
                    appModel.searchText = newValue
                    if !newValue.isEmpty {
                        appModel.isCommandCenterOpen = true
                    }
                }
                .onReceive(appModel.$isCommandCenterOpen) { isOpen in
                    if !isOpen {
                        // Clear local text when closed externally (e.g. by selecting a file)
                        // But only if it was actually open before
                        if !localSearchText.isEmpty {
                            localSearchText = ""
                        }
                    }
                }
                .onTapGesture {
                    appModel.isCommandCenterOpen = true
                }
            
            if !localSearchText.isEmpty {
                Button(action: {
                    localSearchText = ""
                    appModel.searchText = ""
                    appModel.isCommandCenterOpen = false
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
        // No overlay here! The dropdown is handled globally in ContentView.
    }
}

// MARK: - Command Center Panel (Global Overlay)

struct CommandCenterPanel: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedIndex = 0
    
    private var displayFiles: [URL] {
        if appModel.searchText.isEmpty {
            return Array(appModel.allFiles.prefix(30))
        }
        // Fuzzy search logic
        return appModel.allFiles.filter { url in
            let filename = url.lastPathComponent.lowercased()
            let query = appModel.searchText.lowercased()
            
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
        VStack(spacing: 0) {
            // Header / Status
            HStack {
                if displayFiles.isEmpty {
                    Text("No matching files")
                        .foregroundColor(.secondary)
                } else {
                    Text("Found \(displayFiles.count) matches")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("ESC to close")
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .font(.system(size: 10))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if !displayFiles.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayFiles.enumerated()), id: \.element) { index, fileURL in
                            FileRow(fileURL: fileURL, isSelected: selectedIndex == index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectFile(fileURL)
                                }
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        .frame(width: 380)
        .onAppear {
            // Reset selection
            selectedIndex = 0
            
            // Global Key Monitor for navigation
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard appModel.isCommandCenterOpen else { return event }
                
                switch event.keyCode {
                case 53: // ESC
                    DispatchQueue.main.async { appModel.isCommandCenterOpen = false }
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
    
    private func selectFile(_ fileURL: URL) {
        appModel.selectedFile = fileURL
        appModel.isCommandCenterOpen = false
        appModel.searchText = ""
    }
}

struct FileRow: View {
    let fileURL: URL
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white : .secondary)
            Text(fileURL.lastPathComponent)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor : Color.clear)
    }
}
