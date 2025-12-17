import SwiftUI
import Charts

struct UnifiedPlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    let session: Session
    let analysis: Analysis?
    @EnvironmentObject private var l10n: LocalizationService

    @State private var isDragging = false
    @State private var dragTime: TimeInterval = 0
    @State private var activeMarkerIndex: Int? = nil

    private var audioURL: URL {
        PersistenceService.shared.getAudioURL(for: session.audioFilename)
    }

    private var effectiveDuration: TimeInterval {
        // Some imported files may have 0 duration saved initially; rely on AudioPlayer duration once loaded.
        max(1, max(session.duration, audioPlayer.duration))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Top Controls
            HStack(spacing: 16) {
                Button(action: {
                    audioPlayer.togglePlayback(audioURL: audioURL)
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
                        Text(TimelinePointBuilder.formatHMS(effectiveDuration))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                
                Spacer()
            }
            .padding(.horizontal)

            // Timeline Scrubber
            VStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    // Background Chart
                    if let transcript = session.transcript, !transcript.isEmpty {
                        let points = TimelinePointBuilder.build(transcript: transcript, duration: effectiveDuration)
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
                        let duration = effectiveDuration
                        let rawX = width * CGFloat((isDragging ? dragTime : audioPlayer.currentTime) / duration)
                        let currentX = min(max(rawX, 0), width)
                        let labelX = min(max(currentX, 40), width - 40)
                        let labelTime = isDragging ? dragTime : audioPlayer.currentTime

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

                            // On-bar time label
                            Text(TimelinePointBuilder.formatHMS(labelTime))
                                .monospacedDigit()
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                                .position(x: labelX, y: 10)
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
                                        audioPlayer.seek(to: time, audioURL: audioURL)
                                        isDragging = false
                                    }
                            )
                    }
                    .frame(height: 64)
                    
                    // Key Moments Markers (Top Layer)
                    if let analysis = analysis {
                        GeometryReader { geo in
                            let width = geo.size.width
                            let duration = effectiveDuration

                            let moments = analysis.keyMoments
                            ForEach(Array(moments.enumerated()), id: \.offset) { idx, moment in
                                let parsed = TimelinePointBuilder.parseTimeHintSeconds(moment.timeHint ?? "")
                                let fallbackTime: TimeInterval = {
                                    guard moments.count > 1 else { return duration * 0.5 }
                                    return (duration * Double(idx + 1)) / Double(moments.count + 1)
                                }()

                                let time = (parsed != nil && (parsed ?? 0) <= duration) ? (parsed ?? fallbackTime) : fallbackTime
                                let x = width * CGFloat(min(max(time / duration, 0), 1))
                                MarkerButton(
                                    index: idx,
                                    moment: moment,
                                    x: x,
                                    seekSeconds: time,
                                    isActive: activeMarkerIndex == idx,
                                    onToggleActive: { newValue in
                                        activeMarkerIndex = newValue
                                    },
                                    onSeek: { t in
                                        audioPlayer.seek(to: t, audioURL: audioURL)
                                    }
                                )
                                .zIndex(Double(idx))
                            }
                        }
                        .frame(height: 64)
                        .allowsHitTesting(true) // Allow interaction with markers
                    }
                }

                // Time ticks on the chronometer
                HStack {
                    Text(TimelinePointBuilder.formatHMS(0))
                        .monospacedDigit()
                    Spacer()
                    Text(TimelinePointBuilder.formatHMS(effectiveDuration / 2))
                        .monospacedDigit()
                    Spacer()
                    Text(TimelinePointBuilder.formatHMS(effectiveDuration))
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
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
    let index: Int
    let moment: KeyMoment
    let x: CGFloat
    let seekSeconds: TimeInterval
    let isActive: Bool
    let onToggleActive: ((Int?) -> Void)?
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
            onToggleActive?(isActive ? nil : index)
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
        // Ensure the marker tap wins over the scrubber drag gesture underneath.
        .highPriorityGesture(
            TapGesture().onEnded {
                onSeek?(seekSeconds)
                onToggleActive?(isActive ? nil : index)
            }
        )
        .popover(isPresented: Binding(
            get: { isActive },
            set: { newValue in
                if !newValue { onToggleActive?(nil) }
            }
        )) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(TimelinePointBuilder.formatHMS(seekSeconds))
                        .monospacedDigit()
                        .font(.headline)
                    Spacer()
                    if let type = moment.type, !type.isEmpty {
                        Text(type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let speaker = moment.speaker, !speaker.isEmpty {
                    Text(speaker)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(moment.text)
                    .font(.body)

                if let rec = moment.recommendation, !rec.isEmpty {
                    Divider()
                    Text(rec)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(width: 360, alignment: .leading)
        }
    }
}
