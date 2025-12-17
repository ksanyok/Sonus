import AppKit

@MainActor
final class RecordingSuggestionWindowController: NSWindowController {
    private weak var statusItem: NSStatusItem?
    private let panelWidth: CGFloat = 360
    private let panelHeight: CGFloat = 180

    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")

    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let laterButton = NSButton(title: "Later", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)

    private let onStart: () -> Void
    private let onLater: () -> Void

    init(
        statusItem: NSStatusItem?,
        titleStart: String,
        titleLater: String,
        onStart: @escaping () -> Void,
        onLater: @escaping () -> Void
    ) {
        self.statusItem = statusItem
        self.onStart = onStart
        self.onLater = onLater

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
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

        let vc = NSViewController()
        vc.view = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

        let effect = NSVisualEffectView(frame: vc.view.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .popover
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        vc.view.addSubview(effect)

        let content = NSView(frame: effect.bounds)
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)

        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        messageLabel.font = NSFont.systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 3

        startButton.title = titleStart
        startButton.bezelStyle = .rounded
        startButton.controlSize = .regular
        startButton.target = nil
        startButton.action = nil

        laterButton.title = titleLater
        laterButton.bezelStyle = .rounded
        laterButton.controlSize = .regular
        laterButton.target = nil
        laterButton.action = nil

        closeButton.bezelStyle = .circular
        closeButton.controlSize = .small
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = nil
        closeButton.action = nil

        [titleLabel, messageLabel, startButton, laterButton, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -10),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),

            startButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            startButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),

            laterButton.leadingAnchor.constraint(equalTo: startButton.trailingAnchor, constant: 10),
            laterButton.bottomAnchor.constraint(equalTo: startButton.bottomAnchor),
        ])

        panel.contentViewController = vc
        super.init(window: panel)

        startButton.target = self
        startButton.action = #selector(didTapStart)

        laterButton.target = self
        laterButton.action = #selector(didTapLater)

        closeButton.target = self
        closeButton.action = #selector(didTapLater)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(title: String, message: String) {
        titleLabel.stringValue = title
        messageLabel.stringValue = message

        guard let panel = window as? NSPanel else { return }
        if let button = statusItem?.button, let screenFrame = button.window?.frame {
            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.minY - panelHeight - 8
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        close()
    }

    @objc private func didTapStart() {
        onStart()
    }

    @objc private func didTapLater() {
        onLater()
    }
}
