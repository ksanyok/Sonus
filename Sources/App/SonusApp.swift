import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: AppViewModel?
    weak var l10n: LocalizationService?
    private var statusItem: NSStatusItem?
    private let triggerService = ContextTriggerService()
    private var notificationObservers: [NSObjectProtocol] = []
    private var didConfigureTriggers = false
    private var didStartTriggers = false
    private var statusItemBaseImage: NSImage?
    private var statusUpdateTimer: Timer?
    
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

        // AI Assistant открывается через Option+Space (GlobalHotKeyService)

        configureTriggersIfPossible()

        GlobalHotKeyService.shared.register()
        GlobalHotKeyService.shared.onHotKeyTriggered = { [weak self] in
            self?.toggleMiniWindow()
        }
        
        // Регистрация горячей клавиши для AI ассистента (Option + Space)
        GlobalHotKeyService.shared.registerAssistantHotKey()
        GlobalHotKeyService.shared.onAssistantHotKeyTriggered = {
            FloatingAssistantWindow.toggle()
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
                    title = (l10n.language == .ru) ? "Приложение активно" : "App became active"
                    message = (l10n.language == .ru)
                        ? "\(appName) активировано. Начать запись?"
                        : "\(appName) became active. Start recording?"
                }
                
                // Триггеры теперь не показывают уведомления - вместо этого используется AI Assistant
                // который вызывается через Option+Space
                print("Trigger: \(title) - \(message)")
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
        menu.addItem(withTitle: t("Open AI Assistant", "Открыть AI Ассистента"), action: #selector(openAIAssistant), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: t("Quit", "Выйти"), action: #selector(quit), keyEquivalent: "q")
        statusItem?.menu = menu
        
        // Обновляем меню каждую секунду во время записи
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusMenu()
            }
        }
    }

    private func updateStatusMenu() {
        guard let vm = viewModel, let menu = statusItem?.menu else { return }
        
        // Обновляем первый пункт меню с информацией о записи
        if vm.isRecording {
            let duration = Int(vm.audioRecorder.recordingDuration)
            let minutes = duration / 60
            let seconds = duration % 60
            let timeStr = String(format: "%02d:%02d", minutes, seconds)
            
            // Пока просто показываем время записи
            menu.items.first?.title = "🔴 " + t("Recording", "Запись") + ": \(timeStr)"
        } else {
            menu.items.first?.title = t("Open Sonus", "Открыть Sonus")
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

    @objc private func openAIAssistant() {
        // Открываем AI Assistant через FloatingAssistantWindow
        let assistant = RealTimeAssistantService.shared
        if !assistant.isActive {
            Task {
                try await assistant.start()
            }
        }
        // Окно автоматически откроется через GlobalHotKeyService
        NotificationCenter.default.post(name: NSNotification.Name("ActivateAIAssistant"), object: nil)
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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var l10n = LocalizationService()
    
    @Environment(\.scenePhase) var scenePhase

    init() {
        // Цветовая схема настраивается через Settings
    }
    
    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow(viewModel: viewModel)
                .environmentObject(viewModel)
                .environmentObject(l10n)
                .frame(minWidth: 1100, minHeight: 700)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        appDelegate.viewModel = viewModel
                        appDelegate.l10n = l10n
                        appDelegate.configureTriggersIfPossible()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) { }
        }
        
        WindowGroup(id: "mini", for: Session.ID.self) { $sessionID in
            MiniWindow(viewModel: viewModel, recorder: viewModel.audioRecorder)
                .environmentObject(viewModel)
                .environmentObject(l10n)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
