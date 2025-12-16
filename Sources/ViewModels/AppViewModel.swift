import Foundation
import SwiftUI
import Combine

@MainActor
class AppViewModel: ObservableObject {
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

    @Published var processingStatus: [UUID: String] = [:]
    @Published var processingProgress: [UUID: Double] = [:]
    
    // Dependencies
    private let persistence = PersistenceService.shared
    let audioRecorder = AudioRecorder()
    private let openAI = OpenAIClient.shared

    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Bind sessions from persistence
        persistence.$sessions
            .assign(to: \.sessions, on: self)
            .store(in: &cancellables)

        // Подписка на внешние подсказки (для будущих realtime моделей)
        NotificationCenter.default.publisher(for: .newHint)
            .sink { [weak self] note in
                guard let self else { return }
                let question = note.userInfo?["question"] as? String ?? "Вопрос не распознан"
                let answer = note.userInfo?["answer"] as? String ?? "Попробуйте уточнить детали запроса."
                let engagement = note.userInfo?["engagement"] as? Double
                self.showHint(question: question, answer: answer, engagement: engagement)
            }
            .store(in: &cancellables)
    }
    
    func startRecording() {
        Task {
            if await audioRecorder.requestPermission() {
                do {
                    _ = try audioRecorder.startRecording()
                } catch {
                    self.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                    self.showError = true
                }
            } else {
                self.errorMessage = "Microphone permission denied."
                self.showError = true
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
                isProcessing: false,
                category: draftCategory,
                customTitle: draftTitle.isEmpty ? nil : draftTitle
            )
            persistence.saveSession(newSession)
            // reset drafts
            draftTitle = ""
            draftCategory = .personal
            
            // Auto-process if key exists? Maybe optional.
            // For now, user manually triggers or we trigger if key is present.
            if KeychainService.shared.load() != nil {
                processSession(newSession)
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
        guard sessions.contains(where: { $0.id == session.id }) else { return }
        
        var updatedSession = session
        updatedSession.isProcessing = true
        persistence.saveSession(updatedSession)

        processingStatus[session.id] = "Подготовка…"
        processingProgress[session.id] = 0
        
        Task {
            do {
                let audioURL = persistence.getAudioURL(for: session.audioFilename)
                
                // 1. Transcribe
                let transcript = try await openAI.transcribe(audioURL: audioURL) { [weak self] progress, message in
                    Task { @MainActor in
                        self?.processingStatus[session.id] = message
                        self?.processingProgress[session.id] = progress
                    }
                }
                
                // Update with transcript
                updatedSession.transcript = transcript
                // Save intermediate state
                persistence.saveSession(updatedSession)
                
                // 2. Analyze
                self.processingStatus[session.id] = "Анализ (JSON)…"
                self.processingProgress[session.id] = 0.92
                let analysis = try await openAI.analyze(text: transcript)
                
                updatedSession.analysis = analysis
                updatedSession.isProcessing = false
                persistence.saveSession(updatedSession)

                self.processingStatus[session.id] = nil
                self.processingProgress[session.id] = nil
                
            } catch {
                updatedSession.isProcessing = false
                persistence.saveSession(updatedSession)

                self.processingStatus[session.id] = nil
                self.processingProgress[session.id] = nil
                
                self.errorMessage = error.localizedDescription
                self.showError = true
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
