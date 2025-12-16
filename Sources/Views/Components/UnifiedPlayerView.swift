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
                                    colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
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
                
                // Progress Fill (Overlay)
                GeometryReader { geo in
                    let width = geo.size.width
                    let duration = max(1, session.duration)
                    let currentX = width * CGFloat((isDragging ? dragTime : audioPlayer.currentTime) / duration)

                    ZStack(alignment: .leading) {
                        // Masked fill for played portion
                        Rectangle()
                            .fill(
                                LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: currentX, height: 64)
                            .cornerRadius(12)
                        
                        // Playhead Line
                        Capsule()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                            .frame(width: 4, height: 64)
                            .position(x: currentX, y: 32)
                            .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 0)
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
                
                // Key Moments Markers (Top Layer)
                if let analysis = analysis {
                    GeometryReader { geo in
                        let width = geo.size.width
                        let duration = max(1, session.duration)
                        
                        ForEach(Array(analysis.keyMoments.enumerated()), id: \.offset) { _, moment in
                            if let time = parseTimeHint(moment.timeHint), time <= duration {
                                let x = width * CGFloat(time / duration)
                                MarkerButton(moment: moment, x: x)
                            }
                        }
                    }
                    .frame(height: 64)
                    .allowsHitTesting(true) // Allow interaction with markers
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func parseTimeHint(_ hint: String?) -> TimeInterval? {
        guard let hint = hint, !hint.isEmpty else { return nil }
        let parts = hint.split(separator: ":").map { Double($0) ?? 0 }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        } else if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        return nil
    }
}

struct MarkerButton: View {
    let moment: KeyMoment
    let x: CGFloat
    @State private var isHovered = false
    
    var markerColor: Color {
        switch moment.severity {
        case "critical": return .red
        case "warning": return .orange
        case "info": return .blue
        default: return .orange
        }
    }
    
    var body: some View {
        ZStack {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 12))
                .foregroundColor(markerColor)
                .background(Circle().fill(.white).frame(width: 16, height: 16))
                .shadow(radius: 2)
                .scaleEffect(isHovered ? 1.5 : 1.0)
                .animation(.spring(), value: isHovered)
            
            if isHovered {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(moment.type?.uppercased() ?? "MOMENT")
                            .font(.caption2.bold())
                            .foregroundColor(markerColor)
                        Spacer()
                        if let sev = moment.severity {
                            Text(sev.uppercased())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(moment.text)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let rec = moment.recommendation, !rec.isEmpty {
                        Divider()
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(rec)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(8)
                .frame(width: 220)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(8)
                .shadow(radius: 4)
                .offset(y: -80) // Show above the marker
            }
        }
        .position(x: x, y: 32) // Centered vertically in the 64px height
        .onHover { hover in
            isHovered = hover
        }
    }
}
