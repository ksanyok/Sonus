import Foundation
import AVFoundation

enum AudioDurationUtils {
    static func loadDurationSeconds(url: URL) async -> TimeInterval {
        // Prefer AVURLAsset with precise duration.
        let asset = AVURLAsset(
            url: url,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )

        do {
            let durationTime = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(durationTime)
            if seconds.isFinite, seconds > 0.01 {
                return seconds
            }
        } catch {
            // Fall back below.
        }

        // Fallback: AVAudioPlayer duration is often reliable for compressed formats.
        if let player = try? AVAudioPlayer(contentsOf: url) {
            let seconds = player.duration
            if seconds.isFinite, seconds > 0.01 {
                return seconds
            }
        }

        return 0
    }
}
