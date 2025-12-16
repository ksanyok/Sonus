import SwiftUI

struct GlobalSearchView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var selectedSessionID: UUID?
    
    var filteredSessions: [Session] {
        if searchText.isEmpty {
            return []
        }
        let query = searchText.lowercased()
        return viewModel.sessions.filter { session in
            let titleMatch = (session.customTitle ?? "").lowercased().contains(query)
            let transcriptMatch = (session.transcript ?? "").lowercased().contains(query)
            let summaryMatch = (session.analysis?.summary ?? "").lowercased().contains(query)
            
            // Search in participants
            let participantsMatch = session.analysis?.participants.contains { $0.lowercased().contains(query) } ?? false
            
            // Search in objections
            let objectionsMatch = session.analysis?.objections.contains { $0.lowercased().contains(query) } ?? false
            
            return titleMatch || transcriptMatch || summaryMatch || participantsMatch || objectionsMatch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search transcripts, summaries, participants...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title2)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor)), alignment: .bottom)
            
            // Results
            if searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Type to search across all conversations")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredSessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No matches found")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredSessions, selection: $selectedSessionID) { session in
                    NavigationLink(destination: SessionDetailView(sessionID: session.id, viewModel: viewModel)) {
                        SearchResultRow(session: session, query: searchText)
                    }
                    .tag(session.id)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Global Search")
    }
}

struct SearchResultRow: View {
    let session: Session
    let query: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.customTitle ?? session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Spacer()
                Text(session.date.formatted(date: .numeric, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let summary = session.analysis?.summary {
                Text(highlightedText(text: summary, query: query))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Show matching context snippet if found in transcript
            if let transcript = session.transcript, 
               transcript.lowercased().contains(query.lowercased()) {
                Text("... " + snippet(from: transcript, query: query) + " ...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Simple highlighting helper (returns AttributedString in newer SwiftUI, but for simplicity here just returning String or using simple logic)
    // For now, just returning text. Highlighting in SwiftUI Text requires AttributedString (macOS 12+).
    // Assuming macOS 12+ for this project.
    
    func highlightedText(text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        
        var searchRange = lowerText.startIndex..<lowerText.endIndex
        while let range = lowerText.range(of: lowerQuery, options: [], range: searchRange) {
            // Convert String.Index to AttributedString.Index
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].foregroundColor = .blue
                attributed[attrRange].font = .caption.bold()
            }
            searchRange = range.upperBound..<lowerText.endIndex
        }
        return attributed
    }
    
    func snippet(from text: String, query: String) -> String {
        guard let range = text.lowercased().range(of: query.lowercased()) else { return "" }
        let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end]).replacingOccurrences(of: "\n", with: " ")
    }
}
