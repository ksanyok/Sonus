import AppKit

@MainActor
final class RecordingSuggestionWindowController: NSWindowController {
    private weak var statusItem: NSStatusItem?
    private let panelWidth: CGFloat = 360
    private let panelHeight: CGFloat = 132

    private let iconView = NSImageView()
    private let accentBar = NSView()
    private let topGloss = NSView()
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
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

        let vc = NSViewController()
        vc.view = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

        let effect = NSVisualEffectView(frame: vc.view.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        vc.view.addSubview(effect)

        let content = NSView(frame: effect.bounds)
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)

        iconView.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sonus")
        iconView.contentTintColor = NSColor.controlAccentColor
        iconView.imageScaling = .scaleProportionallyUpOrDown

        accentBar.wantsLayer = true
        accentBar.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor

        topGloss.wantsLayer = true
        topGloss.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        topGloss.layer?.cornerRadius = 16
        topGloss.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        messageLabel.font = NSFont.systemFont(ofSize: 12.5)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 3

        startButton.title = titleStart
        startButton.bezelStyle = .rounded
        startButton.controlSize = .small
        startButton.target = nil
        startButton.action = nil

        laterButton.title = titleLater
        laterButton.bezelStyle = .rounded
        laterButton.controlSize = .small
        laterButton.target = nil
        laterButton.action = nil

        closeButton.bezelStyle = .circular
        closeButton.controlSize = .mini
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = nil
        closeButton.action = nil

        [accentBar, topGloss, iconView, titleLabel, messageLabel, startButton, laterButton, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: content.topAnchor),
            accentBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            topGloss.topAnchor.constraint(equalTo: content.topAnchor),
            topGloss.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            topGloss.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            topGloss.heightAnchor.constraint(equalToConstant: 30),

            closeButton.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            iconView.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            iconView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -10),

            messageLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),

            laterButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            laterButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),

            startButton.trailingAnchor.constraint(equalTo: laterButton.leadingAnchor, constant: -10),
            startButton.bottomAnchor.constraint(equalTo: laterButton.bottomAnchor),
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

        // Position like a notification: top-right of the active screen (near the status bar area).
        let screen = statusItem?.button?.window?.screen ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let x = visible.maxX - panelWidth - 16
            let y = visible.maxY - panelHeight - 16
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
