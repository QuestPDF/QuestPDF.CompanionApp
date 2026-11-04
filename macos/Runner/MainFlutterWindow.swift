import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    // Height of the title bar drawn by Flutter; the native window buttons are centered within it
    private let titleBarHeight: CGFloat = 44

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        // Hide titlebar and make window resizable
        self.styleMask.insert(.fullSizeContentView)
        self.styleMask.insert(.resizable)
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        // Make the window movable by its background
        self.isMovableByWindowBackground = true

        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()

        // AppKit restores the default button layout on these events, so the position is applied again
        let layoutEvents: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
        ]

        for event in layoutEvents {
            NotificationCenter.default.addObserver(
                self, selector: #selector(centerWindowButtons), name: event, object: self)
        }

        DispatchQueue.main.async { self.centerWindowButtons() }
    }

    // Grows the titlebar container to the Flutter title bar height and centers the buttons inside it,
    // keeping the same distance from the top and the leading edge
    @objc private func centerWindowButtons() {
        if styleMask.contains(.fullScreen) { return }

        guard
            let closeButton = standardWindowButton(.closeButton),
            let miniaturizeButton = standardWindowButton(.miniaturizeButton),
            let zoomButton = standardWindowButton(.zoomButton),
            let titleBarContainer = closeButton.superview?.superview
        else { return }

        let buttonWidth = closeButton.frame.width
        let buttonSpacing = miniaturizeButton.frame.minX - closeButton.frame.maxX
        let margin = (titleBarHeight - closeButton.frame.height) / 2

        var containerFrame = titleBarContainer.frame
        containerFrame.size.height = titleBarHeight
        containerFrame.origin.y = frame.height - titleBarHeight
        titleBarContainer.frame = containerFrame

        for (index, button) in [closeButton, miniaturizeButton, zoomButton].enumerated() {
            let x = margin + CGFloat(index) * (buttonWidth + buttonSpacing)
            button.setFrameOrigin(NSPoint(x: x, y: margin))
        }
    }
}
