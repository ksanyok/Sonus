import Foundation
import AppKit

/// Lightweight triggers that can suggest starting a recording in the mini window.
///
/// Notes:
/// - We cannot reliably detect "incoming calls" for third-party apps without special integrations.
/// - We can do best-effort signals: active app + microphone running somewhere.
final class ContextTriggerService {
    struct Settings {
        var enableSuggestions: Bool
        var suggestOnMicActive: Bool
        var suggestOnAppActive: Bool
        var cooldownSeconds: TimeInterval
    }

    enum TriggerReason: Equatable {
        case microphoneActive
        case appBecameActive(appName: String)
    }

    private let micMonitor = MicrophoneUsageMonitor()
    private var appObserver: Any?

    private var lastPromptAt: Date?

    var settings: Settings {
        didSet {
            applySettings()
        }
    }

    var onSuggestRecording: ((TriggerReason) -> Void)?

    init() {
        self.settings = Settings(
            enableSuggestions: UserDefaults.standard.bool(forKey: "triggers.enabled"),
            suggestOnMicActive: UserDefaults.standard.bool(forKey: "triggers.mic"),
            suggestOnAppActive: UserDefaults.standard.bool(forKey: "triggers.apps"),
            cooldownSeconds: 30
        )

        // Defaults: enable all triggers unless the user has explicitly configured.
        if UserDefaults.standard.object(forKey: "triggers.enabled") == nil {
            settings.enableSuggestions = true
            settings.suggestOnMicActive = true
            settings.suggestOnAppActive = true
            persistSettings()
        }

        applySettings()
    }

    deinit {
        stop()
    }

    func persistSettings() {
        UserDefaults.standard.set(settings.enableSuggestions, forKey: "triggers.enabled")
        UserDefaults.standard.set(settings.suggestOnMicActive, forKey: "triggers.mic")
        UserDefaults.standard.set(settings.suggestOnAppActive, forKey: "triggers.apps")
    }

    func start() {
        applySettings()
    }

    func stop() {
        micMonitor.stop()
        if let appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appObserver)
            self.appObserver = nil
        }
    }

    private func applySettings() {
        stop()
        guard settings.enableSuggestions else { return }

        if settings.suggestOnMicActive {
            micMonitor.onChange = { [weak self] state in
                guard let self else { return }
                if state == .active {
                    self.maybeSuggest(.microphoneActive)
                }
            }
            micMonitor.start(pollInterval: 1.0)
        }

        if settings.suggestOnAppActive {
            appObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let self else { return }
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

                let bundleID = app.bundleIdentifier ?? ""
                let name = app.localizedName ?? ""

                // Common bundle IDs (may vary):
                let interesting = [
                    "ru.keepcoder.Telegram", // Telegram
                    "com.viber.osx" // Viber
                ]

                if interesting.contains(bundleID) {
                    self.maybeSuggest(.appBecameActive(appName: name.isEmpty ? bundleID : name))
                }
            }
        }
    }

    private func maybeSuggest(_ reason: TriggerReason) {
        let now = Date()
        if let last = lastPromptAt, now.timeIntervalSince(last) < settings.cooldownSeconds {
            return
        }
        lastPromptAt = now
        onSuggestRecording?(reason)
    }
}
