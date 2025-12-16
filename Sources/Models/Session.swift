import Foundation

struct Session: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let date: Date
    var duration: TimeInterval
    let audioFilename: String
    
    var transcript: String? = nil
    var analysis: Analysis? = nil
    var isProcessing: Bool = false
    var category: SessionCategory = .personal
    var customTitle: String? = nil
    
    var title: String {
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
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

enum SessionCategory: String, Codable, CaseIterable, Identifiable {
    case personal = "Personal"
    case clients = "Clients"
    case conferences = "Conferences"
    case meetings = "Meetings"
    case other = "Other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .personal: return "Личное"
        case .clients: return "Клиенты"
        case .conferences: return "Конференции"
        case .meetings: return "Встречи"
        case .other: return "Прочее"
        }
    }
    
    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .clients: return "briefcase.fill"
        case .conferences: return "mic.fill"
        case .meetings: return "person.3.fill"
        case .other: return "archivebox.fill"
        }
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
    
        // Detailed criteria (optional for backward compatibility)
        var criteria: [EvaluationCriterion] = []
}

struct EvaluationCriterion: Codable, Equatable, Hashable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let score: Int // 0-10
    let comment: String
}
