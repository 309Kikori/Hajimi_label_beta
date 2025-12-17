import SwiftUI

struct SideBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Area
            HStack {
                Text("EXPLORER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            if appModel.currentFolder == nil {
                // No Folder State
                VStack {
                    Spacer()
                    Text("No Folder Opened")
                        .foregroundColor(.secondary)
                    Button("Open Folder") {
                        appModel.openFolder()
                    }
                    .controlSize(.large)
                    .padding(.top, 10)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // File List
                List(appModel.files, id: \.self, selection: $appModel.selectedFile) { file in
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                        Text(file.lastPathComponent)
                            .lineLimit(1)
                    }
                    .tag(file)
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
