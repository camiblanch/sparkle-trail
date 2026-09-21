import AppKit
import Combine

/// Drives the shared macOS colour panel.
///
/// The menu bar popover closes the moment the colour panel takes key focus,
/// which tears down any `ColorPicker` living inside it. This controller is a
/// singleton, so the panel keeps writing colours back to the settings after the
/// popover has gone away.
@MainActor
final class ColorPanelController: NSObject, ObservableObject {
    static let shared = ColorPanelController()

    /// Identifies the colour the panel currently edits, or nil when it is idle.
    @Published private(set) var activeToken: String?

    private var apply: ((NSColor) -> Void)?

    // Reading `NSColorPanel.shared` builds the panel window. A view reads this
    // singleton while SwiftUI evaluates its body, and building a window inside
    // a view update re-enters NSView layout and aborts, so `init` must not
    // touch the panel. The observer therefore covers every window and filters,
    // and the members below build the panel only on a user action.
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelWillClose),
            name: NSWindow.willCloseNotification,
            object: nil)
    }

    /// Opens the panel on `color`, or closes it again if `token` already owns it.
    func present(token: String, color: NSColor, apply: @escaping (NSColor) -> Void) {
        let alreadyOpen = token == activeToken
            && NSColorPanel.sharedColorPanelExists
            && NSColorPanel.shared.isVisible
        if alreadyOpen {
            close()
            return
        }

        self.apply = apply
        activeToken = token

        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange))
        panel.color = color

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        reset()
        guard NSColorPanel.sharedColorPanelExists else { return }
        NSColorPanel.shared.setTarget(nil)
        NSColorPanel.shared.setAction(nil)
        NSColorPanel.shared.close()
    }

    private func reset() {
        apply = nil
        activeToken = nil
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        // The panel's pattern and image tabs hand back colours with no RGB
        // components, and reading those would trap.
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        apply?(rgb)
    }

    @objc private func panelWillClose(_ notification: Notification) {
        guard notification.object is NSColorPanel else { return }
        reset()
    }
}
