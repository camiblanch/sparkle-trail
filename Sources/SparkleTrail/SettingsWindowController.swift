import AppKit
import SwiftUI

/// SwiftUI's `openWindow` does not reliably surface a `Window` scene from a menu
/// bar extra in an accessory app, so the settings window is owned in AppKit.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    @discardableResult
    func show(settings: SparkleSettings) -> NSWindow {
        let target = window ?? make(settings: settings)
        window = target
        NSApp.activate()
        target.makeKeyAndOrderFront(nil)
        target.orderFrontRegardless()
        return target
    }

    private func make(settings: SparkleSettings) -> NSWindow {
        let hosting = NSHostingController(rootView: AdvancedSettingsView(settings: settings))
        let created = NSWindow(contentViewController: hosting)
        created.title = "Sparkle Trail Settings"
        created.styleMask = [.titled, .closable, .miniaturizable]
        created.isReleasedWhenClosed = false
        created.center()
        return created
    }
}
