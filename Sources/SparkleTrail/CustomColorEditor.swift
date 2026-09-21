import AppKit
import SwiftUI

/// One to six colours, edited either by the macOS colour picker or by typing a
/// hex value.
struct CustomColorEditor: View {
    @ObservedObject var settings: SparkleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(settings.profile.customHexes.indices), id: \.self) { index in
                HStack(spacing: 8) {
                    ColorPanelWell(token: "custom-\(index)",
                                   color: color(at: index),
                                   apply: { setColor($0, at: index) })
                    HexField(hex: hexBinding(at: index))
                    Spacer(minLength: 0)
                    Button {
                        // Removing shifts every later colour down an index, so
                        // the open panel would start editing the wrong slot.
                        ColorPanelController.shared.close()
                        settings.profile.customHexes.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(settings.profile.customHexes.count <= 1)
                    .help("Remove this colour")
                }
            }

            HStack {
                Button {
                    settings.profile.customHexes.append(nextColorHex())
                } label: {
                    Label("Add colour", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(settings.profile.customHexes.count >= Palettes.maxCustomColors)

                Spacer()
                Text("\(settings.profile.customHexes.count)/\(Palettes.maxCustomColors)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func nextColorHex() -> String {
        let hue = Double(settings.profile.customHexes.count) / Double(Palettes.maxCustomColors)
        return NSColor(hue: hue, saturation: 0.7, brightness: 1, alpha: 1).hexString
    }

    private func hexBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { settings.profile.customHexes.indices.contains(index) ? settings.profile.customHexes[index] : "#ffffff" },
            set: { newValue in
                guard settings.profile.customHexes.indices.contains(index) else { return }
                settings.profile.customHexes[index] = newValue
            })
    }

    private func color(at index: Int) -> NSColor {
        guard settings.profile.customHexes.indices.contains(index),
              let color = NSColor(hex: settings.profile.customHexes[index]) else { return .white }
        return color
    }

    private func setColor(_ color: NSColor, at index: Int) {
        guard settings.profile.customHexes.indices.contains(index) else { return }
        settings.profile.customHexes[index] = color.hexString
    }
}

/// A colour swatch that opens the macOS colour panel when clicked.
struct ColorPanelWell: View {
    let token: String
    let color: NSColor
    let apply: (NSColor) -> Void

    @ObservedObject private var controller = ColorPanelController.shared

    var body: some View {
        Button {
            controller.present(token: token, color: color, apply: apply)
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(nsColor: color))
                .frame(width: 44, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(isOpen ? Color.accentColor : Color.primary.opacity(0.25),
                                      lineWidth: isOpen ? 2.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .help(isOpen ? "Close the colour picker" : "Pick this colour with the macOS colour picker")
    }

    private var isOpen: Bool { controller.activeToken == token }
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
