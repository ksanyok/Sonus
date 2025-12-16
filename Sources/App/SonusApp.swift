import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: AppViewModel?
    weak var l10n: LocalizationService?
    private var statusItem: NSStatusItem?
    private var hintWindowController: HintWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // If another instance is already running, quit this one to avoid duplicates.
        // When launched via SwiftPM (`swift run`), the process isn't a real .app bundle and
        // this check can produce false positives and immediately terminate the app.
        if Bundle.main.bundleURL.pathExtension == "app",
           let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        setupStatusBar()
        GlobalHotKeyService.shared.register()
        GlobalHotKeyService.shared.onHotKeyTriggered = { [weak self] in
            self?.toggleMiniWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
    
    func toggleMiniWindow() {
        DispatchQueue.main.async {
            let miniWindow = NSApplication.shared.windows.first { $0.title == "Mini Recorder" }
            
            if let window = miniWindow, window.isVisible {
                window.close()
            } else {
                if let url = URL(string: "sonus://toggle-mini") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sonus")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: t("Open Sonus", "Открыть Sonus"), action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: t("Toggle Recording", "Переключить запись"), action: #selector(toggleRecording), keyEquivalent: "")
        menu.addItem(withTitle: t("Show Hints", "Показать подсказки"), action: #selector(toggleHints), keyEquivalent: "")
        menu.addItem(withTitle: t("Simulate Live Hint", "Симулировать подсказку"), action: #selector(simulateHint), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: t("Quit", "Выйти"), action: #selector(quit), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    private func t(_ en: String, _ ru: String) -> String {
        let saved = UserDefaults.standard.string(forKey: LocalizationService.storageKey)
        let lang = AppLanguage(rawValue: saved ?? "en") ?? .en
        return lang == .ru ? ru : en
    }
    
    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func toggleHints() {
        guard let viewModel else { return }
        if hintWindowController == nil {
            let localization = l10n ?? LocalizationService()
            hintWindowController = HintWindowController(viewModel: viewModel, l10n: localization, statusItem: statusItem)
        }

        hintWindowController?.toggle()
    }

    @objc private func simulateHint() {
        guard let viewModel else { return }
        let sampleQuestions = [
            "Можем ли мы уложиться в 2 недели?",
            "Сколько будет стоить поддержка?",
            "Какие гарантии по качеству?",
            "Есть ли кейсы в моей отрасли?"
        ]
        let sampleAnswers = [
            "Оценим объём и вернём точный срок сегодня, предварительно 2-3 недели.",
            "Поддержка считается по факту трудозатрат, можем предложить фиксированный пакет часов.",
            "Даем гарантию на исправление дефектов в рамках договорённых требований.",
            "Да, есть кейсы, могу выслать краткое резюме и результаты по похожим проектам."
        ]
        if let q = sampleQuestions.randomElement(), let a = sampleAnswers.randomElement() {
            let engagement = Double.random(in: 0.25...0.95)
            viewModel.showHint(question: q, answer: a, engagement: engagement)
        }
        hintWindowController?.show()
    }
    
    @objc private func toggleRecording() {
        guard let viewModel else { return }
        if viewModel.audioRecorder.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
struct SonusApp: App {
    @StateObject var viewModel = AppViewModel()
    @StateObject private var l10n = LocalizationService()
    @Environment(\.openWindow) var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("Sonus", id: "main") {
            MainWindow(viewModel: viewModel)
                .environmentObject(viewModel)
                .environmentObject(l10n)
                .environment(\.locale, l10n.locale)
                .onAppear {
                    appDelegate.viewModel = viewModel
                    appDelegate.l10n = l10n
                }
        }
        .commands {
            CommandMenu(l10n.t("Recording", ru: "Запись")) {
                Button(l10n.t("Toggle Recording", ru: "Переключить запись")) {
                    if viewModel.audioRecorder.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
                
                Button(l10n.t("Toggle Mini Window", ru: "Мини-окно")) {
                    openWindow(id: "mini")
                }
                .keyboardShortcut("M", modifiers: [.command, .shift])
            }
        }
        
        Window("Mini Recorder", id: "mini") {
            MiniWindow(viewModel: viewModel, recorder: viewModel.audioRecorder)
                .environmentObject(l10n)
                .environment(\.locale, l10n.locale)
                .onAppear {
                    // Hack to make window always on top and transparent title bar
                    for window in NSApplication.shared.windows {
                        if window.title == "Mini Recorder" {
                            window.level = .floating
                            window.styleMask.insert(.fullSizeContentView)
                            window.titlebarAppearsTransparent = true
                            window.isMovableByWindowBackground = true
                            window.standardWindowButton(.closeButton)?.isHidden = true
                            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                            window.standardWindowButton(.zoomButton)?.isHidden = true
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 160, height: 120)
        .handlesExternalEvents(matching: Set(arrayLiteral: "toggle-mini"))
    }
}
