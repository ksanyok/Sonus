import Foundation

enum Playbook: String, CaseIterable, Identifiable, Codable {
    case sales = "Sales"
    case support = "Support"
    case interview = "Interview"
    case general = "General"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sales: return "Sales / Negotiation"
        case .support: return "Customer Support"
        case .interview: return "HR / Interview"
        case .general: return "General Meeting"
        }
    }
    
    var promptInstruction: String {
        switch self {
        case .sales:
            return """
            Focus heavily on sales methodology (SPIN, BANT, etc.). 
            Evaluate:
            - Discovery quality (did they ask enough questions?)
            - Objection handling (was it empathetic and effective?)
            - Closing (did they ask for the next step?)
            - Commercial awareness.
            """
        case .support:
            return """
            Focus on customer service quality.
            Evaluate:
            - Empathy and tone.
            - Problem understanding and resolution speed.
            - Clarity of instructions.
            - Patience with frustrated customers.
            """
        case .interview:
            return """
            Focus on candidate evaluation.
            Evaluate:
            - Competence and hard skills mentioned.
            - Soft skills (communication, honesty).
            - Cultural fit.
            - Red flags or inconsistencies.
            """
        case .general:
            return "Provide a balanced analysis of communication effectiveness, clarity, and action items."
        }
    }
}
