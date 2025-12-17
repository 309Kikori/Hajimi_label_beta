import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel
    
    let columns = [
        GridItem(.adaptive(minimum: 100))
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(appModel.files, id: \.self) { file in
                    VStack {
                        if let image = NSImage(contentsOf: file) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 100)
                                .cornerRadius(5)
                        }
                        Text(file.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .onTapGesture {
                        appModel.selectedFile = file
                        appModel.activeTab = .review
                    }
                }
            }
            .padding()
        }
    }
}
