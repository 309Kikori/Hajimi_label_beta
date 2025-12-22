import SwiftUI

struct CheckerboardView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let size: CGFloat = 20
                let rows = Int(geometry.size.height / size) + 1
                let cols = Int(geometry.size.width / size) + 1
                
                for row in 0..<rows {
                    for col in 0..<cols {
                        if (row + col) % 2 == 0 {
                            path.addRect(CGRect(x: CGFloat(col) * size, y: CGFloat(row) * size, width: size, height: size))
                        }
                    }
                }
            }
            .fill(Color.gray.opacity(0.2))
        }
    }
}
