import AppKit
import ServiceManagement
import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SparkleSettings
    @ObservedObject private var store = ProfileStore.shared

    var body: some View {
        Form {
            Section("Profiles") {
                ProfilesSection(settings: settings)
            }

            Section("Trail") {
                sliders(.density, .maxSparkles, .lifetime, .minSize, .maxSize, .opacity)
            }

            Section("Motion") {
                sliders(.gravity, .drift, .lift, .spin)
            }

            Section("Appearance") {
                ShapePicker(shapeID: $settings.profile.shapeID)
                PaletteSchemePicker(paletteID: $settings.profile.paletteID)
                Toggle("Glow", isOn: $settings.profile.glow)
            }

            if settings.profile.paletteID == Palettes.customID {
                Section("Custom colours") {
                    CustomColorEditor(settings: settings)
                }
            }

            Section("Behaviour") {
                Toggle("Burst on click", isOn: $settings.profile.clickBurst)
                if settings.profile.clickBurst {
                    sliders(.burstCount)
                }
                Toggle("Pause when Reduce Motion is on", isOn: $settings.respectReduceMotion)
                LaunchAtLoginToggle()
            }

            Section {
                HStack {
                    Button("Restore Defaults", action: confirmRestoreDefaults)
                    Button("Undo Last Change") { settings.undoLastChange() }
                        .disabled(settings.undoStack.isEmpty)
                    Spacer()
                    Button(settings.isActive ? "Pause Trail" : "Resume Trail") {
                        settings.isActive.toggle()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: Self.height)
    }

    /// Tall enough for the whole form, but never taller than the screen.
    private static var height: CGFloat {
        min(640, (NSScreen.main?.visibleFrame.height ?? 800) - 60)
    }

    private var currentLookIsSaved: Bool {
        store.profiles.contains { $0.profile == settings.profile }
    }

    private func confirmRestoreDefaults() {
        let detail = currentLookIsSaved
            ? "Your saved profiles are not affected."
            : "The current settings are not saved to any profile. Undo Last Change can put them back."
        guard Alerts.confirmDestructive("Restore the default settings?",
                                        detail: detail,
                                        confirm: "Restore Defaults") else { return }
        settings.restoreDefaults()
    }

    private func sliders(_ settingList: SparkleSetting...) -> some View {
        ForEach(settingList, id: \.title) { setting in
            SettingSlider(setting: setting, profile: $settings.profile)
        }
    }
}

struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Open at login", isOn: $enabled)
                .onChange(of: enabled) { _, newValue in apply(newValue) }
            if let failure {
                Text(failure).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func apply(_ newValue: Bool) {
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            failure = nil
        } catch {
            // Only a signed, bundled copy can register; the raw debug binary cannot.
            failure = "Login item unavailable: \(error.localizedDescription)"
            enabled = SMAppService.mainApp.status == .enabled
        }
    }
}
