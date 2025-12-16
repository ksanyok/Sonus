import Foundation

class PersistenceService: ObservableObject {
    static let shared = PersistenceService()
    
    @Published var sessions: [Session] = []
    
    private let fileManager = FileManager.default
    private let sessionsFileName = "sessions.json"
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var sessionsFileURL: URL {
        documentsDirectory.appendingPathComponent(sessionsFileName)
    }
    
    private init() {
        loadSessions()
    }
    
    func saveSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        persist()
    }
    
    func deleteSession(at offsets: IndexSet) {
        // Also delete audio files
        offsets.forEach { index in
            let session = sessions[index]
            let audioURL = documentsDirectory.appendingPathComponent(session.audioFilename)
            try? fileManager.removeItem(at: audioURL)
        }
        sessions.remove(atOffsets: offsets)
        persist()
    }
    
    func deleteSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            let audioURL = documentsDirectory.appendingPathComponent(session.audioFilename)
            try? fileManager.removeItem(at: audioURL)
            sessions.remove(at: index)
            persist()
        }
    }
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsFileURL)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard fileManager.fileExists(atPath: sessionsFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: sessionsFileURL)
            sessions = try JSONDecoder().decode([Session].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    func getAudioURL(for filename: String) -> URL {
        return documentsDirectory.appendingPathComponent(filename)
    }
}
