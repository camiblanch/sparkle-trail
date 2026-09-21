import AppKit
import ServiceManagement
import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SparkleSettings

    var body: some View {
        Form {
            Section("Profiles") {
                ProfilesSection(settings: settings)
            }

            Section("Trail") {
                slider("Amount", $settings.profile.density, 0...1,
                       caption: "How often a sparkle appears as the cursor moves.") {
                    "\(Int($0 * 100))%"
                }
                slider("Maximum sparkles", $settings.profile.maxSparkles, 25...1500,
                       caption: "The most that can be on screen at once. Raise it if fast movement looks thin.") {
                    "\(Int($0))"
                }
                slider("Lifetime", $settings.profile.lifetime, 250...3000,
                       caption: "How long each sparkle lasts before it fades out.") {
                    String(format: "%.2f s", $0 / 1000)
                }
                slider("Smallest", $settings.profile.minSize, 2...48,
                       caption: "Each sparkle takes a random size between these two.") {
                    "\(Int($0)) pt"
                }
                slider("Largest", $settings.profile.maxSize, 2...48) { "\(Int($0)) pt" }
                slider("Opacity", $settings.profile.opacity, 0.1...1) { "\(Int($0 * 100))%" }
            }

            Section("Motion") {
                slider("Gravity", $settings.profile.gravity, -400...900,
                       caption: "Below zero, sparkles rise instead of falling.") {
                    "\(Int($0))"
                }
                slider("Sideways drift", $settings.profile.drift, 0...240,
                       caption: "Each sparkle gets a random sideways speed up to this.") {
                    "\(Int($0))"
                }
                slider("Upward kick", $settings.profile.lift, 0...240,
                       caption: "Each sparkle gets a random upward speed up to this.") {
                    "\(Int($0))"
                }
                slider("Spin", $settings.profile.spin, 0...900,
                       caption: "Each sparkle gets a random spin rate up to this, either direction.") {
                    "\(Int($0))°/s"
                }
            }

            Section("Appearance") {
                Picker("Shape", selection: $settings.profile.shapeID) {
                    ForEach(SparkleShape.allCases) { shape in
                        Text(shape.label).tag(shape.rawValue)
                    }
                }
                Picker("Colour scheme", selection: $settings.profile.paletteID) {
                    ForEach(Palettes.builtIn) { palette in
                        Text(palette.name).tag(palette.id)
                    }
                }
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
                    slider("Burst size", $settings.profile.burstCount, 4...60) { "\(Int($0))" }
                }
                Toggle("Pause when Reduce Motion is on", isOn: $settings.respectReduceMotion)
                LaunchAtLoginToggle()
            }

            Section {
                HStack {
                    Button("Restore Defaults") { settings.restoreDefaults() }
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

    private func slider(_ title: String,
                        _ value: Binding<Double>,
                        _ range: ClosedRange<Double>,
                        caption: String? = nil,
                        display: @escaping (Double) -> String) -> some View {
        LabelledSlider(title: title, value: value, range: range,
                       display: display, caption: caption)
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
