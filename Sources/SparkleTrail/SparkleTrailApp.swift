import AppKit
import Combine
import SwiftUI

@main
struct SparkleTrailApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var settings = SparkleSettings.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(settings: settings)
        } label: {
            Image(systemName: MenuBarIcon.name(active: settings.isDrawing))
        }
        .menuBarExtraStyle(.window)
    }
}

enum MenuBarIcon {
    /// SF Symbol availability moves between OS releases; fall back rather than
    /// showing an empty menu bar slot.
    static func name(active: Bool) -> String {
        let candidates = active
            ? ["sparkles", "wand.and.stars", "star.fill"]
            : ["sparkle", "wand.and.stars.inverse", "star"]
        for candidate in candidates
        where NSImage(systemSymbolName: candidate, accessibilityDescription: nil) != nil {
            return candidate
        }
        return active ? "star.fill" : "star"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: SparkleEngine?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settings = SparkleSettings.shared
        let engine = SparkleEngine(settings: settings)
        self.engine = engine
        engine.sync()

        // Published values are still the old ones inside objectWillChange, so the
        // engine is re-synced on the next turn of the run loop.
        cancellable = settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { _ in engine.sync() }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
