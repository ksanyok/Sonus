import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: AppViewModel?
    private var statusItem: NSStatusItem?
    private var hintWindowController: HintWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // If another instance is already running, quit this one to avoid duplicates
        if let bundleID = Bundle.main.bundleIdentifier,
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
        menu.addItem(withTitle: "Open Sonus", action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Toggle Recording", action: #selector(toggleRecording), keyEquivalent: "")
        menu.addItem(withTitle: "Show Hints", action: #selector(toggleHints), keyEquivalent: "")
        menu.addItem(withTitle: "Simulate Live Hint", action: #selector(simulateHint), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem?.menu = menu
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
            hintWindowController = HintWindowController(viewModel: viewModel, statusItem: statusItem)
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
    @Environment(\.openWindow) var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("Sonus", id: "main") {
            MainWindow(viewModel: viewModel)
                .onAppear {
                    appDelegate.viewModel = viewModel
                }
        }
        .commands {
            CommandMenu("Recording") {
                Button("Toggle Recording") {
                    if viewModel.audioRecorder.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
                
                Button("Toggle Mini Window") {
                    openWindow(id: "mini")
                }
                .keyboardShortcut("M", modifiers: [.command, .shift])
            }
        }
        
        Window("Mini Recorder", id: "mini") {
            MiniWindow(viewModel: viewModel, recorder: viewModel.audioRecorder)
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
