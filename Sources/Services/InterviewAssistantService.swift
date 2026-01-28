import Foundation
import AVFoundation

/// Сервис для помощи в англоязычном интервью:
/// - Реал-тайм транскрибация речи собеседника
/// - Перевод на русский
/// - Автоматические подсказки после пауз/вопросов
final class InterviewAssistantService: ObservableObject {
    static let shared = InterviewAssistantService()
    
    @Published var isActive = false
    @Published var currentEnglishText = ""
    @Published var currentRussianTranslation = ""
    @Published var suggestedResponse = ""
    @Published var confidenceLevel: Double = 0
    @Published var dialogueHistory: [DialogueEntry] = []
    
    // Настройки (можно менять)
    var pauseThreshold: TimeInterval = 2.5 // Секунд паузы перед подсказкой
    var chunkProcessingInterval: TimeInterval = 4.0 // Минимальный интервал между обработкой чанков
    
    struct DialogueEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let speaker: Speaker
        let englishText: String
        let russianTranslation: String
        
        enum Speaker {
            case interviewer // Собеседник
            case user // Вы
        }
    }
    
    // Используем отдельный экземпляр AudioRecorder для Interview Assistant
    private let audioRecorder = AudioRecorder()
    private let openAI = OpenAIClient.shared
    
    private var conversationContext: [String] = []
    private var transcriptionTask: Task<Void, Never>?
    private var lastChunkProcessedAt = Date.distantPast
    private var accumulatedTranscript = ""
    private var fullRecordingFilename: String?
    
    private var lastSpeechTime = Date()
    private var hintCheckTimer: Timer?
    private var lastProcessedText = "" // Для избежания дублирования
    
    private init() {}
    
    /// Запустить режим помощника интервью
    @MainActor
    func start() async throws {
        guard !isActive else { return }
        
        // Проверка разрешения микрофона
        if !audioRecorder.isPermissionGranted {
            let granted = await audioRecorder.requestPermission()
            guard granted else {
                throw InterviewAssistantError.microphonePermissionDenied
            }
        }
        
        // Очистка состояния
        currentEnglishText = ""
        currentRussianTranslation = ""
        suggestedResponse = ""
        conversationContext.removeAll()
        accumulatedTranscript = ""
        dialogueHistory.removeAll()
        lastSpeechTime = Date()
        lastProcessedText = ""
        fullRecordingFilename = nil
        
        // Подключение обработчика чанков
        audioRecorder.onChunkReady = { [weak self] chunkURL in
            self?.processAudioChunk(chunkURL)
        }
        
        // Запуск записи с обработкой ошибок
        do {
            audioRecorder.warmUpEngineIfPossible()
            let filename = try audioRecorder.startRecording()
            fullRecordingFilename = filename
            
            isActive = true
            
            // Запуск таймера для проверки пауз
            startHintCheckTimer()
            
            print("✅ Interview Assistant режим активирован")
        } catch {
            // Если произошла ошибка, очищаем состояние
            audioRecorder.onChunkReady = nil
            isActive = false
            throw error
        }
    }
    
    /// Остановить режим помощника
    @MainActor
    func stop() async -> (filename: String, duration: TimeInterval, transcript: String)? {
        guard isActive else { return nil }
        
        audioRecorder.onChunkReady = nil
        let recordingResult = audioRecorder.stopRecording()
        
        hintCheckTimer?.invalidate()
        hintCheckTimer = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        
        isActive = false
        
        // Собираем полную транскрипцию
        let fullTranscript = dialogueHistory.map { entry in
            let speaker = entry.speaker == .interviewer ? "Interviewer" : "You"
            return "[\(speaker)]: \(entry.englishText)\n[Translation]: \(entry.russianTranslation)"
        }.joined(separator: "\n\n")
        
        print("⏹ Interview Assistant режим остановлен")
        
        if let result = recordingResult {
            return (filename: result.filename, duration: result.duration, transcript: fullTranscript)
        }
        return nil
    }
    
    private func startHintCheckTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.hintCheckTimer?.invalidate()
            self?.hintCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkForPauseAndGenerateHint()
            }
        }
    }
    
    private func checkForPauseAndGenerateHint() {
        let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeechTime)
        
        // Если прошло достаточно времени с последней речи и есть новый контекст
        guard timeSinceLastSpeech >= pauseThreshold,
              !accumulatedTranscript.isEmpty,
              !currentEnglishText.isEmpty else {
            return
        }
        
        // Сбросим таймер чтобы не генерировать подсказки постоянно
        lastSpeechTime = Date()
        
        // Генерация подсказки
        Task {
            await generateResponseHint()
        }
    }
    
    private func processAudioChunk(_ chunkURL: URL) {
        // Избегаем перегрузки - обрабатываем не чаще раза в N секунд
        let now = Date()
        guard now.timeIntervalSince(lastChunkProcessedAt) >= chunkProcessingInterval else {
            return
        }
        lastChunkProcessedAt = now
        
        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            await self?.transcribeAndTranslateChunk(chunkURL)
        }
    }
    
    private func transcribeAndTranslateChunk(_ chunkURL: URL) async {
        // Проверка уровня звука - отсекаем тишину/фон
        guard audioRecorder.hasSignificantAudio(at: chunkURL, threshold: 0.015) else {
            print("⏩ Чанк пропущен: слишком тихо или только фон")
            try? FileManager.default.removeItem(at: chunkURL)
            return
        }
        
        do {
            // 1. Транскрибация аудио чанка
            let englishText = try await openAI.transcribe(audioURL: chunkURL)
            
            // Фильтрация пустых результатов
            let cleaned = englishText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, cleaned.count > 3 else {
                print("⏩ Чанк пропущен: пустой транскрипт")
                try? FileManager.default.removeItem(at: chunkURL)
                return
            }
            
            print("✅ Реальная речь: \(cleaned)")
            
            print("✅ Реальная речь: \(cleaned)")
            
            // Обновление времени последней речи
            lastSpeechTime = Date()
            
            // 2. Определяем кто говорит (базовая эвристика)
            let speaker: DialogueEntry.Speaker = determineSpeaker(cleaned)
            
            // 3. Перевод на русский
            let russianTranslation = try await translateToRussian(cleaned)
            
            // 4. Обновление UI
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                // Проверяем что это не дубликат
                if self.lastProcessedText == cleaned {
                    return
                }
                self.lastProcessedText = cleaned
                
                self.currentEnglishText = cleaned
                self.currentRussianTranslation = russianTranslation
                
                // Добавляем в историю диалога
                let entry = DialogueEntry(
                    timestamp: Date(),
                    speaker: speaker,
                    englishText: cleaned,
                    russianTranslation: russianTranslation
                )
                self.dialogueHistory.append(entry)
                
                // Добавление в контекст только реплик собеседника для подсказок
                if speaker == .interviewer {
                    self.conversationContext.append("Interviewer: \(englishText)\nTranslation: \(russianTranslation)")
                    if self.conversationContext.count > 8 {
                        self.conversationContext.removeFirst()
                    }
                }
                
                self.accumulatedTranscript += "\n[\(speaker == .interviewer ? "Interviewer" : "You")]: \(englishText)"
            }
            
            print("📝 Транскрибировано: \(englishText)")
            print("🔄 Перевод: \(russianTranslation)")
            
            // Очистка временного файла
            try? FileManager.default.removeItem(at: chunkURL)
            
        } catch {
            print("❌ Ошибка обработки чанка: \(error.localizedDescription)")
        }
    }
    
    private func translateToRussian(_ englishText: String) async throws -> String {
        // Используем GPT для перевода с сохранением контекста интервью
        let prompt = """
        Переведи следующий текст с английского на русский. 
        Это фрагмент собеседования/интервью, переводи естественно и понятно.
        Верни только перевод без дополнительных комментариев.
        
        Текст: \(englishText)
        """
        
        let response = try await openAI.chatCompletion(
            messages: [
                ["role": "system", "content": "Ты профессиональный переводчик с английского на русский."],
                ["role": "user", "content": prompt]
            ],
            temperature: 0.3
        )
        
        return response
    }
    
    @MainActor
    private func generateResponseHint() async {
        guard !conversationContext.isEmpty else { return }
        
        do {
            // Формируем контекст последних реплик
            let contextText = conversationContext.suffix(5).joined(separator: "\n\n")
            
            let prompt = """
            Ты помогаешь человеку на собеседовании на английском языке.
            Контекст разговора (на английском с переводом на русский):
            
            \(contextText)
            
            Последний вопрос/высказывание собеседника:
            \(currentEnglishText)
            
            Предложи краткий и естественный ответ на английском языке.
            Также оцени сложность вопроса от 0 до 1 (0 = простой вопрос, 1 = сложный вопрос).
            
            Верни JSON формата:
            {
              "suggested_response": "краткий ответ на английском",
              "confidence": 0.0-1.0
            }
            """
            
            let jsonResponse = try await openAI.chatCompletionJSON(
                messages: [
                    ["role": "system", "content": "Ты помощник для собеседований. Отвечай кратко и по делу. Возвращай только JSON."],
                    ["role": "user", "content": prompt]
                ],
                temperature: 0.6
            )
            
            if let data = jsonResponse.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(HintResponse.self, from: data) {
                await MainActor.run {
                    self.suggestedResponse = decoded.suggested_response
                    self.confidenceLevel = 1.0 - decoded.confidence // Инвертируем для отображения
                }
                
                print("💡 Подсказка: \(decoded.suggested_response)")
            }
            
        } catch {
            print("❌ Ошибка генерации подсказки: \(error.localizedDescription)")
        }
    }
    
    /// Простая эвристика для определения кто говорит
    /// В будущем можно улучшить с помощью анализа голоса или ML
    private func determineSpeaker(_ text: String) -> DialogueEntry.Speaker {
        // Если после нашей подсказки прошло мало времени и есть похожие слова - скорее всего говорим мы
        let timeSinceSuggestion = Date().timeIntervalSince(lastSpeechTime)
        
        // Простая эвристика: если подсказка была недавно (< 10 сек) и текст короткий - возможно это мы
        if !suggestedResponse.isEmpty && timeSinceSuggestion < 10 {
            // Проверяем схожесть с подсказкой
            let suggestionWords = Set(suggestedResponse.lowercased().split(separator: " ").map(String.init))
            let textWords = Set(text.lowercased().split(separator: " ").map(String.init))
            let commonWords = suggestionWords.intersection(textWords)
            
            // Если есть общие слова и текст не слишком длинный - возможно это мы отвечаем
            if commonWords.count >= 2 && text.split(separator: " ").count < 30 {
                return .user
            }
        }
        
        // По умолчанию считаем что говорит собеседник (интервьюер)
        // TODO: В будущем можно добавить анализ голоса или паттернов речи
        return .interviewer
    }
    
    struct HintResponse: Codable {
        let suggested_response: String
        let confidence: Double
    }
}

enum InterviewAssistantError: Error, LocalizedError {
    case microphonePermissionDenied
    case transcriptionFailed
    case translationFailed
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Доступ к микрофону запрещен"
        case .transcriptionFailed:
            return "Ошибка транскрибации"
        case .translationFailed:
            return "Ошибка перевода"
        }
    }
}
