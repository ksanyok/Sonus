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
    var summary: String
    var sentiment: String // "Positive", "Neutral", "Negative"
    var score: Int // 0-100
    var participants: [String]
    var languages: [String]
    
    // New fields for sales analysis
    var engagementScore: Int // 0-100
    var salesProbability: Int // 0-100
    var objections: [String]
    var nextSteps: [String]
    var recommendations: [String]
    var customerIntent: String // "Buying", "Browsing", "Not Interested"
    
    // Detailed criteria (optional for backward compatibility)
    var criteria: [EvaluationCriterion] = []
    
    init(summary: String,
         sentiment: String,
         score: Int,
         participants: [String],
         languages: [String],
         engagementScore: Int,
         salesProbability: Int,
         objections: [String],
         nextSteps: [String],
         recommendations: [String],
         customerIntent: String,
         criteria: [EvaluationCriterion] = []) {
        self.summary = summary
        self.sentiment = sentiment
        self.score = score
        self.participants = participants
        self.languages = languages
        self.engagementScore = engagementScore
        self.salesProbability = salesProbability
        self.objections = objections
        self.nextSteps = nextSteps
        self.recommendations = recommendations
        self.customerIntent = customerIntent
        self.criteria = criteria
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        sentiment = (try? c.decode(String.self, forKey: .sentiment)) ?? "Neutral"
        score = (try? c.decode(Int.self, forKey: .score)) ?? 0
        participants = (try? c.decode([String].self, forKey: .participants)) ?? []
        languages = (try? c.decode([String].self, forKey: .languages)) ?? []
        engagementScore = (try? c.decode(Int.self, forKey: .engagementScore)) ?? 0
        salesProbability = (try? c.decode(Int.self, forKey: .salesProbability)) ?? 0
        objections = (try? c.decode([String].self, forKey: .objections)) ?? []
        nextSteps = (try? c.decode([String].self, forKey: .nextSteps)) ?? []
        recommendations = (try? c.decode([String].self, forKey: .recommendations)) ?? []
        customerIntent = (try? c.decode(String.self, forKey: .customerIntent)) ?? ""
        criteria = (try? c.decode([EvaluationCriterion].self, forKey: .criteria)) ?? []
    }
}

struct EvaluationCriterion: Codable, Equatable, Hashable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let score: Int // 0-10
    let comment: String
}
