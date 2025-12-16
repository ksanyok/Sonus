import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.sessions) { session in
                NavigationLink(value: session) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.title)
                                .font(.headline)
                            Text(session.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let analysis = session.analysis {
                            Text("\(analysis.score)%")
                                .font(.caption)
                                .padding(4)
                                .background(color(for: analysis.score))
                                .cornerRadius(4)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: viewModel.deleteSessions)
        }
        .navigationTitle("History")
    }
    
    func color(for score: Int) -> Color {
        switch score {
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
        }
    }
}
