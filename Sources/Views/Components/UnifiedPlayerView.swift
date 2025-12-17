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

                        let moments = analysis.keyMoments
                        ForEach(Array(moments.enumerated()), id: \.offset) { idx, moment in
                            let parsed = TimelinePointBuilder.parseTimeHintSeconds(moment.timeHint ?? "")
                            let fallbackTime: TimeInterval = {
                                guard moments.count > 1 else { return duration * 0.5 }
                                return (duration * Double(idx + 1)) / Double(moments.count + 1)
                            }()

                            let time = (parsed != nil && (parsed ?? 0) <= duration) ? (parsed ?? fallbackTime) : fallbackTime
                            let x = width * CGFloat(min(max(time / duration, 0), 1))
                            MarkerButton(moment: moment, x: x, seekSeconds: time, onSeek: { t in
                                audioPlayer.seek(to: t)
                            })
                            .zIndex(Double(idx))
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
    
    // Time parsing moved to TimelinePointBuilder.parseTimeHintSeconds(_:) to keep behavior consistent across the app.
}

struct MarkerButton: View {
    let moment: KeyMoment
    let x: CGFloat
    let seekSeconds: TimeInterval
    let onSeek: ((TimeInterval) -> Void)?

    private var hoverTooltip: String {
        var parts: [String] = []
        if let th = moment.timeHint, !th.isEmpty {
            parts.append(th)
        }
        if let t = moment.type, !t.isEmpty {
            parts.append(t)
        }
        if let s = moment.speaker, !s.isEmpty {
            parts.append(s)
        }
        parts.append(moment.text)
        if let rec = moment.recommendation, !rec.isEmpty {
            parts.append(rec)
        }
        return parts.joined(separator: " — ")
    }
    
    var markerColor: Color {
        switch moment.severity {
        case "critical": return .red
        case "warning": return .orange
        case "info": return .blue
        default: return .orange
        }
    }
    
    var body: some View {
        Button {
            onSeek?(seekSeconds)
        } label: {
            ZStack {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 12))
                    .foregroundColor(markerColor)
                    .background(Circle().fill(.white).frame(width: 16, height: 16))
                    .shadow(radius: 2)
            }
            .frame(width: 18, height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: x, y: 32)
        .help(hoverTooltip)
    }
}
