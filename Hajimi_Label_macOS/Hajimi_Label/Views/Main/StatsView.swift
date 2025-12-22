import SwiftUI
import UniformTypeIdentifiers

struct StatsView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("stats_title")
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            let stats = appModel.stats
            
            Group {
                StatRow(label: "total", value: stats.total, color: .primary)
                StatRow(label: "passed", value: stats.passed, color: .green)
                StatRow(label: "failed", value: stats.failed, color: .red)
                StatRow(label: "invalid", value: stats.invalid, color: .yellow)
                StatRow(label: "unreviewed", value: stats.unreviewed, color: .gray)
            }
            
            Divider()
                .padding(.vertical)
            
            Button(action: exportJSON) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(NSLocalizedString("export_json", comment: "Export JSON button label"))
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "review_results.json"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    let data = try JSONSerialization.data(withJSONObject: appModel.results, options: .prettyPrinted)
                    try data.write(to: url)
                } catch {
                    print("Failed to export JSON: \(error)")
                    // Optionally update appModel.errorMessage to show in StatusBar
                    DispatchQueue.main.async {
                        appModel.errorMessage = "Export failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(NSLocalizedString(label, comment: ""))
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            
            Text("\(value)")
                .font(.title2)
                .bold()
                .foregroundColor(color)
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView(appModel: AppModel())
    }
}
