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
        formatter.locale = .autoupdatingCurrent
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

    var displayNameEn: String {
        switch self {
        case .personal: return "Personal"
        case .clients: return "Clients"
        case .conferences: return "Conferences"
        case .meetings: return "Meetings"
        case .other: return "Other"
        }
    }

    var displayNameRu: String {
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
    var speakerCount: Int?
    var stopWords: [String]?
    
    // New fields for sales analysis
    var engagementScore: Int // 0-100
    var salesProbability: Int // 0-100
    var objections: [String]
    var nextSteps: [String]
    var recommendations: [String]
    var customerIntent: String // "Buying", "Browsing", "Not Interested"
    
    // Detailed criteria (optional for backward compatibility)
    var criteria: [EvaluationCriterion] = []

    // Extended fields (optional; may be absent depending on transcript quality)
    var communicationStyle: CommunicationStyle?
    var client: ParticipantProfile?
    var otherParticipants: [ParticipantProfile]?
    var extractedEntities: ExtractedEntities?
    var clientInsights: ClientInsights?
    var keyMoments: [KeyMoment] = []
    var actionItems: [ActionItem] = []
    var commitments: [Commitment] = []
    var conversationMetrics: ConversationMetrics?
    
    init(summary: String,
         sentiment: String,
         score: Int,
         participants: [String],
         languages: [String],
         speakerCount: Int? = nil,
         stopWords: [String]? = nil,
         engagementScore: Int,
         salesProbability: Int,
         objections: [String],
         nextSteps: [String],
         recommendations: [String],
         customerIntent: String,
         criteria: [EvaluationCriterion] = [],
         communicationStyle: CommunicationStyle? = nil,
         client: ParticipantProfile? = nil,
         otherParticipants: [ParticipantProfile]? = nil,
         extractedEntities: ExtractedEntities? = nil,
         clientInsights: ClientInsights? = nil,
         keyMoments: [KeyMoment] = [],
            actionItems: [ActionItem] = [],
            commitments: [Commitment] = [],
            conversationMetrics: ConversationMetrics? = nil) {
        self.summary = summary
        self.sentiment = sentiment
        self.score = score
        self.participants = participants
        self.languages = languages
        self.speakerCount = speakerCount
        self.stopWords = stopWords
        self.engagementScore = engagementScore
        self.salesProbability = salesProbability
        self.objections = objections
        self.nextSteps = nextSteps
        self.recommendations = recommendations
        self.customerIntent = customerIntent
        self.criteria = criteria
        self.communicationStyle = communicationStyle
        self.client = client
        self.otherParticipants = otherParticipants
        self.extractedEntities = extractedEntities
        self.clientInsights = clientInsights
        self.keyMoments = keyMoments
        self.actionItems = actionItems
        self.commitments = commitments
        self.conversationMetrics = conversationMetrics
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        sentiment = (try? c.decode(String.self, forKey: .sentiment)) ?? "Neutral"
        score = (try? c.decode(Int.self, forKey: .score)) ?? 0
        participants = (try? c.decode([String].self, forKey: .participants)) ?? []
        languages = (try? c.decode([String].self, forKey: .languages)) ?? []
        speakerCount = try? c.decode(Int.self, forKey: .speakerCount)
        stopWords = try? c.decode([String].self, forKey: .stopWords)
        engagementScore = (try? c.decode(Int.self, forKey: .engagementScore)) ?? 0
        salesProbability = (try? c.decode(Int.self, forKey: .salesProbability)) ?? 0
        objections = (try? c.decode([String].self, forKey: .objections)) ?? []
        nextSteps = (try? c.decode([String].self, forKey: .nextSteps)) ?? []
        recommendations = (try? c.decode([String].self, forKey: .recommendations)) ?? []
        customerIntent = (try? c.decode(String.self, forKey: .customerIntent)) ?? ""
        criteria = (try? c.decode([EvaluationCriterion].self, forKey: .criteria)) ?? []

        communicationStyle = try? c.decode(CommunicationStyle.self, forKey: .communicationStyle)
        client = try? c.decode(ParticipantProfile.self, forKey: .client)
        otherParticipants = try? c.decode([ParticipantProfile].self, forKey: .otherParticipants)
        extractedEntities = try? c.decode(ExtractedEntities.self, forKey: .extractedEntities)
        clientInsights = try? c.decode(ClientInsights.self, forKey: .clientInsights)
        keyMoments = (try? c.decode([KeyMoment].self, forKey: .keyMoments)) ?? []
        actionItems = (try? c.decode([ActionItem].self, forKey: .actionItems)) ?? []
        commitments = (try? c.decode([Commitment].self, forKey: .commitments)) ?? []
        conversationMetrics = try? c.decode(ConversationMetrics.self, forKey: .conversationMetrics)
    }
}

struct ParticipantProfile: Codable, Equatable, Hashable {
    var label: String?
    var name: String?
    var role: String?
    var company: String?
    var title: String?
    var contact: ContactInfo?
    var notes: String?
    var confidence: Int? // 0-100
}

struct ContactInfo: Codable, Equatable, Hashable {
    var emails: [String]?
    var phones: [String]?
    var messengers: [String]?
}

struct CommunicationStyle: Codable, Equatable, Hashable {
    var formality: String? // "formal" | "neutral" | "informal"
    var tone: [String]? // e.g. ["дружелюбный", "деловой"]
    var pacing: String? // "fast" | "moderate" | "slow"
    var structure: String? // "structured" | "mixed" | "chaotic"
    var conflictLevel: Int? // 0-100
}

struct ExtractedEntities: Codable, Equatable, Hashable {
    var companies: [String]?
    var people: [String]?
    var products: [String]?
    var locations: [String]?
    var urls: [String]?
    var emails: [String]?
    var phones: [String]?
    var dateMentions: [DateMention]?
}

struct DateMention: Codable, Equatable, Hashable {
    var text: String
    var isoDate: String? // YYYY-MM-DD when confidently inferred
    var context: String?
}

struct ClientInsights: Codable, Equatable, Hashable {
    var summary: String?
    var goals: [String]?
    var painPoints: [String]?
    var priorities: [String]?
    var budget: String?
    var timeline: String?
    var decisionMakers: [String]?
    var decisionProcess: String?
    var buyingSignals: [String]?
    var risks: [String]?
}

struct KeyMoment: Codable, Equatable, Hashable {
    var speaker: String?
    var text: String
    var type: String? // e.g. "objection" | "agreement" | "requirement" | "deadline"
    var timeHint: String? // e.g. "00:12:34" when possible
}

struct ActionItem: Codable, Equatable, Hashable {
    var title: String
    var owner: String? // "sales" | "client" | name
    var dueDateISO: String? // YYYY-MM-DD
    var priority: String? // "low" | "medium" | "high"
    var notes: String?
}

struct Commitment: Codable, Equatable, Hashable {
    var title: String
    var owner: String? // "sales" | "client" | name
    var dueDateISO: String? // YYYY-MM-DD
    var notes: String?
    var confidence: Int? // 0-100
}

struct ConversationMetrics: Codable, Equatable, Hashable {
    var talkTimeShare: [String: Int]? // e.g. {"sales": 55, "client": 45}
    var interruptionsCount: Int?
    var questionCount: Int?
    var monologueLongestSeconds: Int?
    var sentimentTrend: String? // e.g. "improving" | "worsening" | "stable" | "mixed"
    var riskFlags: [String]?
}

struct EvaluationCriterion: Codable, Equatable, Hashable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let score: Int // 0-10
    let comment: String
}
