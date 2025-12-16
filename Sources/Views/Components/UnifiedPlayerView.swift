import SwiftUI
import Charts

struct UnifiedPlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    let session: Session
    let analysis: Analysis?
    @EnvironmentObject private var l10n: LocalizationService

    @State private var isDragging = false
    @State private var dragTime: TimeInterval = 0

    var body: some View {
        VStack(spacing: 16) {
            // Top Controls
            HStack(spacing: 16) {
                Button(action: {
                    let url = PersistenceService.shared.getAudioURL(for: session.audioFilename)
                    audioPlayer.togglePlayback(audioURL: url)
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.customTitle ?? session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    
                    HStack {
                        Text(TimelinePointBuilder.formatHMS(isDragging ? dragTime : audioPlayer.currentTime))
                            .monospacedDigit()
                            .fontWeight(.medium)
                        Text("/")
                            .foregroundColor(.secondary)
                        Text(TimelinePointBuilder.formatHMS(session.duration))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                
                Spacer()
            }
            .padding(.horizontal)

            // Timeline Scrubber
            ZStack(alignment: .leading) {
                // Background Chart
                if let transcript = session.transcript, !transcript.isEmpty {
                    let points = TimelinePointBuilder.build(transcript: transcript, duration: session.duration)
                    Chart {
                        ForEach(points) { p in
                            BarMark(
                                x: .value("Time", p.midSeconds),
                                y: .value("Intensity", p.emotionalIntensity),
                                width: .fixed(4)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 64)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 64)
                }

                // Progress Fill
                GeometryReader { geo in
                    let width = geo.size.width
                    let duration = max(1, session.duration)
                    let currentX = width * CGFloat((isDragging ? dragTime : audioPlayer.currentTime) / duration)

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(
                                LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: currentX, height: 64)
                            .cornerRadius(12) // This might clip the right edge weirdly if not careful, but acceptable for now
                        
                        // Playhead Line
                        Rectangle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                            .frame(width: 2, height: 64)
                            .position(x: currentX, y: 32)
                            .shadow(radius: 2)
                    }
                    
                    // Interaction Layer
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let ratio = min(max(value.location.x / width, 0), 1)
                                    dragTime = ratio * duration
                                }
                                .onEnded { value in
                                    let ratio = min(max(value.location.x / width, 0), 1)
                                    let time = ratio * duration
                                    audioPlayer.seek(to: time)
                                    isDragging = false
                                }
                        )
                }
                .frame(height: 64)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}
