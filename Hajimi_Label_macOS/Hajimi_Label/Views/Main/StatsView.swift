import SwiftUI

struct StatsView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Statistics")
                .font(.largeTitle)
            
            let stats = appModel.stats
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Total: \(stats.total)")
                Text("Passed: \(stats.passed)")
                    .foregroundColor(.green)
                Text("Failed: \(stats.failed)")
                    .foregroundColor(.red)
                Text("Invalid: \(stats.invalid)")
                    .foregroundColor(.gray)
                Text("Unreviewed: \(stats.unreviewed)")
                    .foregroundColor(.orange)
            }
            .font(.title2)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
