import SwiftUI

struct MiniWindow: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var recorder: AudioRecorder
    @EnvironmentObject private var l10n: LocalizationService
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                if recorder.isRecording {
                    Text(formatDuration(recorder.recordingDuration))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())

                    VisualizerView(levels: recorder.audioLevels)
                        .frame(height: 30)

                    Button(action: viewModel.stopRecording) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: viewModel.startRecording) {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text(l10n.t("Ready", ru: "Готов"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(width: 160, height: 120)
            .background(.ultraThinMaterial)

            if viewModel.shouldShowAPIKeyBanner {
                Button {
                    NotificationCenter.default.post(name: .sonusOpenSettings, object: nil)
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .padding(6)
                        .background(Color.black.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .help(l10n.t("API key required for AI", ru: "Нужен API ключ для анализа"))
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
