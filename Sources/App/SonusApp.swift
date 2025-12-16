import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
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
}

@main
struct SonusApp: App {
    @StateObject var viewModel = AppViewModel()
    @Environment(\.openWindow) var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("Sonus", id: "main") {
            MainWindow(viewModel: viewModel)
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
            MiniWindow(viewModel: viewModel)
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
