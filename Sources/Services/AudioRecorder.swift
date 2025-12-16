import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 30) // For visualization
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentFilename: String?
    
    override init() {
        super.init()
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
        let filename = UUID().uuidString + ".m4a"
        let audioURL = PersistenceService.shared.getAudioURL(for: filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            currentFilename = filename
            recordingDuration = 0

            startTimer()
            return filename
        } catch {
            throw error
        }
    }
    
    func stopRecording() -> (filename: String, duration: TimeInterval)? {
        guard let recorder = audioRecorder, recorder.isRecording else { return nil }

        let duration = recorder.currentTime
        recorder.stop()

        stopTimer()
        isRecording = false

        guard let filename = currentFilename else { return nil }
        currentFilename = nil

        return (filename, duration)
    }
    
    private func startTimer() {
        // Update UI more frequently for smoother animation (approx 60 FPS)
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }

            recorder.updateMeters()
            let currentTime = recorder.currentTime
            let level = recorder.averagePower(forChannel: 0)
            let normalizedLevel = max(0, (level + 60) / 60) // Normalize -160..0 to 0..1 with boost

            DispatchQueue.main.async {
                self.recordingDuration = currentTime
                if self.audioLevels.count >= 30 {
                    self.audioLevels.removeFirst()
                }
                self.audioLevels.append(normalizedLevel)
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        // Reset levels
        DispatchQueue.main.async {
            self.audioLevels = Array(repeating: 0, count: 30)
        }
    }
}
