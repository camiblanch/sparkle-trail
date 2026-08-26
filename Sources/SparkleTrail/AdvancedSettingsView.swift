import AppKit
import ServiceManagement
import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SparkleSettings

    var body: some View {
        Form {
            Section("Trail") {
                slider("Amount", $settings.density, 0...1) { "\(Int($0 * 100))%" }
                slider("Maximum sparkles", $settings.maxSparkles, 25...1500) { "\(Int($0))" }
                slider("Lifetime", $settings.lifetime, 250...3000) { String(format: "%.2f s", $0 / 1000) }
                slider("Smallest", $settings.minSize, 2...48) { "\(Int($0)) pt" }
                slider("Largest", $settings.maxSize, 2...48) { "\(Int($0)) pt" }
                slider("Opacity", $settings.opacity, 0.1...1) { "\(Int($0 * 100))%" }
            }

            Section("Motion") {
                slider("Gravity", $settings.gravity, -400...900) { "\(Int($0))" }
                slider("Sideways drift", $settings.drift, 0...240) { "\(Int($0))" }
                slider("Upward kick", $settings.lift, 0...240) { "\(Int($0))" }
                slider("Spin", $settings.spin, 0...900) { "\(Int($0))°/s" }
            }

            Section("Appearance") {
                Picker("Shape", selection: $settings.shapeID) {
                    ForEach(SparkleShape.allCases) { shape in
                        Text(shape.label).tag(shape.rawValue)
                    }
                }
                Picker("Colour scheme", selection: $settings.paletteID) {
                    ForEach(Palettes.builtIn) { palette in
                        Text(palette.name).tag(palette.id)
                    }
                }
                Toggle("Glow", isOn: $settings.glow)
            }

            if settings.paletteID == Palettes.customID {
                Section("Custom colours") {
                    CustomColorEditor(settings: settings)
                }
            }

            Section("Behaviour") {
                Toggle("Burst on click", isOn: $settings.clickBurst)
                if settings.clickBurst {
                    slider("Burst size", $settings.burstCount, 4...60) { "\(Int($0))" }
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
                        display: @escaping (Double) -> String) -> some View {
        LabelledSlider(title: title, value: value, range: range, display: display)
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
