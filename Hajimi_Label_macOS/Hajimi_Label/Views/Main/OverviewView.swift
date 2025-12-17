import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack {
            Text("Overview Feature Coming Soon")
                .font(.title)
                .foregroundColor(.secondary)
        }
    }
}

struct OverviewView_Previews: PreviewProvider {
    static var previews: some View {
        OverviewView(appModel: AppModel())
    }
}
