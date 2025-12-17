import Foundation
import CoreAudio

/// Best-effort monitor that detects when the system default input device (microphone)
/// is running somewhere (could be this app or another app).
final class MicrophoneUsageMonitor {
    enum State: Equatable {
        case unknown
        case inactive
        case active
    }

    private var timer: Timer?
    private var lastState: State = .unknown

    var onChange: ((State) -> Void)?

    func start(pollInterval: TimeInterval = 1.0) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = pollInterval * 0.2
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = Self.isDefaultInputRunningSomewhere()
            .map { $0 ? State.active : State.inactive } ?? .unknown

        guard current != lastState else { return }
        lastState = current
        onChange?(current)
    }

    private static func isDefaultInputRunningSomewhere() -> Bool? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != 0 else { return nil }

        var isRunning: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)

        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let runningStatus = AudioObjectGetPropertyData(
            AudioObjectID(deviceID),
            &runningAddress,
            0,
            nil,
            &size,
            &isRunning
        )

        guard runningStatus == noErr else { return nil }
        return isRunning != 0
    }
}
