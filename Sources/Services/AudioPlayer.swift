import Foundation
import AVFoundation

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var loadedURL: URL?
    private var timer: Timer?
    
    override init() {
        super.init()
    }

    private func ensurePlayer(audioURL: URL) throws -> AVAudioPlayer {
        if let player = audioPlayer, loadedURL == audioURL {
            return player
        }

        stopTimer()
        isPlaying = false

        let newPlayer = try AVAudioPlayer(contentsOf: audioURL)
        newPlayer.delegate = self
        newPlayer.prepareToPlay()

        audioPlayer = newPlayer
        loadedURL = audioURL
        duration = newPlayer.duration
        currentTime = newPlayer.currentTime

        return newPlayer
    }
    
    func startPlayback(audioURL: URL) {
        do {
            let player = try ensurePlayer(audioURL: audioURL)
            player.play()
            isPlaying = true
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

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let clamped = min(max(time, 0), max(0, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    func seek(to time: TimeInterval, audioURL: URL) {
        do {
            let player = try ensurePlayer(audioURL: audioURL)
            let clamped = min(max(time, 0), max(0, player.duration))
            player.currentTime = clamped
            currentTime = clamped
            duration = player.duration
        } catch {
            print("Seek failed: \(error)")
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
