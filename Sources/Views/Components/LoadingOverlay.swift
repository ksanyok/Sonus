import SwiftUI

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)
                    .scaleEffect(1.2)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
        }
        .transition(.opacity)
    }
}
