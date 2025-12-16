import Foundation

enum OpenAIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "API Key is missing. Please add it in Settings."
        case .invalidURL: return "Invalid API URL."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message): return "OpenAI API Error: \(message)"
        case .noData: return "No data received from API."
        }
    }
}

class OpenAIClient {
    static let shared = OpenAIClient()
    private let baseURL = "https://api.openai.com/v1"
    
    private init() {}
    
    private var apiKey: String? {
        KeychainService.shared.load()
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }
        
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let data = try createMultipartBody(audioURL: audioURL, boundary: boundary)
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError(URLError(.badServerResponse))
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorJson = try? JSONDecoder().decode(APIErrorResponse.self, from: responseData) {
                throw OpenAIError.apiError(errorJson.error.message)
            }
            throw OpenAIError.apiError("Status code: \(httpResponse.statusCode)")
        }
        
        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: responseData)
        return result.text
    }
    
    func analyze(text: String) async throws -> Analysis {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Analyze the following transcript of a sales conversation. Provide a JSON response with the following fields:
        - summary: A concise summary of the conversation (in Russian).
        - sentiment: The overall sentiment (Positive, Neutral, Negative).
        - score: A sentiment score from 0 to 100.
        - participants: A list of inferred participant names or roles (e.g., "Speaker 1").
        - speakerCount: Total number of distinct speakers detected.
        - languages: A list of languages detected in the conversation.
        - engagementScore: A score from 0 to 100 indicating how engaged the customer is.
        - salesProbability: A probability score from 0 to 100 indicating the likelihood of a sale.
        - objections: A list of objections raised by the customer.
        - nextSteps: A list of actionable next steps.
        - recommendations: Recommendations for the salesperson on how to improve or what to say next.
        - customerIntent: The customer's intent (e.g., "Buying", "Browsing", "Not Interested"). Determine if they are genuinely interested or just agreeing politely.
        - stopWords: A list of filler/stop words detected (e.g., "uh", "um", "like").
        - criteria: An array of evaluation criteria. Each object should have:
            - name: Name of the criterion (e.g., "Greeting", "Needs Analysis", "Closing").
            - score: Score from 0 to 10.
            - comment: A brief comment explaining the score.
        
        Transcript:
        \(text)
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini", // or gpt-3.5-turbo
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that analyzes conversations and outputs JSON."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError(URLError(.badServerResponse))
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
             if let errorJson = try? JSONDecoder().decode(APIErrorResponse.self, from: responseData) {
                throw OpenAIError.apiError(errorJson.error.message)
            }
            throw OpenAIError.apiError("Status code: \(httpResponse.statusCode)")
        }
        
        let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: responseData)
        guard let content = result.choices.first?.message.content,
              let data = content.data(using: .utf8) else {
            throw OpenAIError.noData
        }
        
        do {
            return try JSONDecoder().decode(Analysis.self, from: data)
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "<no-body>"
            throw OpenAIError.decodingError(NSError(domain: "OpenAIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Decode failed: \(error.localizedDescription). Body: \(bodyString)"]))
        }
    }
    
    private func createMultipartBody(audioURL: URL, boundary: String) throws -> Data {
        var data = Data()
        let fileData = try Data(contentsOf: audioURL)
        let filename = audioURL.lastPathComponent
        
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-1\r\n".data(using: .utf8)!)
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
}

// Helper structs for decoding
struct TranscriptionResponse: Codable {
    let text: String
}

struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

struct APIErrorResponse: Codable {
    struct APIError: Codable {
        let message: String
    }
    let error: APIError
}
