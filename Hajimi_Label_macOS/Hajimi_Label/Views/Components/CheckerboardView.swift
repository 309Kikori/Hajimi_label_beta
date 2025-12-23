import SwiftUI

/// A view that renders a checkerboard pattern.
/// Commonly used as a background for images to indicate transparency.
///
/// 渲染棋盘格图案的视图。
/// 通常用作图片背景以指示透明度。
struct CheckerboardView: View {
    var body: some View {
        GeometryReader { geometry in
            // Draw the pattern using a Path.
            // 使用 Path 绘制图案。
            Path { path in
                let size: CGFloat = 20 // Size of each square. (每个方块的大小)
                let rows = Int(geometry.size.height / size) + 1
                let cols = Int(geometry.size.width / size) + 1
                
                // Iterate through rows and columns.
                // 遍历行和列。
                for row in 0..<rows {
                    for col in 0..<cols {
                        // Draw a square only if the sum of row and col is even.
                        // This creates the checkerboard effect.
                        //
                        // 仅当行和列之和为偶数时绘制方块。
                        // 这产生了棋盘格效果。
                        if (row + col) % 2 == 0 {
                            path.addRect(CGRect(x: CGFloat(col) * size, y: CGFloat(row) * size, width: size, height: size))
                        }
                    }
                }
            }
            .fill(Color.gray.opacity(0.2)) // Fill with a semi-transparent gray. (填充半透明灰色)
        }
    }
}
