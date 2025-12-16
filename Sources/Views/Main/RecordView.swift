import SwiftUI

struct RecordView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            if viewModel.audioRecorder.isRecording {
                Text(timeString(from: viewModel.audioRecorder.recordingDuration))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundColor(.primary)
                
                VisualizerView(levels: viewModel.audioRecorder.audioLevels)
                    .frame(height: 100)
                
                Text("Recording...")
                    .font(.headline)
                    .foregroundColor(.red)
                    .pulseAnimation()
            } else {
                Text("Ready to Record")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                if viewModel.audioRecorder.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                Image(systemName: viewModel.audioRecorder.isRecording ? "stop.circle.fill" : "record.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(viewModel.audioRecorder.isRecording ? .red : .red)
                    .shadow(radius: 10)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding()
    }
    
    func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension View {
    func pulseAnimation() -> some View {
        self.modifier(PulseEffect())
    }
}

struct PulseEffect: ViewModifier {
    @State private var isOn = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isOn ? 0.5 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isOn = true
                }
            }
    }
}
