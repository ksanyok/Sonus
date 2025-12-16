import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: session.category.icon)
                        Text(session.category.displayName)
                        Text("•")
                        Text(session.date.formatted(date: .long, time: .shortened))
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if session.isProcessing {
                    ProgressView("Processing...")
                        .controlSize(.small)
                } else if session.analysis == nil {
                    Button("Analyze") {
                        viewModel.processSession(session)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            // Audio Player
            VStack(spacing: 8) {
                HStack {
                    Button(action: {
                        let url = PersistenceService.shared.getAudioURL(for: session.audioFilename)
                        audioPlayer.togglePlayback(audioURL: url)
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    
                    VStack(spacing: 4) {
                        ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration > 0 ? audioPlayer.duration : session.duration)
                            .tint(.accentColor)
                        
                        HStack {
                            Text(formatDuration(audioPlayer.currentTime))
                            Spacer()
                            Text(formatDuration(audioPlayer.duration > 0 ? audioPlayer.duration : session.duration))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
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
