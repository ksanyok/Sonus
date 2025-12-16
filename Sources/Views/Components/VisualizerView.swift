import SwiftUI

struct VisualizerView: View {
    var levels: [Float]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 6, height: CGFloat(levels[index]) * 100)
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
        .frame(height: 100)
        .padding()
    }
}
