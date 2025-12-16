import SwiftUI

struct VisualizerView: View {
    var levels: [Float]
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple, .pink]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 8, height: max(4, CGFloat(levels[index]) * 150))
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: levels[index])
            }
        }
        .frame(height: 160)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.05))
                .blur(radius: 10)
        )
    }
}
