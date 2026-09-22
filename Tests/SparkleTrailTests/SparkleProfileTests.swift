import Foundation
import Testing

@testable import SparkleTrail

private func isolatedDefaults(_ name: String = #function) -> UserDefaults {
    let suite = "sparkletrail.tests.\(name).\(UUID().uuidString)"
    UserDefaults.standard.removePersistentDomain(forName: suite)
    return UserDefaults(suiteName: suite)!
}

private func hexes(_ count: Int) -> [String] {
    (0..<count).map { String(format: "#%02x0000", $0 + 1) }
}

@Suite("Custom colour limit")
struct CustomColorLimitTests {
    @Test("Drops the colours past the limit")
    func clampsAboveLimit() {
        var profile = SparkleProfile.factory
        profile.customHexes = hexes(Palettes.maxCustomColors + 3)

        let clamped = profile.clampingCustomColorCount()

        #expect(clamped.customHexes == hexes(Palettes.maxCustomColors))
    }

    @Test("Leaves a list at or below the limit alone")
    func keepsAllowedCounts() {
        for count in 1...Palettes.maxCustomColors {
            var profile = SparkleProfile.factory
            profile.customHexes = hexes(count)

            #expect(profile.clampingCustomColorCount() == profile)
        }
    }
}

@Suite("Profile persistence")
struct ProfilePersistenceTests {
    @Test("A written profile reads back unchanged")
    func roundTripsThroughUserDefaults() {
        let defaults = isolatedDefaults()
        var profile = SparkleProfile.factory
        profile.density = 0.42
        profile.shapeID = SparkleShape.heart.rawValue
        profile.customHexes = ["#123456", "#abcdef"]
        profile.glow = false

        profile.write(to: defaults)

        #expect(SparkleProfile(from: defaults) == profile)
    }

    @Test("Missing keys fall back to the factory value")
    func fallsBackPerKey() {
        let defaults = isolatedDefaults()
        defaults.set(0.1, forKey: "density")

        let loaded = SparkleProfile(from: defaults)

        #expect(loaded.density == 0.1)
        #expect(loaded.maxSparkles == SparkleProfile.factory.maxSparkles)
        #expect(loaded.shapeID == SparkleProfile.factory.shapeID)
    }
}

@Suite("Settings persistence")
@MainActor
struct SettingsPersistenceTests {
    @Test("Applying an over-long colour list clamps it and persists the clamp")
    func appliedColorsAreClampedAndPersisted() {
        let defaults = isolatedDefaults()
        let settings = SparkleSettings(store: defaults)

        var tooMany = SparkleProfile.factory
        tooMany.customHexes = hexes(Palettes.maxCustomColors + 3)
        settings.replaceProfile(with: tooMany)

        #expect(settings.profile.customHexes == hexes(Palettes.maxCustomColors))
        #expect(SparkleSettings(store: defaults).profile.customHexes
            == hexes(Palettes.maxCustomColors))
    }

    /// Stored defaults from an older release can hold more colours than the
    /// editor now allows.
    @Test("An over-long colour list in stored defaults is clamped on load")
    func storedColorsAreClampedOnLoad() {
        let defaults = isolatedDefaults()
        var tooMany = SparkleProfile.factory
        tooMany.customHexes = hexes(Palettes.maxCustomColors + 3)
        tooMany.write(to: defaults)

        #expect(SparkleSettings(store: defaults).profile.customHexes
            == hexes(Palettes.maxCustomColors))
    }

    /// `profile` is `@Published`, so it is a computed property and assigning to
    /// it inside its own `didSet` recurses instead of being suppressed.
    @Test("An ordinary edit persists without re-entering its own observer")
    func ordinaryEditPersists() {
        let defaults = isolatedDefaults()
        let settings = SparkleSettings(store: defaults)

        settings.profile.density = 0.33

        #expect(SparkleSettings(store: defaults).profile.density == 0.33)
    }

    @Test("Replacing the look can be undone")
    func replaceProfileIsUndoable() {
        let defaults = isolatedDefaults()
        let settings = SparkleSettings(store: defaults)
        let original = settings.profile

        var replacement = SparkleProfile.factory
        replacement.spin = 12
        settings.replaceProfile(with: replacement)
        #expect(settings.profile == replacement)

        settings.undoLastChange()
        #expect(settings.profile == original)
    }
}
