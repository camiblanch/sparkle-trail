import SwiftUI

/// A slider driven by a `SparkleSetting`, so both windows read the same range
/// and the same formatted value.
struct SettingSlider: View {
    let setting: SparkleSetting
    @Binding var profile: SparkleProfile
    /// The menu bar panel is too small to carry the explanations.
    var showsCaption = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(setting.title).font(.caption)
                Spacer()
                Text(setting.format(value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: setting.range)
            if showsCaption, let caption = setting.caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var value: Binding<Double> { $profile[dynamicMember: setting.keyPath] }
}

struct ShapePicker: View {
    @Binding var shapeID: String

    var body: some View {
        Picker("Shape", selection: $shapeID) {
            ForEach(SparkleShape.allCases) { shape in
                Text(shape.label).tag(shape.rawValue)
            }
        }
    }
}

struct PaletteSchemePicker: View {
    @Binding var paletteID: String

    var body: some View {
        Picker("Colour scheme", selection: $paletteID) {
            ForEach(Palettes.builtIn) { palette in
                Text(palette.name).tag(palette.id)
            }
        }
    }
}
