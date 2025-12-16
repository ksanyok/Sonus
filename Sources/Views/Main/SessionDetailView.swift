import SwiftUI
import AppKit

struct SessionDetailView: View {
    let session: Session
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.largeTitle).bold()
                    HStack(spacing: 8) {
                        Label(session.category.displayName, systemImage: session.category.icon)
                        Text("•")
                        Text(session.date.formatted(date: .long, time: .shortened))
                        Text("•")
                        Text(formatDuration(session.duration))
                    }
                    .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 10) {
                        Button("Analyze") { viewModel.processSession(session) }
                            .buttonStyle(.borderedProminent)
                            .disabled(session.isProcessing)
                        Button("Delete", role: .destructive) { viewModel.deleteSession(session) }
                            .buttonStyle(.bordered)
                    }
                    if session.isProcessing {
                        ProgressView("Processing...")
                            .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Audio Player card
            HStack(spacing: 16) {
                Button(action: {
                    let url = PersistenceService.shared.getAudioURL(for: session.audioFilename)
                    audioPlayer.togglePlayback(audioURL: url)
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 6) {
                    Slider(value: playbackProgress)
                    HStack {
                        Text(formatDuration(audioPlayer.currentTime)).foregroundColor(.secondary)
                        Spacer()
                        Text(formatDuration(displayDuration)).foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                .padding(.vertical, 8)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(14)
            .padding(.horizontal)
            
            // Content
            if let analysis = session.analysis {
                Picker("", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Analysis").tag(1)
                    Text("Transcript").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == 0 {
                            OverviewView(analysis: analysis)
                        } else if selectedTab == 1 {
                            DetailedAnalysisView(analysis: analysis)
                        } else {
                            TranscriptView(transcript: session.transcript)
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                Text("No analysis available")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var displayDuration: TimeInterval {
        let effectiveDuration = audioPlayer.duration > 0 ? audioPlayer.duration : session.duration
        return effectiveDuration > 0 ? effectiveDuration : 0
    }

    private var playbackProgress: Binding<Double> {
        Binding(get: {
            guard displayDuration > 0 else { return 0 }
            return audioPlayer.currentTime / displayDuration
        }, set: { ratio in
            guard displayDuration > 0 else { return }
            audioPlayer.seek(to: ratio * displayDuration)
        })
    }
}

struct OverviewView: View {
    let analysis: Analysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary Card
            VStack(alignment: .leading, spacing: 10) {
                Label("Summary", systemImage: "text.alignleft")
                    .font(.headline)
                Text(analysis.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            // Key Metrics
            HStack(spacing: 20) {
                MetricCard(title: "Score", value: "\(analysis.score)%", icon: "chart.bar.fill", color: .blue)
                MetricCard(title: "Sentiment", value: analysis.sentiment, icon: "face.smiling", color: .green)
                MetricCard(title: "Engagement", value: "\(analysis.engagementScore)%", icon: "person.2.wave.2.fill", color: .orange)
                MetricCard(title: "Sales Prob.", value: "\(analysis.salesProbability)%", icon: "cart.badge.plus", color: .pink)
            }
            
            // Speakers / Languages
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Speakers", systemImage: "person.3.fill")
                    Spacer()
                    Text("\(analysis.speakerCount ?? analysis.participants.count) participant(s)")
                        .foregroundColor(.secondary)
                }
                WrapChips(items: analysis.participants)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Label("Languages", systemImage: "globe")
                WrapChips(items: analysis.languages)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            if let stop = analysis.stopWords, !stop.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Stop words / fillers", systemImage: "ellipsis.message")
                    WrapChips(items: stop)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            
            // Intent
            VStack(alignment: .leading, spacing: 10) {
                Label("Customer Intent", systemImage: "cart.fill")
                    .font(.headline)
                Text(analysis.customerIntent)
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            if !analysis.nextSteps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Next Steps", systemImage: "arrow.turn.up.right")
                        .font(.headline)
                    ForEach(analysis.nextSteps, id: \.self) { step in
                        HStack(alignment: .top) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .padding(.top, 6)
                            Text(step)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
}

struct DetailedAnalysisView: View {
    let analysis: Analysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Criteria
            VStack(alignment: .leading, spacing: 10) {
                Label("Evaluation Criteria", systemImage: "checklist")
                    .font(.headline)
                
                ForEach(analysis.criteria) { criterion in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(criterion.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(criterion.comment)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(criterion.score)/10")
                            .font(.headline)
                            .foregroundColor(criterion.score >= 7 ? .green : (criterion.score >= 4 ? .orange : .red))
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            // Recommendations
            VStack(alignment: .leading, spacing: 10) {
                Label("Recommendations", systemImage: "lightbulb.fill")
                    .font(.headline)
                
                ForEach(analysis.recommendations, id: \.self) { rec in
                    HStack(alignment: .top) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .padding(.top, 6)
                        Text(rec)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            if !analysis.objections.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Objections", systemImage: "exclamationmark.bubble")
                        .font(.headline)
                    ForEach(analysis.objections, id: \.self) { obj in
                        HStack(alignment: .top) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 10))
                                .padding(.top, 4)
                            Text(obj)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
}

struct TranscriptView: View {
    let transcript: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let text = transcript {
                Text(text)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            } else {
                Text("No transcript available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct WrapChips: View {
    let items: [String]
    
    var body: some View {
        FlexibleView(data: items, spacing: 8, alignment: .leading) { item in
            Text(item)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
        }
    }
}

// Simple flexible wrap layout
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    
    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geo in
            let rows = buildRows(for: geo.size.width)
            VStack(alignment: alignment, spacing: spacing) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(rows[row], id: \.self) { element in
                            content(element)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func buildRows(for availableWidth: CGFloat) -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for element in data {
            let w = estimateWidth(for: element)
            if currentWidth + w + spacing > availableWidth {
                rows.append([element])
                currentWidth = w + spacing
            } else {
                if rows[rows.count - 1].isEmpty {
                    rows[rows.count - 1].append(element)
                } else {
                    rows[rows.count - 1].append(element)
                }
                currentWidth += w + spacing
            }
        }
        return rows
    }
    
    private func estimateWidth(for element: Data.Element) -> CGFloat {
        let attr = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))]
        let size = (String(describing: element) as NSString).size(withAttributes: attr)
        return size.width + 20 // padding used in chip
    }
}
