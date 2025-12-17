import Foundation
import AVFoundation

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

    private var sessionsBackupFileURL: URL {
        sessionsFileURL.appendingPathExtension("bak")
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
            // Keep a backup before overwriting to avoid losing data on schema changes.
            if fileManager.fileExists(atPath: sessionsFileURL.path) {
                try? fileManager.removeItem(at: sessionsBackupFileURL)
                try? fileManager.copyItem(at: sessionsFileURL, to: sessionsBackupFileURL)
            }
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsFileURL)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        if fileManager.fileExists(atPath: sessionsFileURL.path) {
            do {
                let data = try Data(contentsOf: sessionsFileURL)
                sessions = try JSONDecoder().decode([Session].self, from: data)
            } catch {
                print("Failed to load sessions: \(error)")

                // Try loading from backup if available.
                if fileManager.fileExists(atPath: sessionsBackupFileURL.path) {
                    do {
                        let data = try Data(contentsOf: sessionsBackupFileURL)
                        sessions = try JSONDecoder().decode([Session].self, from: data)
                        print("Loaded sessions from backup.")
                    } catch {
                        print("Failed to load sessions backup: \(error)")
                    }
                }
            }
        }

        recoverOrphanAudioFilesIfNeeded()
    }

    private func recoverOrphanAudioFilesIfNeeded() {
        // If sessions.json was overwritten after a decode failure, audio files may still exist.
        // Recreate sessions for any audio files not referenced by current sessions list.
        let referenced = Set(sessions.map { $0.audioFilename })

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            print("Failed to list Documents for recovery: \(error)")
            return
        }

        let allowedExts: Set<String> = ["wav", "m4a", "mp3", "aac", "caf"]
        var recovered: [Session] = []

        for url in urls {
            guard url.lastPathComponent != sessionsFileName else { continue }

            let ext = url.pathExtension.lowercased()
            guard allowedExts.contains(ext) else { continue }
            guard !referenced.contains(url.lastPathComponent) else { continue }
            guard !url.lastPathComponent.hasPrefix("chunk_") else { continue }

            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey])
            guard values?.isRegularFile == true else { continue }

            let date = values?.creationDate ?? values?.contentModificationDate ?? Date()

            let asset = AVURLAsset(url: url)
            let seconds = CMTimeGetSeconds(asset.duration)
            let duration = seconds.isFinite ? seconds : 0

            let source: SessionSource? = (ext == "wav") ? .recording : .importFile

            let session = Session(
                id: UUID(),
                date: date,
                duration: duration,
                audioFilename: url.lastPathComponent,
                transcript: nil,
                analysis: nil,
                analysisUpdatedAt: nil,
                analysisSchemaVersion: nil,
                isProcessing: false,
                category: .personal,
                customTitle: url.deletingPathExtension().lastPathComponent,
                source: source
            )
            recovered.append(session)
        }

        guard !recovered.isEmpty else { return }

        sessions.append(contentsOf: recovered)
        sessions.sort { $0.date > $1.date }
        persist()
        print("Recovered \(recovered.count) sessions from audio files.")
    }
    
    func getAudioURL(for filename: String) -> URL {
        return documentsDirectory.appendingPathComponent(filename)
    }
}
