import SwiftUI

struct StatusBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        HStack(spacing: 15) {
            // Left side
            HStack(spacing: 5) {
                Image(systemName: "folder")
                Text(appModel.currentFolder?.lastPathComponent ?? NSLocalizedString("no_folder", comment: ""))
            }
            
            if let selected = appModel.selectedFile {
                HStack(spacing: 5) {
                    Image(systemName: "doc")
                    Text(selected.lastPathComponent)
                    
                    // Status of current file
                    if let status = appModel.results[selected.lastPathComponent] {
                        Text("[\(NSLocalizedString(status, comment: ""))]")
                            .foregroundColor(statusColor(status))
                    } else {
                        Text("[\(NSLocalizedString("unreviewed", comment: ""))]")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Right side
            let stats = appModel.stats
            Text("\(NSLocalizedString("passed", comment: "")): \(stats.passed)")
            Text("\(NSLocalizedString("failed", comment: "")): \(stats.failed)")
            Text("\(NSLocalizedString("unreviewed", comment: "")): \(stats.unreviewed)")
            
            HStack(spacing: 5) {
                Image(systemName: "bell")
                Text(NSLocalizedString("status_ready", comment: ""))
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundColor(.white)
        .background(Color(hex: "007acc")) // VS Code Blue
    }
    
    func statusColor(_ status: String) -> Color {
        switch status {
        case "pass": return .green
        case "fail": return .red
        case "invalid": return .yellow
        default: return .gray
        }
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarView(appModel: AppModel())
    }
}
