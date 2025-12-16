import AppKit
import SwiftUI

final class HintWindowController: NSWindowController {
    private weak var statusItem: NSStatusItem?
    private let panelSize = NSSize(width: 360, height: 280)

    init(viewModel: AppViewModel, l10n: LocalizationService, statusItem: NSStatusItem?) {
        self.statusItem = statusItem
        let hosting = NSHostingController(
            rootView: HintBubbleView(viewModel: viewModel)
                .environmentObject(l10n)
                .environment(\.locale, l10n.locale)
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.contentViewController = hosting
        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            show()
        }
    }

    func show() {
        guard let panel = window as? NSPanel else { return }
        if let button = statusItem?.button, let screenFrame = button.window?.frame {
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.minY - panelSize.height - 8
            panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
        }
        panel.orderFrontRegardless()
    }
}
