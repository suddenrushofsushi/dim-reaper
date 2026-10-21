import AppKit

@MainActor
final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    private let id: Overlay.ID
    private weak var store: OverlayStore?
    private let tintView: MetalTintView

    init(overlay: Overlay, store: OverlayStore) {
        self.id = overlay.id
        self.store = store
        self.tintView = MetalTintView(frame: CGRect(origin: .zero, size: overlay.frame.size))

        let panel = OverlayPanel(
            contentRect: overlay.frame,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)

        panel.delegate = self
        panel.contentView = tintView
        tintView.setOpacity(overlay.opacity)
        apply(overlay)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(_ overlay: Overlay) {
        guard let window else { return }
        if window.frame != overlay.frame {
            window.setFrame(overlay.frame, display: true, animate: false)
        }
        window.isMovable = !overlay.locked
        tintView.setOpacity(overlay.opacity)
        // Resize the metal view's drawable to track the window's content size.
        tintView.frame = window.contentView?.bounds ?? tintView.frame
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) { reportFrame() }
    func windowDidResize(_ notification: Notification) {
        reportFrame()
        tintView.frame = window?.contentView?.bounds ?? tintView.frame
    }

    private func reportFrame() {
        guard let frame = window?.frame else { return }
        store?.handleFrameChange(id: id, frame: frame)
    }
}

/// Borderless floating panel that sits above normal windows on every Space.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false

        // Sit above normal app windows but below system UI like the menu bar.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))

        // Show on every Space, survive full-screen transitions, don't appear in window cycling.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }
}
