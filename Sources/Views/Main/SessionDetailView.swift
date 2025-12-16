import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var audioPlayer = AudioPlayer()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.title)
                            .font(.title)
                        Text(formatDuration(session.duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        let url = PersistenceService.shared.getAudioURL(for: session.audioFilename)
                        audioPlayer.togglePlayback(audioURL: url)
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    
                    if session.isProcessing {
                        ProgressView("Processing...")
                    } else if session.analysis == nil {
                        Button("Analyze") {
                            viewModel.processSession(session)
                        }
                    }
                }
                
                if audioPlayer.isPlaying {
                    ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration)
                        .padding(.horizontal)
                }
                
                if let analysis = session.analysis {
                    Group {
                        DetailSection(title: "Summary", content: analysis.summary)
                        
                        HStack(spacing: 20) {
                            ScoreView(title: "Sentiment", value: analysis.sentiment)
                            ScoreView(title: "Score", value: "\(analysis.score)/100")
                            ScoreView(title: "Engagement", value: "\(analysis.engagementScore)/100")
                            ScoreView(title: "Sales Prob.", value: "\(analysis.salesProbability)%")
                        }
                        
                        DetailSection(title: "Customer Intent", content: analysis.customerIntent)
                        
                        if !analysis.objections.isEmpty {
                            DetailSection(title: "Objections", content: analysis.objections.joined(separator: "\n• "))
                        }
                        
                        if !analysis.nextSteps.isEmpty {
                            DetailSection(title: "Next Steps", content: analysis.nextSteps.joined(separator: "\n• "))
                        }
                        
                        if !analysis.recommendations.isEmpty {
                            DetailSection(title: "Recommendations", content: analysis.recommendations.joined(separator: "\n• "))
                        }
                        
                        DetailSection(title: "Participants", content: analysis.participants.joined(separator: ", "))
                        DetailSection(title: "Languages", content: analysis.languages.joined(separator: ", "))
                    }
                }
                
                if let transcript = session.transcript {
                    DetailSection(title: "Transcript", content: transcript)
                }
            }
            .padding()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

struct DetailSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ScoreView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
