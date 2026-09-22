import Testing

@testable import SparkleTrail

/// The menu bar panel and the advanced window once declared their own range and
/// format for the same slider, and the two drifted apart: "Largest" ran 6...48
/// in one and 2...48 in the other. These hold the single definition honest.
@Suite("Setting descriptors")
struct SparkleSettingTests {
    private static let all: [SparkleSetting] = [
        .density, .maxSparkles, .lifetime, .minSize, .maxSize, .opacity,
        .gravity, .drift, .lift, .spin, .burstCount,
    ]

    @Test("Every factory value sits inside its own slider range")
    func factoryValuesAreInRange() {
        let factory = SparkleProfile.factory
        for setting in Self.all {
            let value = factory[keyPath: setting.keyPath]
            #expect(setting.range.contains(value),
                    "\(setting.title) factory value \(value) is outside \(setting.range)")
        }
    }

    @Test("No two settings share a title")
    func titlesAreUnique() {
        #expect(Set(Self.all.map(\.title)).count == Self.all.count)
    }

    @Test("No two settings write to the same profile property")
    func keyPathsAreUnique() {
        #expect(Set(Self.all.map(\.keyPath)).count == Self.all.count)
    }

    @Test("Each range is usable and formats at both ends")
    func rangesAreUsable() {
        for setting in Self.all {
            #expect(setting.range.lowerBound < setting.range.upperBound,
                    "\(setting.title) has an empty range")
            #expect(!setting.format(setting.range.lowerBound).isEmpty)
            #expect(!setting.format(setting.range.upperBound).isEmpty)
        }
    }
}
