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
    /// Bump when the analysis JSON schema / prompts change in a way that should trigger re-analysis.
    static let analysisSchemaVersion: Int = 3
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

    private func dataWithRetry(for request: URLRequest, maxRetries: Int = 3) async throws -> (Data, URLResponse) {
        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse {
                    // Retry transient statuses
                    if [429, 502, 503, 504].contains(http.statusCode), attempt < maxRetries {
                        let base = 0.8 * pow(2.0, Double(attempt))
                        let jitter = Double.random(in: 0...0.25)
                        try await Task.sleep(nanoseconds: UInt64((base + jitter) * 1_000_000_000))
                        attempt += 1
                        continue
                    }
                }
                return (data, response)
            } catch {
                lastError = error
                if attempt >= maxRetries { break }
                let base = 0.6 * pow(2.0, Double(attempt))
                let jitter = Double.random(in: 0...0.25)
                try await Task.sleep(nanoseconds: UInt64((base + jitter) * 1_000_000_000))
                attempt += 1
            }
        }

        throw OpenAIError.networkError(lastError ?? URLError(.cannotConnectToHost))
    }

    func validateAPIKey() async throws -> Bool {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let url = URL(string: "\(baseURL)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (responseData, response) = try await dataWithRetry(for: request, maxRetries: 1)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.networkError(URLError(.badServerResponse))
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            return false
        }
        if !(200...299).contains(http.statusCode) {
            if let errorJson = try? JSONDecoder().decode(APIErrorResponse.self, from: responseData) {
                throw OpenAIError.apiError(errorJson.error.message)
            }
            throw OpenAIError.apiError("Status code: \(http.statusCode)")
        }
        return true
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

    struct LiveHintResponse: Codable {
        let question: String
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
        let (responseData, response) = try await dataWithRetry(for: request)

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

    func liveHint(context: String) async throws -> LiveHintResponse {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Ты — ассистент продавца во время звонка. На основе последнего контекста диалога:
        1) Выдели самый важный вопрос/возражение клиента (если его нет — сформулируй как краткое описание текущего сомнения/темы).
        2) Предложи краткий, конкретный ответ/следующую фразу продавца.
        3) Оцени вовлечённость клиента 0..1.

        Правила:
        - Не выдумывай факты, опирайся только на контекст.
        - Ответ максимально практичный и короткий.

        Верни строго JSON:
        {"question":"...","answer":"...","engagement":0.0}

        Контекст:
        \(context)
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
        let (responseData, response) = try await dataWithRetry(for: request)

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

        return try JSONDecoder().decode(LiveHintResponse.self, from: data)
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
                - commitments: массив объектов {title, owner, dueDateISO, notes, confidence}
                    (это именно обещания/договорённости: "я пришлю", "мы покажем", "вышлем КП", "сделаем демо" и т.п.)
                - conversationMetrics: объект {
                        talkTimeShare: словарь {"sales":0..100, "client":0..100} (если можно оценить),
                        interruptionsCount: число,
                        questionCount: число,
                        monologueLongestSeconds: число,
                        sentimentTrend: "improving"|"worsening"|"stable"|"mixed",
                        riskFlags: массив строк
                    }

                - speakerInsights: массив объектов {
                        name: строка (имя/ярлык говорящего из текста, например "Иван" или "Клиент"),
                        role: строка|null,
                        activityScore: 0..100|null,
                        competenceScore: 0..100|null,
                        emotionControlScore: 0..100|null,
                        conflictHandlingScore: 0..100|null,
                        ideasAndProposals: массив строк,
                        strengths: массив строк,
                        risks: массив строк,
                        evidenceQuotes: массив коротких цитат (до 6) из текста
                    }
                    Правила:
                    - НЕ выдумывай цитаты.
                    - Если нет явных говорящих — верни пустой массив.
                    - Не больше 8 объектов.

                Стенограмма:
                \(condensed)
                """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini", // or gpt-3.5-turbo
            "messages": [
                ["role": "system", "content": "Ты аналитик переговоров. Отвечай на русском. Возвращай только JSON."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.2
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        request.timeoutInterval = 180

        let (responseData, response) = try await dataWithRetry(for: request)
        
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
            var analysis = try JSONDecoder().decode(Analysis.self, from: data)

            // Post-process to reduce "empty" results on huge transcripts.
            analysis = analysisNormalized(analysis)

            // If the model returned null/empty summary on a long transcript, do a cheap targeted pass.
            if analysis.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let improved = try? await generateSummaryOnly(from: condensed) {
                    analysis.summary = improved
                }
            }

            // If reminders are empty, try a targeted extraction from condensed notes.
            if analysis.commitments.isEmpty && analysis.actionItems.isEmpty {
                if let reminders = try? await extractRemindersOnly(from: condensed) {
                    if analysis.commitments.isEmpty { analysis.commitments = reminders.commitments }
                    if analysis.actionItems.isEmpty { analysis.actionItems = reminders.actionItems }
                }
            }

            // Normalize again in case new reminders added participants/entities.
            analysis = analysisNormalized(analysis)
            return analysis
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "<no-body>"
            throw OpenAIError.decodingError(NSError(domain: "OpenAIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Decode failed: \(error.localizedDescription). Body: \(bodyString)"]))
        }
    }

    // MARK: - Long transcript helpers

    private struct ChunkSignals: Codable {
        var participants: [String]?
        var languages: [String]?
        var keyFacts: [String]?
        var commitments: [ChunkCommitment]?
        var actionItems: [ChunkActionItem]?
        var extractedEntities: ExtractedEntities?
    }

    private struct ChunkCommitment: Codable {
        var title: String?
        var owner: String?
        var dueDateISO: String?
        var notes: String?
        var confidence: Int?
    }

    private struct ChunkActionItem: Codable {
        var title: String?
        var owner: String?
        var dueDateISO: String?
        var priority: String?
        var notes: String?
    }

    private struct RemindersOnlyResponse: Codable {
        var commitments: [ChunkCommitment]?
        var actionItems: [ChunkActionItem]?
    }

    private func condensedTranscriptIfNeeded(_ text: String) async throws -> String {
        // For very long conversations, direct JSON analysis often gets sparse.
        // We build a condensed, structured "signal summary" to preserve names, commitments, and entities.
        if text.count <= 12_000 { return text }

        let chunks = splitText(text, chunkSize: 16_000)

        // Protect against massive costs on multi-hour transcripts.
        let maxExtractionChunks = 24
        let selected = selectChunkIndices(total: chunks.count, max: maxExtractionChunks)

        var notes: [String] = []
        notes.reserveCapacity(selected.count)

        for idx in selected {
            let chunk = chunks[idx]
            let signals = try await extractChunkSignals(chunk)
            notes.append(renderSignals(signals, chunkIndex: idx + 1, chunkCount: chunks.count))
        }

        let combined = notes.joined(separator: "\n")
        // Keep it bounded so the final analysis call remains stable.
        if combined.count <= 30_000 { return combined }
        return String(combined.suffix(30_000))
    }

    private func selectChunkIndices(total: Int, max maxCount: Int) -> [Int] {
        guard total > 0 else { return [] }
        if total <= maxCount { return Array(0..<total) }

        let step = max(1, Int(ceil(Double(total) / Double(maxCount))))
        var indices: [Int] = Array(stride(from: 0, to: total, by: step))

        if indices.first != 0 { indices.insert(0, at: 0) }
        if indices.last != total - 1 { indices.append(total - 1) }

        // De-dup, keep order
        var seen = Set<Int>()
        var out: [Int] = []
        out.reserveCapacity(indices.count)
        for i in indices {
            if seen.insert(i).inserted { out.append(i) }
        }
        // Trim if still too many
        if out.count > maxCount { out = Array(out.prefix(maxCount)) }
        return out
    }

    private func extractChunkSignals(_ chunk: String) async throws -> ChunkSignals {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Ты извлекаешь сигналы из ФРАГМЕНТА стенограммы. Верни строго JSON (без Markdown).

        Цели:
        - Сохранить имена/роли участников (если встречаются в тексте).
        - Сохранить обещания/договорённости и задачи.
        - Сохранить сущности (компании/люди/продукты/ссылки/контакты/даты).

        Правила:
        - Не выдумывай: извлекай только явно сказанное.
        - Если данных нет — пустые массивы/null.

        Верни JSON со структурой:
        {
          "participants": ["..."],
          "languages": ["..."],
          "keyFacts": ["..."],
          "commitments": [{"title":"...","owner":"...","dueDateISO":"YYYY-MM-DD","notes":"...","confidence":0}],
          "actionItems": [{"title":"...","owner":"...","dueDateISO":"YYYY-MM-DD","priority":"low|medium|high","notes":"..."}],
          "extractedEntities": {
            "companies":["..."],"people":["..."],"products":["..."],"locations":["..."],
            "urls":["..."],"emails":["..."],"phones":["..."],
            "dateMentions":[{"text":"...","isoDate":"YYYY-MM-DD","context":"..."}]
          }
        }

        Фрагмент:
        \(chunk)
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Отвечай по-русски. Верни только JSON."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (responseData, response) = try await dataWithRetry(for: request)

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
        return try JSONDecoder().decode(ChunkSignals.self, from: data)
    }

    private func renderSignals(_ s: ChunkSignals, chunkIndex: Int, chunkCount: Int) -> String {
        var lines: [String] = []
        lines.append("[Chunk \(chunkIndex)/\(chunkCount)]")
        if let participants = s.participants, !participants.isEmpty {
            lines.append("participants: \(participants.prefix(12).joined(separator: ", "))")
        }
        if let languages = s.languages, !languages.isEmpty {
            lines.append("languages: \(languages.prefix(6).joined(separator: ", "))")
        }
        if let facts = s.keyFacts, !facts.isEmpty {
            lines.append("facts:")
            for f in facts.prefix(12) { lines.append("- \(f)") }
        }
        if let commitments = s.commitments, !commitments.isEmpty {
            lines.append("commitments:")
            for c in commitments.prefix(10) {
                let t = (c.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { continue }
                let owner = (c.owner ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let due = (c.dueDateISO ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                lines.append("- \(t)\(owner.isEmpty ? "" : " [\(owner)]")\(due.isEmpty ? "" : " (\(due))")")
            }
        }
        if let items = s.actionItems, !items.isEmpty {
            lines.append("actionItems:")
            for it in items.prefix(12) {
                let t = (it.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty { continue }
                let owner = (it.owner ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let due = (it.dueDateISO ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                lines.append("- \(t)\(owner.isEmpty ? "" : " [\(owner)]")\(due.isEmpty ? "" : " (\(due))")")
            }
        }
        if let e = s.extractedEntities {
            var entityLines: [String] = []
            if let companies = e.companies, !companies.isEmpty { entityLines.append("companies: \(companies.prefix(8).joined(separator: ", "))") }
            if let people = e.people, !people.isEmpty { entityLines.append("people: \(people.prefix(10).joined(separator: ", "))") }
            if let products = e.products, !products.isEmpty { entityLines.append("products: \(products.prefix(8).joined(separator: ", "))") }
            if !entityLines.isEmpty {
                lines.append("entities:")
                lines.append(contentsOf: entityLines.map { "- \($0)" })
            }
        }
        return lines.joined(separator: "\n")
    }

    private func generateSummaryOnly(from condensed: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        На основе заметок/сигналов разговора напиши краткое резюме на русском (3-6 предложений).
        Не выдумывай факты. Если данных мало — честно скажи, что удалось понять.

        Заметки:
        \(condensed)
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
        let (responseData, response) = try await dataWithRetry(for: request, maxRetries: 2)

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
        return (result.choices.first?.message.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractRemindersOnly(from condensed: String) async throws -> (commitments: [Commitment], actionItems: [ActionItem]) {
        guard let apiKey = apiKey, !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 75
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Извлеки из заметок разговора:
        1) commitments — обещания/договорённости ("я пришлю", "мы покажем", "вышлем КП", "сделаем демо").
        2) actionItems — задачи/следующие шаги.

        Верни строго JSON:
        {"commitments":[{"title":"...","owner":"...","dueDateISO":"YYYY-MM-DD","notes":"...","confidence":0}],
         "actionItems":[{"title":"...","owner":"...","dueDateISO":"YYYY-MM-DD","priority":"low|medium|high","notes":"..."}]}

        Если ничего нет — пустые массивы.

        Заметки:
        \(condensed)
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Отвечай на русском. Верни только JSON."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (responseData, response) = try await dataWithRetry(for: request, maxRetries: 2)

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

        let parsed = try JSONDecoder().decode(RemindersOnlyResponse.self, from: data)
        let commitments: [Commitment] = (parsed.commitments ?? [])
            .compactMap { c in
                let t = (c.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                return Commitment(title: t, owner: c.owner, dueDateISO: c.dueDateISO, notes: c.notes, confidence: c.confidence)
            }
        let actionItems: [ActionItem] = (parsed.actionItems ?? [])
            .compactMap { it in
                let t = (it.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                return ActionItem(title: t, owner: it.owner, dueDateISO: it.dueDateISO, priority: it.priority, notes: it.notes)
            }

        return (commitments: commitments, actionItems: actionItems)
    }

    private func analysisNormalized(_ analysis: Analysis) -> Analysis {
        var a = analysis

        // Participants: fall back to extracted profiles/entities.
        if a.participants.isEmpty {
            var people: [String] = []
            if let client = a.client {
                if let name = client.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    people.append(name)
                } else if let label = client.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    people.append(label)
                }
            }
            if let others = a.otherParticipants {
                for p in others {
                    if let name = p.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        people.append(name)
                    } else if let label = p.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        people.append(label)
                    }
                }
            }
            if let ents = a.extractedEntities, let names = ents.people {
                people.append(contentsOf: names)
            }

            let cleaned = people
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // De-dupe preserving order (case-insensitive)
            var seen = Set<String>()
            var uniq: [String] = []
            for p in cleaned {
                let key = p.lowercased()
                if seen.insert(key).inserted { uniq.append(p) }
            }
            a.participants = uniq
        }

        // Speaker count: derive if missing.
        if a.speakerCount == nil {
            if a.participants.count >= 2 {
                a.speakerCount = a.participants.count
            } else if let others = a.otherParticipants {
                let n = (a.client == nil ? 0 : 1) + others.count
                if n >= 2 { a.speakerCount = n }
            }
        }

        return a
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

        let (responseData, response) = try await dataWithRetry(for: request)
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

    // NOTE: previous plain-text summarization removed a lot of detail for multi-hour recordings.
    // Replaced by structured signal extraction in the helper above.

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
