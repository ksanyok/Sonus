import Foundation
import AVFoundation
import AppKit

class PersistenceService: ObservableObject {
    static let shared = PersistenceService()
    
    @Published var sessions: [Session] = []
    
    private let fileManager = FileManager.default
    private let sessionsFileName = "sessions.json"

    private let audioStorageBookmarkKey = "sonus.audioStorage.bookmark"
    private var storageDirectoryCached: URL?
    private var isStorageAccessActive: Bool = false
    
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
        restoreAudioStorageAccessIfNeeded()
        loadSessions()
    }

    /// The directory where audio files are stored. Defaults to the app's Documents directory.
    var audioStorageDirectory: URL {
        if let cached = storageDirectoryCached {
            return cached
        }
        return documentsDirectory
    }

    var audioStorageDirectoryPath: String {
        audioStorageDirectory.path
    }

    func revealAudioStorageDirectoryInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([audioStorageDirectory])
    }

    /// Set a new audio storage directory. This will persist a security-scoped bookmark and best-effort move existing audio files.
    func setAudioStorageDirectory(_ newDirectory: URL) throws {
        let oldDirectory = audioStorageDirectory

        let bookmark = try newDirectory.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: audioStorageBookmarkKey)

        storageDirectoryCached = newDirectory
        restoreAudioStorageAccessIfNeeded()

        // Ensure it exists.
        try? fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)

        // Best-effort: move all referenced audio files.
        moveAllAudioFiles(from: oldDirectory, to: newDirectory)
    }

    private func restoreAudioStorageAccessIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: audioStorageBookmarkKey) else {
            storageDirectoryCached = documentsDirectory
            return
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Refresh bookmark.
                let refreshed = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(refreshed, forKey: audioStorageBookmarkKey)
            }

            storageDirectoryCached = url

            // Keep access active for app lifetime to simplify audio playback/analysis.
            if !isStorageAccessActive {
                isStorageAccessActive = url.startAccessingSecurityScopedResource()
            }
        } catch {
            // Fall back to Documents if bookmark can't be resolved.
            storageDirectoryCached = documentsDirectory
        }
    }

    private func moveAllAudioFiles(from oldDirectory: URL, to newDirectory: URL) {
        guard oldDirectory != newDirectory else { return }

        for s in sessions {
            let oldURL = oldDirectory.appendingPathComponent(s.audioFilename)
            let newURL = newDirectory.appendingPathComponent(s.audioFilename)
            guard fileManager.fileExists(atPath: oldURL.path) else { continue }
            if fileManager.fileExists(atPath: newURL.path) { continue }
            do {
                try fileManager.moveItem(at: oldURL, to: newURL)
            } catch {
                // Best-effort: keep going.
                continue
            }
        }

        // Move chunks folder if exists.
        let oldChunks = oldDirectory.appendingPathComponent("chunks")
        let newChunks = newDirectory.appendingPathComponent("chunks")
        if fileManager.fileExists(atPath: oldChunks.path), !fileManager.fileExists(atPath: newChunks.path) {
            try? fileManager.moveItem(at: oldChunks, to: newChunks)
        }
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
            let audioURL = audioStorageDirectory.appendingPathComponent(session.audioFilename)
            try? fileManager.removeItem(at: audioURL)
        }
        sessions.remove(atOffsets: offsets)
        persist()
    }
    
    func deleteSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            let audioURL = audioStorageDirectory.appendingPathComponent(session.audioFilename)
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
                at: audioStorageDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            print("Failed to list audio storage for recovery: \(error)")
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

            let duration = secondsFromURLBestEffort(url)

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
        return audioStorageDirectory.appendingPathComponent(filename)
    }

    func audioFileSizeBytes(for filename: String) -> Int64? {
        let url = getAudioURL(for: filename)
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    func audioFileSizeString(for filename: String) -> String? {
        guard let bytes = audioFileSizeBytes(for: filename) else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func secondsFromURLBestEffort(_ url: URL) -> TimeInterval {
        if let player = try? AVAudioPlayer(contentsOf: url) {
            let seconds = player.duration
            if seconds.isFinite { return seconds }
        }
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        return seconds.isFinite ? seconds : 0
    }
}
