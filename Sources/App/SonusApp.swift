import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: AppViewModel?
    weak var l10n: LocalizationService?
    private var statusItem: NSStatusItem?
    private var hintWindowController: HintWindowController?
    private var suggestionWindowController: RecordingSuggestionWindowController?
    private let triggerService = ContextTriggerService()
    private var notificationObservers: [NSObjectProtocol] = []
    private var didConfigureTriggers = false
    private var didStartTriggers = false
    private var statusItemBaseImage: NSImage?
    private var statusItemBlinkTimer: Timer?
    private var statusItemBlinkOn = false
    
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

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .sonusOpenSettings,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.openMainWindow()
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .sonusShowMiniWindow,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.showMiniWindowIfNeeded()
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .sonusTriggersDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.reloadTriggerSettings()
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .sonusCloseHintsPanel,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.hintWindowController?.close()
                }
            }
        )

        configureTriggersIfPossible()

        GlobalHotKeyService.shared.register()
        GlobalHotKeyService.shared.onHotKeyTriggered = { [weak self] in
            self?.toggleMiniWindow()
        }
        
        // Проверка обновлений при запуске (в фоне)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 секунды после запуска
            await UpdateService.shared.checkForUpdates(silent: true)
        }
    }

    func configureTriggersIfPossible() {
        guard !didConfigureTriggers else { return }
        guard viewModel != nil, l10n != nil else { return }
        didConfigureTriggers = true

        triggerService.onSuggestRecording = { [weak self] reason in
            guard let self else { return }
            Task { @MainActor in
                guard let vm = self.viewModel, let l10n = self.l10n else { return }
                guard !vm.isRecording && !vm.isStartingRecording else { return }

                let title: String
                let message: String
                switch reason {
                case .microphoneActive:
                    title = (l10n.language == .ru) ? "Микрофон активен" : "Microphone is active"
                    message = (l10n.language == .ru)
                        ? "Похоже, какое‑то приложение использует микрофон. Начать запись в Sonus?"
                        : "Another app seems to be using the microphone. Start recording in Sonus?"
                case .appBecameActive(let appName):
                    title = (l10n.language == .ru) ? "Похоже на звонок" : "Possible call"
                    message = (l10n.language == .ru)
                        ? "Вы открыли \(appName). Начать запись разговора?"
                        : "You opened \(appName). Start recording?"
                }

                vm.presentRecordingSuggestion(title: title, message: message)

                self.startStatusItemBlinking()

                self.suggestionWindowController?.hide()
                self.suggestionWindowController = RecordingSuggestionWindowController(
                    statusItem: self.statusItem,
                    titleStart: l10n.t("Start recording", ru: "Начать запись"),
                    titleLater: l10n.t("Later", ru: "Позже"),
                    onStart: {
                        vm.dismissRecordingSuggestion()
                        vm.startRecording()
                        NotificationCenter.default.post(name: .sonusShowMiniWindow, object: nil)
                        self.stopStatusItemBlinking()
                        self.suggestionWindowController?.hide()
                        self.suggestionWindowController = nil
                    },
                    onLater: {
                        vm.dismissRecordingSuggestion()
                        self.stopStatusItemBlinking()
                        self.suggestionWindowController?.hide()
                        self.suggestionWindowController = nil
                    }
                )

                self.suggestionWindowController?.show(title: title, message: message)

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 12 * 1_000_000_000)
                    self.stopStatusItemBlinking()
                    self.suggestionWindowController?.hide()
                    self.suggestionWindowController = nil
                }
            }
        }

        startTriggersIfPossible()
    }

    func startTriggersIfPossible() {
        guard didConfigureTriggers else { return }
        guard !didStartTriggers else { return }
        didStartTriggers = true
        reloadTriggerSettings()
        triggerService.start()
    }

    func showDebugRecordingSuggestion() {
        guard let vm = viewModel, let l10n else { return }
        guard !vm.isRecording && !vm.isStartingRecording else { return }

        let title = l10n.t("Debug prompt", ru: "Тестовое уведомление")
        let message = l10n.t(
            "This is an opt-in debug prompt to verify the suggestion window.",
            ru: "Это тестовое уведомление для проверки окна рекомендации."
        )

        suggestionWindowController?.hide()
        stopStatusItemBlinking()
        suggestionWindowController = RecordingSuggestionWindowController(
            statusItem: statusItem,
            titleStart: l10n.t("Start recording", ru: "Начать запись"),
            titleLater: l10n.t("Later", ru: "Позже"),
            onStart: {
                vm.dismissRecordingSuggestion()
                vm.startRecording()
                NotificationCenter.default.post(name: .sonusShowMiniWindow, object: nil)
                self.stopStatusItemBlinking()
                self.suggestionWindowController?.hide()
                self.suggestionWindowController = nil
            },
            onLater: {
                vm.dismissRecordingSuggestion()
                self.stopStatusItemBlinking()
                self.suggestionWindowController?.hide()
                self.suggestionWindowController = nil
            }
        )
        startStatusItemBlinking()
        suggestionWindowController?.show(title: title, message: message)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
            self.stopStatusItemBlinking()
            self.suggestionWindowController?.hide()
            self.suggestionWindowController = nil
        }
    }

    deinit {
        for obs in notificationObservers {
            NotificationCenter.default.removeObserver(obs)
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
            statusItemBaseImage = button.image
        }
        let menu = NSMenu()
        menu.addItem(withTitle: t("Open Sonus", "Открыть Sonus"), action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: t("Toggle Recording", "Переключить запись"), action: #selector(toggleRecording), keyEquivalent: "")
        menu.addItem(withTitle: t("Show Hints", "Показать подсказки"), action: #selector(toggleHints), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: t("Quit", "Выйти"), action: #selector(quit), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    private func startStatusItemBlinking() {
        guard let button = statusItem?.button else { return }
        if statusItemBaseImage == nil {
            statusItemBaseImage = button.image
        }

        stopStatusItemBlinking()
        statusItemBlinkOn = false

        let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let button = self.statusItem?.button else { return }
                self.statusItemBlinkOn.toggle()
                if self.statusItemBlinkOn {
                    button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Sonus")
                } else {
                    button.image = self.statusItemBaseImage ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sonus")
                }
            }
        }

        statusItemBlinkTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopStatusItemBlinking() {
        statusItemBlinkTimer?.invalidate()
        statusItemBlinkTimer = nil
        statusItemBlinkOn = false
        if let button = statusItem?.button {
            button.image = statusItemBaseImage ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sonus")
        }
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

    private func showMiniWindowIfNeeded() {
        let miniWindow = NSApplication.shared.windows.first { $0.title == "Mini Recorder" }
        if let window = miniWindow, window.isVisible { return }
        if let url = URL(string: "sonus://toggle-mini") {
            NSWorkspace.shared.open(url)
        }
    }

    private func reloadTriggerSettings() {
        let enabled: Bool
        if UserDefaults.standard.object(forKey: "triggers.enabled") == nil {
            enabled = true
        } else {
            enabled = UserDefaults.standard.bool(forKey: "triggers.enabled")
        }

        let mic: Bool
        if UserDefaults.standard.object(forKey: "triggers.mic") == nil {
            mic = true
        } else {
            mic = UserDefaults.standard.bool(forKey: "triggers.mic")
        }

        let apps: Bool
        if UserDefaults.standard.object(forKey: "triggers.apps") == nil {
            apps = true
        } else {
            apps = UserDefaults.standard.bool(forKey: "triggers.apps")
        }

        triggerService.settings = .init(
            enableSuggestions: enabled,
            suggestOnMicActive: mic,
            suggestOnAppActive: apps,
            cooldownSeconds: 30
        )
        triggerService.persistSettings()
    }

    func toggleHintsPanel() {
        toggleHints()
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
                    appDelegate.configureTriggersIfPossible()

                    // Opt-in debug hook to validate the suggestion panel without relying on external triggers.
                    if ProcessInfo.processInfo.environment["SONUS_DEBUG_SHOW_SUGGESTION"] == "1" {
                        Task { @MainActor in
                            appDelegate.showDebugRecordingSuggestion()
                        }
                    }

                    // Opt-in debug hook to validate the hints panel open path.
                    if ProcessInfo.processInfo.environment["SONUS_DEBUG_SHOW_HINTS"] == "1" {
                        Task { @MainActor in
                            appDelegate.toggleHintsPanel()
                        }
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(l10n.t("About Sonus", ru: "О приложении Sonus")) {
                    openWindow(id: "about")
                }
            }
            
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
        
        Window("About Sonus", id: "about") {
            AboutView()
                .environmentObject(l10n)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 380)
    }
}
