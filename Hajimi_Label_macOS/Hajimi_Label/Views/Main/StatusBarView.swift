import SwiftUI

struct StatusBarView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        HStack {
            if appModel.currentFolder != nil {
                Text("Ready")
                Spacer()
                Text("\(appModel.files.count) Files")
            } else {
                Text("Ready")
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor)) // Or a specific status bar color
        .foregroundColor(.white)
        .background(Color.blue) // VS Code default blue
        .font(.system(size: 12))
    }
}
