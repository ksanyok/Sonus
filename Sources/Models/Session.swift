import Foundation

struct Session: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let date: Date
    var duration: TimeInterval
    let audioFilename: String
    
    var transcript: String?
    var analysis: Analysis?
    var isProcessing: Bool = false
    
    var title: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Analysis: Codable, Equatable, Hashable {
    let summary: String
    let sentiment: String // "Positive", "Neutral", "Negative"
    let score: Int // 0-100
    let participants: [String]
    let languages: [String]
    
    // New fields for sales analysis
    let engagementScore: Int // 0-100
    let salesProbability: Int // 0-100
    let objections: [String]
    let nextSteps: [String]
    let recommendations: [String]
    let customerIntent: String // "Buying", "Browsing", "Not Interested"
}
