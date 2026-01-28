import Foundation
import AVFoundation
import Combine

/// Универсальный AI ассистент для любых разговоров в реальном времени
/// - Транскрибация на любом языке
/// - Перевод на выбранный язык
/// - Анализ вовлеченности собеседника
/// - Подсказки и рекомендации
final class RealTimeAssistantService: ObservableObject {
    static let shared = RealTimeAssistantService()
    
    @Published var isActive = false
    @Published var currentTranscript = ""
    @Published var translation = ""
    @Published var suggestion = ""
    @Published var engagement = EngagementLevel.neutral
    @Published var engagementScore: Double = 0.5 // 0.0 - 1.0
    @Published var conversationHistory: [ConversationEntry] = []
    
    // Настройки
    var targetLanguage: AssistantLanguage = .russian
    var assistantMode: AssistantMode = .translation
    var autoSuggest = true
    var pauseThreshold: TimeInterval = 2.0
    
    enum AssistantLanguage: String, CaseIterable, Identifiable {
        case russian = "ru"
        case english = "en"
        case ukrainian = "uk"
        case german = "de"
        case french = "fr"
        case spanish = "es"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .russian: return "Русский"
            case .english: return "English"
            case .ukrainian: return "Українська"
            case .german: return "Deutsch"
            case .french: return "Français"
            case .spanish: return "Español"
            }
        }
    }
    
    enum AssistantMode: String, CaseIterable, Identifiable {
        case translation = "translation"
        case coaching = "coaching"
        case notes = "notes"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .translation: return "Перевод и подсказки"
            case .coaching: return "Коучинг и рекомендации"
            case .notes: return "Заметки и ключевые моменты"
            }
        }
        
        var icon: String {
            switch self {
            case .translation: return "translate"
            case .coaching: return "person.fill.checkmark"
            case .notes: return "note.text"
            }
        }
    }
    
    enum EngagementLevel {
        case high      // 0.7 - 1.0
        case neutral   // 0.4 - 0.7
        case low       // 0.0 - 0.4
        
        var color: String {
            switch self {
            case .high: return "green"
            case .neutral: return "yellow"
            case .low: return "red"
            }
        }
        
        var emoji: String {
            switch self {
            case .high: return "😊"
            case .neutral: return "😐"
            case .low: return "😟"
            }
        }
        
        var description: String {
            switch self {
            case .high: return "Высокая вовлечённость"
            case .neutral: return "Нормальная вовлечённость"
            case .low: return "Низкая вовлечённость"
            }
        }
    }
    
    struct ConversationEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let originalText: String
        let translatedText: String
        let detectedLanguage: String
        let engagementScore: Double
    }
    
    private let audioRecorder = AudioRecorder()
    private let openAI = OpenAIClient.shared
    private var lastChunkProcessedAt = Date.distantPast
    private var fullRecordingFilename: String?
    private var chunkProcessingTask: Task<Void, Never>?
    
    // Для анализа вовлечённости
    private var recentTranscripts: [String] = []
    private var lastEngagementCheck = Date()
    private var sentimentHistory: [Double] = []
    
    private init() {
        // Загрузка настроек
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func start() async throws {
        guard !isActive else { return }
        
        // Проверка разрешения
        if !audioRecorder.isPermissionGranted {
            let granted = await audioRecorder.requestPermission()
            guard granted else {
                throw AssistantError.microphonePermissionDenied
            }
        }
        
        // Очистка состояния
        currentTranscript = ""
        translation = ""
        suggestion = ""
        conversationHistory.removeAll()
        recentTranscripts.removeAll()
        sentimentHistory.removeAll()
        engagementScore = 0.5
        engagement = .neutral
        
        // Подключение обработчика чанков
        audioRecorder.onChunkReady = { [weak self] chunkURL in
            self?.processAudioChunk(chunkURL)
        }
        
        // Запуск записи
        do {
            audioRecorder.warmUpEngineIfPossible()
            let filename = try audioRecorder.startRecording()
            fullRecordingFilename = filename
            isActive = true
            
            print("✅ AI Assistant активирован в режиме: \(assistantMode.displayName)")
            print("📝 Целевой язык: \(targetLanguage.displayName)")
        } catch {
            audioRecorder.onChunkReady = nil
            isActive = false
            throw error
        }
    }
    
    @MainActor
    func stop() async -> (filename: String, duration: TimeInterval, transcript: String)? {
        guard isActive else { return nil }
        
        audioRecorder.onChunkReady = nil
        chunkProcessingTask?.cancel()
        
        guard let result = audioRecorder.stopRecording() else {
            isActive = false
            return nil
        }
        
        isActive = false
        
        // Формируем полную транскрипцию
        let fullTranscript = conversationHistory.map { entry in
            "[\(formatTime(entry.timestamp))] \(entry.originalText)"
        }.joined(separator: "\n")
        
        print("✅ AI Assistant остановлен")
        return (result.filename, result.duration, fullTranscript)
    }
    
    func updateEngagement(_ score: Double) {
        engagementScore = max(0, min(1, score))
        
        engagement = if engagementScore >= 0.7 {
            .high
        } else if engagementScore >= 0.4 {
            .neutral
        } else {
            .low
        }
    }
    
    // MARK: - Private Methods
    
    private func processAudioChunk(_ chunkURL: URL) {
        // Минимальный интервал между обработкой чанков
        let now = Date()
        guard now.timeIntervalSince(lastChunkProcessedAt) >= 3.0 else { return }
        lastChunkProcessedAt = now
        
        chunkProcessingTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // 1. Транскрибация
                let transcript = try await self.openAI.transcribe(audioURL: chunkURL)
                
                guard !transcript.isEmpty, !Task.isCancelled else { return }
                
                // 2. Перевод на целевой язык
                let translated = try await self.translateText(transcript)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.currentTranscript = transcript
                    self.translation = translated
                    
                    // Добавляем в историю
                    let entry = ConversationEntry(
                        timestamp: Date(),
                        originalText: transcript,
                        translatedText: translated,
                        detectedLanguage: "auto",
                        engagementScore: self.engagementScore
                    )
                    self.conversationHistory.append(entry)
                    
                    // Добавляем в буфер для анализа
                    self.recentTranscripts.append(transcript)
                    if self.recentTranscripts.count > 5 {
                        self.recentTranscripts.removeFirst()
                    }
                }
                
                // 3. Анализ вовлечённости
                if now.timeIntervalSince(self.lastEngagementCheck) >= 5.0 {
                    await self.analyzeEngagement(transcript: transcript)
                    self.lastEngagementCheck = now
                }
                
                // 4. Генерация подсказки
                if self.autoSuggest {
                    try await self.generateSuggestion(transcript: transcript, translation: translated)
                }
                
            } catch {
                print("❌ Ошибка обработки чанка: \(error)")
            }
        }
    }
    
    private func translateText(_ text: String) async throws -> String {
        let prompt = """
        Translate the following text to \(targetLanguage.displayName).
        Keep it natural and conversational.
        Text: \(text)
        """
        
        let response = try await openAI.chatCompletion(messages: [
            ["role": "system", "content": "You are a professional translator. Provide only the translation, no explanations."],
            ["role": "user", "content": prompt]
        ])
        
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func analyzeEngagement(transcript: String) async {
        let allText = recentTranscripts.joined(separator: " ")
        
        let prompt = """
        Analyze the engagement level of this conversation based on the transcript.
        Consider: enthusiasm, question frequency, response length, emotional tone.
        
        Recent conversation:
        \(allText)
        
        Return ONLY a number between 0.0 (low engagement) and 1.0 (high engagement).
        """
        
        do {
            let response = try await openAI.chatCompletion(messages: [
                ["role": "system", "content": "You are an expert in conversation analysis. Return only a decimal number."],
                ["role": "user", "content": prompt]
            ])
            
            if let score = Double(response.trimmingCharacters(in: .whitespacesAndNewlines)) {
                await MainActor.run {
                    self.updateEngagement(score)
                    self.sentimentHistory.append(score)
                    if self.sentimentHistory.count > 10 {
                        self.sentimentHistory.removeFirst()
                    }
                }
            }
        } catch {
            print("❌ Ошибка анализа вовлечённости: \(error)")
        }
    }
    
    private func generateSuggestion(transcript: String, translation: String) async throws {
        let modeContext = switch assistantMode {
        case .translation:
            "Suggest how to respond naturally in the same language as the conversation."
        case .coaching:
            "Provide coaching advice on how to improve the conversation and maintain engagement."
        case .notes:
            "Extract and highlight key points and action items."
        }
        
        let engagementContext = if engagement == .low {
            "\n\nIMPORTANT: Engagement is LOW. Suggest ways to re-engage the person."
        } else {
            ""
        }
        
        let prompt = """
        Mode: \(assistantMode.displayName)
        Conversation: \(transcript)
        Translation: \(translation)
        \(modeContext)\(engagementContext)
        
        Provide a brief, actionable suggestion in Russian.
        """
        
        let response = try await openAI.chatCompletion(messages: [
            ["role": "system", "content": "You are a helpful conversation assistant."],
            ["role": "user", "content": prompt]
        ])
        
        await MainActor.run {
            self.suggestion = response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        if let langCode = UserDefaults.standard.string(forKey: "assistant.targetLanguage"),
           let lang = AssistantLanguage(rawValue: langCode) {
            targetLanguage = lang
        }
        
        if let modeCode = UserDefaults.standard.string(forKey: "assistant.mode"),
           let mode = AssistantMode(rawValue: modeCode) {
            assistantMode = mode
        }
        
        autoSuggest = UserDefaults.standard.object(forKey: "assistant.autoSuggest") as? Bool ?? true
    }
    
    func saveSettings() {
        UserDefaults.standard.set(targetLanguage.rawValue, forKey: "assistant.targetLanguage")
        UserDefaults.standard.set(assistantMode.rawValue, forKey: "assistant.mode")
        UserDefaults.standard.set(autoSuggest, forKey: "assistant.autoSuggest")
    }
}

enum AssistantError: LocalizedError {
    case microphonePermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Необходим доступ к микрофону для работы AI ассистента"
        }
    }
}
