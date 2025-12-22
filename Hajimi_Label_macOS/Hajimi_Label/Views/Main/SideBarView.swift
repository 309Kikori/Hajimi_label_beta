import SwiftUI

struct SideBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("explorer")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            
            if let folder = appModel.currentFolder {
                // Folder Header
                HStack {
                    Text("📂 \(folder.lastPathComponent)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                
                // File List
                List(appModel.files, id: \.self, selection: $appModel.selectedFile) { file in
                    HStack {
                        StatusIcon(status: appModel.results[file.lastPathComponent] ?? "unreviewed")
                        Text(file.lastPathComponent)
                            .font(.system(size: 13))
                    }
                    .tag(file)
                }
                .listStyle(SidebarListStyle())
            } else {
                // No Folder State
                VStack(spacing: 20) {
                    Spacer()
                    Text("no_folder")
                        .foregroundColor(.secondary)
                    Button("open_folder") {
                        appModel.openFolder()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct StatusIcon: View {
    let status: String
    
    var body: some View {
        switch status {
        case "pass":
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case "fail":
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case "invalid":
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
        default:
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        }
    }
}

struct SideBarView_Previews: PreviewProvider {
    static var previews: some View {
        SideBarView(appModel: AppModel())
    }
}



