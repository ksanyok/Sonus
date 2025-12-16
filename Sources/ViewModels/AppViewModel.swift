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
    
    func deleteSession(_ session: Session) {
        if selectedSession == session {
            selectedSession = nil
        }
        persistence.deleteSession(session)
    }

    func saveSession(_ session: Session) {
        persistence.saveSession(session)
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
        
        Task {
            do {
                let audioURL = persistence.getAudioURL(for: session.audioFilename)
                
                // 1. Transcribe
                let transcript = try await openAI.transcribe(audioURL: audioURL)
                
                // Update with transcript
                updatedSession.transcript = transcript
                // Save intermediate state
                persistence.saveSession(updatedSession)
                
                // 2. Analyze
                let analysis = try await openAI.analyze(text: transcript)
                
                updatedSession.analysis = analysis
                updatedSession.isProcessing = false
                persistence.saveSession(updatedSession)
                
            } catch {
                updatedSession.isProcessing = false
                persistence.saveSession(updatedSession)
                
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    func showHint(question: String, answer: String) {
        let newHint = HintItem(id: UUID(), question: question, answer: answer, createdAt: Date())
        withAnimation(.spring()) {
            hints.append(newHint)
            if hints.count > 20 { hints.removeFirst() }
            currentHintIndex = max(hints.count - 1, 0)
        }
    }

    func clearHints() {
        withAnimation(.easeInOut) {
            hints.removeAll()
            currentHintIndex = 0
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
}

struct HintItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let question: String
    let answer: String
    let createdAt: Date
}
