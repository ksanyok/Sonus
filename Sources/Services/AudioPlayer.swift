import Foundation
import AVFoundation

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    override init() {
        super.init()
    }
    
    func startPlayback(audioURL: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            duration = audioPlayer?.duration ?? 0
            
            startTimer()
        } catch {
            print("Playback failed: \(error)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        stopTimer()
        currentTime = 0
    }
    
    func togglePlayback(audioURL: URL) {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback(audioURL: audioURL)
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentTime = 0
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
