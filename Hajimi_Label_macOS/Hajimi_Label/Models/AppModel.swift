import Foundation
import SwiftUI
import Combine

enum AppTab {
    case review
    case overview
    case stats
    case settings
}

class AppModel: ObservableObject {
    @Published var activeTab: AppTab = .review
    @Published var currentFolder: URL?
    @Published var files: [URL] = []
    @Published var selectedFile: URL?
    @Published var results: [String: String] = [:]
    
    var stats: (total: Int, passed: Int, failed: Int, invalid: Int, unreviewed: Int) {
        let total = files.count
        let passed = results.values.filter { $0 == "pass" }.count
        let failed = results.values.filter { $0 == "fail" }.count
        let invalid = results.values.filter { $0 == "invalid" }.count
        let unreviewed = total - passed - failed - invalid
        return (total, passed, failed, invalid, unreviewed)
    }
    
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                self.currentFolder = url
                loadFiles(from: url)
                ensureResultsFileExists()
                loadResults()
            }
        }
    }
    
    func loadFiles(from url: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff"]
            self.files = fileURLs.filter { url in
                imageExtensions.contains(url.pathExtension.lowercased())
            }.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            
            if !files.isEmpty {
                selectedFile = files.first
            }
        } catch {
            print("Error loading files: \(error)")
        }
    }
    
    func loadResults() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")
        
        do {
            let data = try Data(contentsOf: resultsURL)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                self.results = json
            }
        } catch {
            print("No existing results or error loading: \(error)")
            self.results = [:]
        }
    }
    
    func saveResults() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
            try data.write(to: resultsURL)
        } catch {
            print("Error saving results: \(error)")
        }
    }
    
    func labelCurrentFile(status: String) {
        guard let file = selectedFile else { return }
        let filename = file.lastPathComponent
        results[filename] = status
        saveResults()
        
        // Auto-advance to next file
        if let index = files.firstIndex(of: file), index + 1 < files.count {
            selectedFile = files[index + 1]
        }
    }
    
    func ensureResultsFileExists() {
        guard let folder = currentFolder else { return }
        let resultsURL = folder.appendingPathComponent("review_results.json")

        // Always try to create if not exists, even if we just loaded
        if !FileManager.default.fileExists(atPath: resultsURL.path) {
            do {
                let emptyResults: [String: String] = [:]
                let data = try JSONSerialization.data(withJSONObject: emptyResults, options: .prettyPrinted)
                try data.write(to: resultsURL)
                print("Created empty review_results.json at \(resultsURL.path)")
            } catch {
                print("Error creating review_results.json: \(error)")
            }
        }
    }
}
