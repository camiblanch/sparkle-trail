import AppKit
import SwiftUI

/// One to six colours, edited either by colour well or by typing a hex value.
struct CustomColorEditor: View {
    @ObservedObject var settings: SparkleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(settings.customHexes.indices), id: \.self) { index in
                HStack(spacing: 8) {
                    ColorPicker("", selection: colorBinding(at: index), supportsOpacity: false)
                        .labelsHidden()
                    HexField(hex: hexBinding(at: index))
                    Spacer(minLength: 0)
                    Button {
                        settings.customHexes.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(settings.customHexes.count <= 1)
                    .help("Remove this colour")
                }
            }

            HStack {
                Button {
                    settings.customHexes.append(nextColorHex())
                } label: {
                    Label("Add colour", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(settings.customHexes.count >= Palettes.maxCustomColors)

                Spacer()
                Text("\(settings.customHexes.count)/\(Palettes.maxCustomColors)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func nextColorHex() -> String {
        let hue = Double(settings.customHexes.count) / Double(Palettes.maxCustomColors)
        return NSColor(hue: hue, saturation: 0.7, brightness: 1, alpha: 1).hexString
    }

    private func hexBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { settings.customHexes.indices.contains(index) ? settings.customHexes[index] : "#ffffff" },
            set: { newValue in
                guard settings.customHexes.indices.contains(index) else { return }
                settings.customHexes[index] = newValue
            })
    }

    private func colorBinding(at index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard settings.customHexes.indices.contains(index),
                      let color = NSColor(hex: settings.customHexes[index]) else { return .white }
                return Color(nsColor: color)
            },
            set: { newValue in
                guard settings.customHexes.indices.contains(index) else { return }
                settings.customHexes[index] = NSColor(newValue).hexString
            })
    }
}

struct HexField: View {
    @Binding var hex: String
    @State private var text = ""

    var body: some View {
        TextField("#rrggbb", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(.caption.monospaced())
            .frame(width: 82)
            .onAppear { text = hex }
            .onChange(of: hex) { _, updated in
                if NSColor(hex: text)?.hexString != updated { text = updated }
            }
            .onChange(of: text) { _, typed in
                if let parsed = NSColor(hex: typed) { hex = parsed.hexString }
            }
            .onSubmit { text = hex }
    }
}
