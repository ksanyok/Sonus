import Foundation
import AVFoundation

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

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    private var apiKey: String? {
        KeychainService.shared.load()
    }
    
    func transcribe(audioURL: URL, onProgress: ((Double, String) -> Void)? = nil) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        // Очень длинные/большие записи часто падают по таймауту или лимиту размера — режем на куски.
        if try shouldChunkAudio(audioURL: audioURL) {
            return try await transcribeInChunks(audioURL: audioURL, onProgress: onProgress)
        }

        onProgress?(0.05, "Транскрибация…")
        return try await transcribeSingle(audioURL: audioURL, apiKey: apiKey)
    }

    struct RealtimeHintResponse: Codable {
        let answer: String
        let engagement: Double
        
    }

    func realtimeHint(question: String, context: String) async throws -> RealtimeHintResponse {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Ты — ассистент продавца во время звонка. На основе последнего контекста диалога предложи краткий и конкретный ответ на вопрос клиента.
        Также оцени вовлечённость клиента по шкале 0..1 (0 = теряем клиента, 1 = высокий интерес).

        Верни строго JSON:
        {"answer": "...", "engagement": 0.0}

        Контекст (последние реплики):
        \(context)

        Вопрос клиента:
        \(question)
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Отвечай на русском. Возвращай только JSON без Markdown."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.4
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (responseData, response) = try await session.data(for: request)

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
        return try JSONDecoder().decode(RealtimeHintResponse.self, from: data)
    }
    
    func analyze(text: String) async throws -> Analysis {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let condensed = try await condensedTranscriptIfNeeded(text)
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
                let prompt = """
                Проанализируй стенограмму разговора (чаще всего — продажа/переговоры). Верни СТРОГО JSON (без Markdown), с полями ниже.

                Важно:
                - Если данных нет, ставь null или пустой массив.
                - Не выдумывай имена/компании/контакты: извлекай только то, что явно сказано в тексте.
                - Все текстовые поля пиши на русском.

                Обязательные поля:
                - summary: краткое резюме.
                - sentiment: "Positive" | "Neutral" | "Negative".
                - score: 0..100 (общее качество/успешность разговора).
                - participants: массив строк (имена/роли, если можно понять).
                - speakerCount: число говорящих (если уверенно).
                - languages: массив языков.
                - engagementScore: 0..100 (насколько клиент вовлечён).
                - salesProbability: 0..100 (вероятность сделки/конверсии).
                - objections: массив возражений.
                - nextSteps: массив следующих шагов.
                - recommendations: массив рекомендаций продавцу.
                - customerIntent: строка (например: "Buying"/"Browsing"/"Not Interested").
                - stopWords: массив слов-паразитов/филлеров.
                - criteria: массив объектов {name, score(0..10), comment}.

                Расширенные поля:
                - communicationStyle: объект {
                        formality: "formal"|"neutral"|"informal",
                        tone: массив строк,
                        pacing: "fast"|"moderate"|"slow",
                        structure: "structured"|"mixed"|"chaotic",
                        conflictLevel: 0..100
                    }
                - client: объект {
                        label, name, role, company, title,
                        contact: {emails:[...], phones:[...], messengers:[...]},
                        notes, confidence(0..100)
                    }
                - otherParticipants: массив объектов ParticipantProfile (та же структура, что client)
                - extractedEntities: объект {
                        companies:[...], people:[...], products:[...], locations:[...],
                        urls:[...], emails:[...], phones:[...],
                        dateMentions:[{text, isoDate, context}]
                    }
                - clientInsights: объект {
                        summary,
                        goals:[...], painPoints:[...], priorities:[...],
                        budget, timeline,
                        decisionMakers:[...], decisionProcess,
                        buyingSignals:[...], risks:[...]
                    }
                - keyMoments: массив объектов {speaker, text, type, timeHint}
                - actionItems: массив объектов {title, owner, dueDateISO, priority, notes}

                Стенограмма:
                \(condensed)
                """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini", // or gpt-3.5-turbo
            "messages": [
                ["role": "system", "content": "Ты аналитик переговоров. Отвечай на русском. Возвращай только JSON."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        request.timeoutInterval = 180

        let (responseData, response) = try await session.data(for: request)
        
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
        let mimeType = mimeType(for: audioURL)
        
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-1\r\n".data(using: .utf8)!)
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }

    private func transcribeSingle(audioURL: URL, apiKey: String) async throws -> String {
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let data = try createMultipartBody(audioURL: audioURL, boundary: boundary)
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
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

    private func shouldChunkAudio(audioURL: URL) throws -> Bool {
        let attrs = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0

        // Если файл больше 20MB — почти наверняка будет больно.
        if size > 20 * 1024 * 1024 { return true }

        // И если длительность > 15 минут — тоже режем, чтобы не словить таймаут.
        let asset = AVURLAsset(url: audioURL)
        let seconds = CMTimeGetSeconds(asset.duration)
        if seconds.isFinite, seconds > 15 * 60 { return true }
        return false
    }

    private func transcribeInChunks(audioURL: URL, onProgress: ((Double, String) -> Void)?) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let asset = AVURLAsset(url: audioURL)
        let duration = CMTimeGetSeconds(asset.duration)
        if !duration.isFinite || duration <= 0 {
            return try await transcribeSingle(audioURL: audioURL, apiKey: apiKey)
        }

        let chunkSeconds: Double = 8 * 60
        var cursor: Double = 0
        var parts: [String] = []
        let total = max(1, Int(ceil(duration / chunkSeconds)))
        var index = 0

        while cursor < duration {
            let end = min(duration, cursor + chunkSeconds)
            index += 1
            onProgress?(min(0.85, 0.1 + 0.7 * (Double(index - 1) / Double(total))), "Экспорт фрагмента \(index)/\(total)…")
            let segmentURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")

            try await exportSegment(asset: asset, start: cursor, end: end, to: segmentURL)

            onProgress?(min(0.9, 0.1 + 0.7 * (Double(index - 1) / Double(total)) + 0.2 / Double(total)), "Транскрибация фрагмента \(index)/\(total)…")
            let text = try await transcribeSingle(audioURL: segmentURL, apiKey: apiKey)
            parts.append(text)
            try? FileManager.default.removeItem(at: segmentURL)
            cursor = end
        }
        onProgress?(0.9, "Склейка результата…")
        return parts.joined(separator: "\n")
    }

    private func exportSegment(asset: AVURLAsset, start: Double, end: Double, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw OpenAIError.apiError("Не удалось создать экспорт аудио сегмента")
        }
        exporter.outputURL = url
        exporter.outputFileType = .m4a
        exporter.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )
        try await withCheckedThrowingContinuation { cont in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    cont.resume(returning: ())
                case .failed:
                    cont.resume(throwing: exporter.error ?? OpenAIError.apiError("Экспорт сегмента не удался"))
                case .cancelled:
                    cont.resume(throwing: OpenAIError.apiError("Экспорт сегмента отменён"))
                default:
                    cont.resume(throwing: OpenAIError.apiError("Экспорт сегмента: неизвестный статус"))
                }
            }
        }
    }

    private func condensedTranscriptIfNeeded(_ text: String) async throws -> String {
        // Для многочасовых разговоров JSON-анализ по сырой стенограмме часто таймаутится.
        // Сначала сжимаем в краткий конспект.
        if text.count <= 12_000 { return text }

        let chunks = splitText(text, chunkSize: 7_000)
        var notes: [String] = []
        for chunk in chunks {
            let note = try await summarizeChunk(chunk)
            notes.append(note)
        }
        return notes.joined(separator: "\n")
    }

    private func summarizeChunk(_ chunk: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Сожми фрагмент стенограммы в краткий конспект на русском.
        Нужно: ключевые факты, боли/возражения, решения, вопросы клиента, договорённости.
        Ответ: только текст, 5-12 пунктов.

        Фрагмент:
        \(chunk)
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Пиши по-русски. Без Markdown."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (responseData, response) = try await session.data(for: request)

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
        return result.choices.first?.message.content ?? ""
    }

    private func splitText(_ text: String, chunkSize: Int) -> [String] {
        if text.count <= chunkSize { return [text] }
        var chunks: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[start..<end]))
            start = end
        }
        return chunks
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a": return "audio/m4a"
        case "wav": return "audio/wav"
        case "caf": return "audio/x-caf"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
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
