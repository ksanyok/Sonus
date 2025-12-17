import AppKit
import SwiftUI

final class HintWindowController: NSWindowController {
    private weak var statusItem: NSStatusItem?
    private let panelSize = NSSize(width: 360, height: 280)

    init(viewModel: AppViewModel, l10n: LocalizationService, statusItem: NSStatusItem?) {
        self.statusItem = statusItem
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.hasShadow = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

        // Clamp content size to a fixed rectangle to avoid AppKit trying to infer min/max
        // sizes from SwiftUI hosting view constraints.
        window.contentMinSize = panelSize
        window.contentMaxSize = panelSize

        let rootView = HintBubbleView(viewModel: viewModel)
            .environmentObject(l10n)
            .environment(\.locale, l10n.locale)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.translatesAutoresizingMaskIntoConstraints = true

        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        container.autoresizingMask = [.width, .height]
        container.translatesAutoresizingMaskIntoConstraints = true
        container.addSubview(hostingView)

        let vc = NSViewController()
        vc.view = container
        window.contentViewController = vc
        super.init(window: window)
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
        guard let window else { return }
        if let button = statusItem?.button, let screenFrame = button.window?.frame {
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.minY - panelSize.height - 8
            window.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
        }
        window.orderFrontRegardless()
    }
}
