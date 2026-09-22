import AppKit

/// The app's modal alerts. `NSAlert` is used rather than a SwiftUI alert so a
/// confirmation still works from the menu bar panel, which closes as soon as a
/// sheet takes focus.
enum Alerts {
    /// Returns true when the user confirms.
    static func confirmDestructive(_ message: String,
                                   detail: String,
                                   confirm: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func report(_ error: Error, title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
