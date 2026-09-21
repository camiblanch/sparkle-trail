import AppKit
import SwiftUI

struct MenuPanel: View {
    @ObservedObject var settings: SparkleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            ProfileMenu(settings: settings)

            Divider()

            PaletteGrid(settings: settings)

            if settings.profile.paletteID == Palettes.customID {
                CustomColorEditor(settings: settings)
            }

            LabelledSlider(title: "Amount", value: $settings.profile.density, range: 0...1,
                           display: { "\(Int($0 * 100))%" })
            LabelledSlider(title: "Largest", value: $settings.profile.maxSize, range: 6...48,
                           display: { "\(Int($0)) pt" })
            LabelledSlider(title: "Lifetime", value: $settings.profile.lifetime, range: 250...3000,
                           display: { String(format: "%.1f s", $0 / 1000) })

            Picker("Shape", selection: $settings.profile.shapeID) {
                ForEach(SparkleShape.allCases) { shape in
                    Text(shape.label).tag(shape.rawValue)
                }
            }
            .pickerStyle(.menu)

            Toggle("Glow", isOn: $settings.profile.glow)
            Toggle("Burst on click", isOn: $settings.profile.clickBurst)

            Divider()

            HStack {
                Button("Advanced…") { SettingsWindowController.shared.show(settings: settings) }
                    .help("All motion, size and behaviour settings")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .toggleStyle(.switch)
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Sparkle Trail").font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $settings.isActive)
                .labelsHidden()
                .accessibilityLabel("Sparkle trail")
        }
    }

    /// Reduce Motion stops the trail without switching it off, so that state
    /// needs saying. Reporting "Following your cursor" while nothing draws
    /// reads as a broken app.
    private var status: String {
        if !settings.isActive { return "Paused" }
        if settings.motionSuppressed { return "Held back by Reduce Motion" }
        return "Following your cursor"
    }
}

struct LabelledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var display: (Double) -> String
    /// Only the controls whose effect is not obvious carry one. Captioning
    /// every slider would bury the few that need the explanation.
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text(display(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PaletteGrid: View {
    @ObservedObject var settings: SparkleSettings

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Colour scheme").font(.caption)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Palettes.builtIn) { palette in
                    Button {
                        settings.profile.paletteID = palette.id
                    } label: {
                        Swatch(colors: swatchColors(for: palette),
                               selected: settings.profile.paletteID == palette.id)
                    }
                    .buttonStyle(.plain)
                    .help(palette.name)
                }
            }
            Text(settings.palette.name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func swatchColors(for palette: SparklePalette) -> [Color] {
        switch palette.id {
        case Palettes.rainbowID:
            return (0..<6).map { Color(hue: Double($0) / 6, saturation: 0.85, brightness: 1) }
        case Palettes.customID:
            let colors = settings.profile.customHexes.compactMap(NSColor.init(hex:)).map(Color.init(nsColor:))
            return colors.isEmpty ? [Color(nsColor: .quaternaryLabelColor)] : colors
        default:
            return palette.swatches.map(Color.init(nsColor:))
        }
    }
}

struct Swatch: View {
    let colors: [Color]
    let selected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: colors.isEmpty ? [.gray] : colors,
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.black.opacity(0.12),
                                  lineWidth: selected ? 2.5 : 1)
            )
    }
}
