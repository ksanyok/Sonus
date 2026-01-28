import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 30) // For visualization

    /// Called on main queue when a chunk file is finalized.
    var onChunkReady: ((URL) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var inputFormat: AVAudioFormat?
    private var mainFile: AVAudioFile?
    private var chunkFile: AVAudioFile?

    private var recordingStartDate: Date?
    private var chunkStartDate: Date?

    private var currentFilename: String?
    private var currentFileURL: URL?

    private let writerQueue = DispatchQueue(label: "com.sonus.audioRecorder.writer")
    private let chunkDuration: TimeInterval = 8
    private var lastLevelUpdate: Date = .distantPast

    private var isEngineRunning: Bool = false
    
    override init() {
        super.init()

        // Best-effort: create chunk directory early to avoid doing it on the first start.
        try? FileManager.default.createDirectory(at: chunksDirectoryURL, withIntermediateDirectories: true)
    }

    var isPermissionGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Pre-start the audio engine to reduce initial recording latency.
    func warmUpEngineIfPossible() {
        guard isPermissionGranted else { return }
        if isEngineRunning { return }

        // AVAudioEngine graph operations can be fragile off-main on newer macOS.
        // Make warm-up best-effort and never crash the app.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.warmUpEngineIfPossible()
            }
            return
        }

        do {
            // Prime the graph so prepare/start doesn't trip internal assertions.
            let input = audioEngine.inputNode
            _ = input.outputFormat(forBus: 0)
            _ = audioEngine.mainMixerNode

            audioEngine.prepare()
            try audioEngine.start()
            isEngineRunning = true
        } catch {
            // Ignore warm-up failures; startRecording will surface errors.
        }
    }
    
    func requestPermission() async -> Bool {
        if #available(macOS 14.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func startRecording() throws -> String {
        if isRecording { return currentFilename ?? "" }

        // Make sure engine is already running (or starts now).
        if !isEngineRunning {
            // Проверяем что inputNode доступен перед prepare
            let inputNode = audioEngine.inputNode
            guard inputNode.outputFormat(forBus: 0).sampleRate > 0 else {
                throw RecordingError.audioEngineNotConfigured
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            isEngineRunning = true
        }

        let filename = UUID().uuidString + ".wav"
        let audioURL = PersistenceService.shared.getAudioURL(for: filename)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Дополнительная проверка формата
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw RecordingError.invalidAudioFormat
        }
        
        inputFormat = format

        // WAV with the device's native PCM format (usually Float32). Whisper accepts WAV.
        mainFile = try AVAudioFile(forWriting: audioURL, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        currentFilename = filename
        currentFileURL = audioURL

        // Prepare chunk directory (already created in init, but keep it safe).
        try FileManager.default.createDirectory(at: chunksDirectoryURL, withIntermediateDirectories: true)
        chunkFile = try createNewChunkFile(format: format)
        chunkStartDate = Date()

        recordingStartDate = Date()
        recordingDuration = 0

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.handleIncomingAudio(buffer: buffer)
        }

        isRecording = true

        return filename
    }
    
    func stopRecording() -> (filename: String, duration: TimeInterval)? {
        guard isRecording else { return nil }

        audioEngine.inputNode.removeTap(onBus: 0)
        // Keep engine running to make the next start near-instant.

        isRecording = false

        // Finalize last chunk (best-effort)
        if let url = chunkFile?.url {
            let finalizedURL = url
            chunkFile = nil
            DispatchQueue.main.async { [weak self] in
                self?.onChunkReady?(finalizedURL)
            }
        }

        mainFile = nil

        let duration = recordingDuration
        guard let filename = currentFilename else { return nil }
        currentFilename = nil
        currentFileURL = nil
        recordingStartDate = nil
        chunkStartDate = nil

        // Reset levels
        DispatchQueue.main.async {
            self.audioLevels = Array(repeating: 0, count: 30)
        }

        return (filename, duration)
    }

    private var chunksDirectoryURL: URL {
        // Store chunks next to recordings in Documents/Sonus, under /chunks
        let base = PersistenceService.shared.getAudioURL(for: "chunks")
        return base
    }

    private func createNewChunkFile(format: AVAudioFormat) throws -> AVAudioFile {
        let name = "chunk_\(UUID().uuidString).wav"
        let url = chunksDirectoryURL.appendingPathComponent(name)
        return try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
    }

    private func handleIncomingAudio(buffer: AVAudioPCMBuffer) {
        // Lightweight UI updates (duration + level) throttled to ~20Hz
        let now = Date()
        if let start = recordingStartDate {
            let elapsed = now.timeIntervalSince(start)
            if elapsed.isFinite {
                DispatchQueue.main.async { [weak self] in
                    self?.recordingDuration = elapsed
                }
            }
        }

        if now.timeIntervalSince(lastLevelUpdate) >= 0.05 {
            lastLevelUpdate = now
            let level = normalizedRMSLevel(buffer)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.audioLevels.count >= 30 { self.audioLevels.removeFirst() }
                self.audioLevels.append(level)
            }
        }

        // Copy buffer for async writing (avoid doing IO on audio thread)
        guard let format = inputFormat,
              let copied = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameCapacity) else {
            return
        }
        copied.frameLength = buffer.frameLength

        let channelCount = Int(format.channelCount)
        if format.commonFormat == .pcmFormatFloat32, let src = buffer.floatChannelData, let dst = copied.floatChannelData {
            for ch in 0..<channelCount {
                memcpy(dst[ch], src[ch], Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        } else if format.commonFormat == .pcmFormatInt16, let src = buffer.int16ChannelData, let dst = copied.int16ChannelData {
            for ch in 0..<channelCount {
                memcpy(dst[ch], src[ch], Int(buffer.frameLength) * MemoryLayout<Int16>.size)
            }
        } else if format.commonFormat == .pcmFormatInt32, let src = buffer.int32ChannelData, let dst = copied.int32ChannelData {
            for ch in 0..<channelCount {
                memcpy(dst[ch], src[ch], Int(buffer.frameLength) * MemoryLayout<Int32>.size)
            }
        } else {
            // Unsupported format copy; skip chunking but keep recording duration/levels.
            return
        }

        writerQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.mainFile?.write(from: copied)
                try self.chunkFile?.write(from: copied)
            } catch {
                // Ignore write errors to keep recording alive.
            }

            // Rotate chunk if needed
            let now = Date()
            if let chunkStart = self.chunkStartDate, now.timeIntervalSince(chunkStart) >= self.chunkDuration {
                let finalizedURL = self.chunkFile?.url
                self.chunkFile = nil
                self.chunkStartDate = now
                do {
                    if let f = self.inputFormat {
                        self.chunkFile = try self.createNewChunkFile(format: f)
                    }
                } catch {
                    // If we can't create next chunk, just stop chunking.
                    self.chunkFile = nil
                }
                if let finalizedURL {
                    DispatchQueue.main.async { [weak self] in
                        self?.onChunkReady?(finalizedURL)
                    }
                }
            }
        }
    }

    private func normalizedRMSLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return 0 }
        let samples = channelData[0]
        var sum: Float = 0
        for i in 0..<frameLength {
            let v = samples[i]
            sum += v * v
        }
        let rms = sqrt(sum / Float(frameLength))
        // Map roughly 0..1 to 0..1 with a mild boost
        let boosted = min(1, rms * 6)
        return max(0, boosted)
    }
}

enum RecordingError: LocalizedError {
    case audioEngineNotConfigured
    case invalidAudioFormat
    
    var errorDescription: String? {
        switch self {
        case .audioEngineNotConfigured:
            return "Audio engine is not properly configured. Please check microphone permissions."
        case .invalidAudioFormat:
            return "Invalid audio format detected. Please check audio device settings."
        }
    }
}
