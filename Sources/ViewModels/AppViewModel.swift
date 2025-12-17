import Foundation
import SwiftUI
import Combine
import AVFoundation

final class AppViewModel: ObservableObject, @unchecked Sendable {
    @Published var sessions: [Session] = []
    @Published var selectedSession: Session?
    @Published var isSettingsPresented = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var draftTitle: String = ""
    @Published var draftCategory: SessionCategory = .personal
    @Published var hints: [HintItem] = []
    @Published var currentHintIndex: Int = 0
    @Published var engagement: Double = 0.7 // 0..1, влияет на цвет пузыря

    @Published var isRecording: Bool = false
    @Published var isStartingRecording: Bool = false

    @Published var processingStatus: [UUID: String] = [:]
    @Published var processingProgress: [UUID: Double] = [:]
    
    @Published var selectedPlaybook: Playbook = {
        if let saved = UserDefaults.standard.string(forKey: "selectedPlaybook"),
           let playbook = Playbook(rawValue: saved) {
            return playbook
        }
        return .sales
    }() {
        didSet {
            UserDefaults.standard.set(selectedPlaybook.rawValue, forKey: "selectedPlaybook")
        }
    }
    
    @Published var customVocabulary: String = UserDefaults.standard.string(forKey: "customVocabulary") ?? "" {
        didSet {
            UserDefaults.standard.set(customVocabulary, forKey: "customVocabulary")
        }
    }
    
    // Dependencies
    private let persistence = PersistenceService.shared
    let audioRecorder = AudioRecorder()
    private let openAI = OpenAIClient.shared

    
    private var cancellables = Set<AnyCancellable>()

    private var liveTranscriptBuffer: String = ""
    private var liveAnalysisTask: Task<Void, Never>?
    private var isLivePipelineActive: Bool = false
    private var pendingLiveChunks: [URL] = []
    
    init() {
        // Bind sessions from persistence
        persistence.$sessions
            .receive(on: RunLoop.main)
            .assign(to: \.sessions, on: self)
            .store(in: &cancellables)

        // Best-effort: fix legacy sessions that have 0 duration (often due to AVAsset duration not being loaded yet).
        Task { [weak self] in
            await self?.refreshMissingDurationsIfNeeded()
        }

        audioRecorder.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)

