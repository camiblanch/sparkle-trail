import AppKit
import Testing

@testable import SparkleTrail

@Suite("Palette resolution")
struct PaletteResolutionTests {
    private func profile(paletteID: String, customHexes: [String] = []) -> SparkleProfile {
        var profile = SparkleProfile.factory
        profile.paletteID = paletteID
        profile.customHexes = customHexes
        return profile
    }

    @Test("A built-in palette resolves to its own swatches")
    func builtInPalette() {
        let gold = Palettes.palette(id: "gold")
        let colors = Palettes.colors(for: profile(paletteID: "gold"))

        #expect(colors.swatches == gold.swatches)
    }

    @Test("An unknown palette ID falls back to the first palette")
    func unknownPalette() {
        let colors = Palettes.colors(for: profile(paletteID: "no-such-palette"))

        #expect(colors.swatches == Palettes.builtIn[0].swatches)
    }

    @Test("Custom resolves to the profile's own hexes")
    func customPalette() {
        let colors = Palettes.colors(for: profile(paletteID: Palettes.customID,
                                                  customHexes: ["#ff0000", "#00ff00"]))

        #expect(colors.swatches == [NSColor(hex: "#ff0000"), NSColor(hex: "#00ff00")])
    }

    /// A sparkle with no readable colour would be invisible.
    @Test("An unreadable custom list falls back to white")
    func unreadableCustomPalette() {
        let colors = Palettes.colors(for: profile(paletteID: Palettes.customID,
                                                  customHexes: ["nonsense", ""]))

        #expect(colors.swatches == [.white])
    }

    @Test("Rainbow is a case of its own, not a fixed list")
    func rainbowPalette() {
        let colors = Palettes.colors(for: profile(paletteID: Palettes.rainbowID))

        guard case .rainbow = colors else {
            Issue.record("expected .rainbow, got \(colors)")
            return
        }
        #expect(colors.swatches.count == Palettes.maxCustomColors)
        #expect(Set(colors.swatches).count == Palettes.maxCustomColors)
    }

    @Test("Every palette yields at least one colour to draw with")
    func everyPaletteDraws() {
        for palette in Palettes.builtIn {
            let colors = Palettes.colors(for: profile(paletteID: palette.id,
                                                      customHexes: SparkleProfile.factory.customHexes))
            #expect(!colors.swatches.isEmpty, "\(palette.id) resolved to nothing")
        }
    }
}

@Suite("Hex colours")
struct HexColorTests {
    @Test("Reads three- and six-digit hex, with or without a hash")
    func parsesValidHex() {
        #expect(NSColor(hex: "#ffffff")?.hexString == "#ffffff")
        #expect(NSColor(hex: "ffffff")?.hexString == "#ffffff")
        #expect(NSColor(hex: "#fff")?.hexString == "#ffffff")
        #expect(NSColor(hex: "  #1a2b3c  ")?.hexString == "#1a2b3c")
    }

    @Test("Rejects anything else")
    func rejectsInvalidHex() {
        for text in ["", "#", "#12", "#12345", "#1234567", "#gggggg", "hello"] {
            #expect(NSColor(hex: text) == nil, "\(text) should not parse")
        }
    }

    @Test("A parsed colour round trips through its hex string")
    func roundTrips() {
        for hex in Palettes.builtIn.flatMap(\.hexes) {
            #expect(NSColor(hex: hex)?.hexString == hex.lowercased())
        }
    }
}
