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

            ForEach([SparkleSetting.density, .maxSize, .lifetime], id: \.title) { setting in
                SettingSlider(setting: setting, profile: $settings.profile, showsCaption: false)
            }

            ShapePicker(shapeID: $settings.profile.shapeID)
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

    /// Each swatch previews the palette it selects, not the one in use, so the
    /// grid asks about that palette rather than the live profile.
    private func swatchColors(for palette: SparklePalette) -> [Color] {
        var previewed = settings.profile
        previewed.paletteID = palette.id
        return Palettes.colors(for: previewed).swatches.map(Color.init(nsColor:))
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