        // Подписка на внешние подсказки (для будущих realtime моделей)
        NotificationCenter.default.publisher(for: .newHint)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self else { return }
                let question = note.userInfo?["question"] as? String ?? "Вопрос не распознан"
                let answer = note.userInfo?["answer"] as? String ?? "Попробуйте уточнить детали запроса."
                let engagement = note.userInfo?["engagement"] as? Double
                self.showHint(question: question, answer: answer, engagement: engagement)
            }
            .store(in: &cancellables)
    }

    var hasAPIKey: Bool {
        KeychainService.shared.load() != nil
    }
    
    func startRecording() {
        DispatchQueue.main.async { [weak self] in
            self?.isStartingRecording = true
        }

        // Fast path: permission already granted.
        if audioRecorder.isPermissionGranted {
            do {
                audioRecorder.warmUpEngineIfPossible()
                startLivePipelineIfNeeded()
                _ = try audioRecorder.startRecording()
                DispatchQueue.main.async { [weak self] in
                    self?.isStartingRecording = false
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isStartingRecording = false
                    self?.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                    self?.showError = true
                }
            }
            return
        }

        // Slow path: ask for permission.
        Task {
            if await audioRecorder.requestPermission() {
                do {
                    audioRecorder.warmUpEngineIfPossible()
                    startLivePipelineIfNeeded()
                    _ = try audioRecorder.startRecording()
                    await MainActor.run { self.isStartingRecording = false }
                } catch {
                    await MainActor.run {
                        self.isStartingRecording = false
                        self.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            } else {
                await MainActor.run {
                    self.isStartingRecording = false
                    self.errorMessage = "Microphone permission denied."
                    self.showError = true
                }
            }
        }
    }

    func prewarmRecording() {
        Task {
            if await audioRecorder.requestPermission() {
                audioRecorder.warmUpEngineIfPossible()
            }
        }
    }
    
    func stopRecording() {
        if let result = audioRecorder.stopRecording() {
            let newSession = Session(
                id: UUID(),
                date: Date(),
                duration: result.duration,
                audioFilename: result.filename,
                transcript: nil,
                analysis: nil,
                analysisUpdatedAt: nil,
                analysisSchemaVersion: nil,
                isProcessing: false,
                category: draftCategory,
                customTitle: draftTitle.isEmpty ? nil : draftTitle,
                source: .recording
            )
            persistence.saveSession(newSession)
            // reset drafts
            DispatchQueue.main.async { [weak self] in
                self?.draftTitle = ""
                self?.draftCategory = .personal
            }
            
            // Analysis is manual-only: user triggers it explicitly.
        }

        stopLivePipeline()
    }
    
    func importAudio(from url: URL) {
        Task {
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let originalExt = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
            let newFilename = UUID().uuidString + "." + originalExt
            let destinationURL = documentsPath.appendingPathComponent(newFilename)

            do {
                try fileManager.copyItem(at: url, to: destinationURL)

                let asset = AVURLAsset(url: destinationURL)
                let durationTime = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(durationTime)
                let duration = seconds.isFinite ? seconds : 0

                let detectedSource: SessionSource = inferImportedSource(from: url)
                let importedName = url.deletingPathExtension().lastPathComponent

                let newSession = Session(
                    id: UUID(),
                    date: Date(),
                    duration: duration,
                    audioFilename: newFilename,
                    transcript: nil,
                    analysis: nil,
                    analysisUpdatedAt: nil,
                    analysisSchemaVersion: nil,
                    isProcessing: false,
                    category: draftCategory,
                    customTitle: draftTitle.isEmpty ? nil : draftTitle,
                    importedName: importedName,
                    source: detectedSource
                )

                await MainActor.run { [weak self] in
                    self?.persistence.saveSession(newSession)
                    self?.draftTitle = ""
                    self?.draftCategory = .personal
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Failed to import audio: \(error.localizedDescription)"
                    self?.showError = true
                }
            }
        }
    }

    @MainActor
    private func refreshMissingDurationsIfNeeded() async {
        let candidates = sessions.filter { $0.duration <= 0.01 }
        guard !candidates.isEmpty else { return }

        for s in candidates {
            let audioURL = persistence.getAudioURL(for: s.audioFilename)
            let asset = AVURLAsset(url: audioURL)
            do {
                let durationTime = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(durationTime)
                let duration = seconds.isFinite ? seconds : 0
                guard duration > 0.01 else { continue }
                var updated = s
                updated.duration = duration
                persistence.saveSession(updated)
            } catch {
                // Best-effort only.
                continue
            }
        }
    }

    private func inferImportedSource(from url: URL) -> SessionSource {
        // Heuristic: Voice Memos embedded in Apple Notes often live under the Notes group container.
        // We can’t guarantee this for all setups, so fall back to generic import.
        let path = url.path.lowercased()
        if path.contains("group.com.apple.notes") || path.contains("/notes/") {
            return .notes
        }
        return .importFile
    }

    private func shouldAutoTitle(_ session: Session) -> Bool {
        // Auto-title when user hasn't set a meaningful title.
        // Treat "imported filename" titles as placeholders too.
        guard let tRaw = session.customTitle else { return true }
        let t = tRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        if let imported = session.importedName?.trimmingCharacters(in: .whitespacesAndNewlines), !imported.isEmpty {
            if t.caseInsensitiveCompare(imported) == .orderedSame { return true }
        }
        return false
    }

    private func autoTitle(for session: Session, analysis: Analysis) -> String? {
        // Prefer entities (company/product), then client insights, then summary.
        let company = analysis.extractedEntities?.companies?.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let product = analysis.extractedEntities?.products?.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let insight = analysis.clientInsights?.summary?.trimmingCharacters(in: .whitespacesAndNewlines)

        let candidate: String? = {
            if let company, !company.isEmpty, let product, !product.isEmpty {
                return "\(company) — \(product)"
            }
            if let company, !company.isEmpty {
                return company
            }
            if let product, !product.isEmpty {
                return product
            }
            if let insight, !insight.isEmpty {
                return insight
            }
            return analysis.summary
        }()

        if let s = sanitizeTitle(candidate) {
            return s
        }

        // Fallback: first ~8 words of summary.
        let cleaned = analysis.summary
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return nil }
        return words.prefix(8).joined(separator: " ")
    }

    private func sanitizeTitle(_ raw: String?) -> String? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        s = s.replacingOccurrences(of: "\n", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }

        // Keep it short for UI.
        let maxLen = 64
        if s.count > maxLen {
            let idx = s.index(s.startIndex, offsetBy: maxLen)
            s = String(s[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "—-–:;,."))
        return s.isEmpty ? nil : s
    }

    private func startLivePipelineIfNeeded() {
        guard !isLivePipelineActive else { return }
        isLivePipelineActive = true
        liveTranscriptBuffer = ""
        pendingLiveChunks.removeAll()

        audioRecorder.onChunkReady = { [weak self] chunkURL in
            // AudioRecorder guarantees main queue for this callback today, but keep it
            // MainActor-safe to avoid crashes if that ever changes.
            Task { @MainActor in
                self?.enqueueLiveChunk(url: chunkURL)
            }
        }
    }

    private func stopLivePipeline() {
        isLivePipelineActive = false
        audioRecorder.onChunkReady = nil
        liveAnalysisTask?.cancel()
        liveAnalysisTask = nil
        pendingLiveChunks.removeAll()
    }

    private func enqueueLiveChunk(url: URL) {
        pendingLiveChunks.append(url)
        drainLiveQueueIfNeeded()
    }

    private func drainLiveQueueIfNeeded() {
        guard liveAnalysisTask == nil else { return }
        guard isLivePipelineActive else {
            pendingLiveChunks.removeAll()
            return
        }
        guard !pendingLiveChunks.isEmpty else { return }

        let url = pendingLiveChunks.removeFirst()
        liveAnalysisTask = Task.detached(priority: .utility) { [weak self] in
            defer {
                try? FileManager.default.removeItem(at: url)
                Task { @MainActor in
                    self?.liveAnalysisTask = nil
                    self?.drainLiveQueueIfNeeded()
                }
            }

            guard let self else { return }

            // Gate on main-actor state.
            let shouldRun = await MainActor.run {
                (KeychainService.shared.load() != nil) && self.audioRecorder.isRecording && self.isLivePipelineActive
            }
            guard shouldRun else { return }

            do {
                let piece = try await self.openAI.transcribe(audioURL: url)
                let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }

                let context = await MainActor.run { () -> String in
                    self.liveTranscriptBuffer += "\n" + trimmed
                    if self.liveTranscriptBuffer.count > 2500 {
                        self.liveTranscriptBuffer = String(self.liveTranscriptBuffer.suffix(2500))
                    }
                    return self.liveTranscriptBuffer
                }

                let hint = try await self.openAI.liveHint(context: context)
                let q = hint.question.trimmingCharacters(in: .whitespacesAndNewlines)
                let a = hint.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !(q.isEmpty && a.isEmpty) else { return }

                await MainActor.run {
                    self.showHint(question: q.isEmpty ? "Контекст" : q, answer: a, engagement: hint.engagement)
                }
            } catch {
                // Quietly ignore live errors; don't break recording.
            }
        }
    }

    func saveSession(_ session: Session) {
        persistence.saveSession(session)
    }

    func deleteSession(_ session: Session) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        deleteSessions(at: IndexSet(integer: index))
    }

    func deleteSessions(at offsets: IndexSet) {
        // Check if selected session is being deleted
        offsets.forEach { index in
            if sessions.indices.contains(index) {
                let session = sessions[index]
                if selectedSession == session {
                    selectedSession = nil
                }
            }
        }
        persistence.deleteSession(at: offsets)
    }
    
    func processSession(_ session: Session) {
        guard let current = sessions.first(where: { $0.id == session.id }) else { return }
        // Block repeated launches immediately.
        if current.isProcessing || processingStatus[session.id] != nil { return }
        
        var updatedSession = session
        updatedSession.isProcessing = true
        persistence.saveSession(updatedSession)

        DispatchQueue.main.async { [weak self] in
            self?.processingStatus[session.id] = "Подготовка…"
            self?.processingProgress[session.id] = 0
        }
        
        Task {
            do {
                let audioURL = persistence.getAudioURL(for: session.audioFilename)
                
                // 1. Transcribe
                let transcript = try await openAI.transcribe(audioURL: audioURL) { [weak self] progress, message in
                    DispatchQueue.main.async {
                        self?.processingStatus[session.id] = message
                        self?.processingProgress[session.id] = progress
                    }
                }
                
                // Update with transcript
                updatedSession.transcript = transcript
                // Save intermediate state
                persistence.saveSession(updatedSession)
                
                // 2. Analyze
                DispatchQueue.main.async { [weak self] in
                    self?.processingStatus[session.id] = "Анализ (JSON)…"
                    self?.processingProgress[session.id] = 0.92
                }
                let analysis = try await openAI.analyze(text: transcript, playbook: self.selectedPlaybook, customVocabulary: self.customVocabulary)
                
                updatedSession.analysis = analysis
                updatedSession.analysisUpdatedAt = Date()
                updatedSession.analysisSchemaVersion = OpenAIClient.analysisSchemaVersion

                // Auto-generate a title after analysis (when user didn't set one).
                if self.shouldAutoTitle(updatedSession),
                   let generated = self.autoTitle(for: updatedSession, analysis: analysis) {
                    updatedSession.customTitle = generated
                }

                updatedSession.isProcessing = false
                persistence.saveSession(updatedSession)

                DispatchQueue.main.async { [weak self] in
                    self?.processingStatus[session.id] = nil
                    self?.processingProgress[session.id] = nil
                }
                
            } catch {
                updatedSession.isProcessing = false
                persistence.saveSession(updatedSession)

                DispatchQueue.main.async { [weak self] in
                    self?.processingStatus[session.id] = nil
                    self?.processingProgress[session.id] = nil
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
        }
    }

    func showHint(question: String, answer: String, engagement: Double? = nil) {
        let newHint = HintItem(id: UUID(), question: question, answer: answer, createdAt: Date())
        withAnimation(.spring()) {
            hints.append(newHint)
            if hints.count > 20 { hints.removeFirst() }
            currentHintIndex = max(hints.count - 1, 0)
            if let engagement { updateEngagement(engagement) }
        }
    }

    func clearHints() {
        withAnimation(.easeInOut) {
            hints.removeAll()
            currentHintIndex = 0
            engagement = 0.7
        }
    }

    var currentHint: HintItem? {
        guard hints.indices.contains(currentHintIndex) else { return nil }
        return hints[currentHintIndex]
    }

    func nextHint() {
        guard !hints.isEmpty else { return }
        withAnimation(.easeInOut) {
            currentHintIndex = (currentHintIndex + 1) % hints.count
        }
    }

    func previousHint() {
        guard !hints.isEmpty else { return }
        withAnimation(.easeInOut) {
            currentHintIndex = (currentHintIndex - 1 + hints.count) % hints.count
        }
    }

    func updateEngagement(_ value: Double) {
        engagement = min(1.0, max(0.0, value))
    }
}

struct HintItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let question: String
    let answer: String
    let createdAt: Date
}

extension Notification.Name {
    static let newHint = Notification.Name("com.sonus.hint.new")
}
