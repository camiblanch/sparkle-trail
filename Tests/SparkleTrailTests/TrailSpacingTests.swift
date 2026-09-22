import CoreGraphics
import Testing

@testable import SparkleTrail

@Suite("Trail spacing")
struct TrailSpacingTests {
    private func line(_ spacing: inout TrailSpacing,
                      length: CGFloat,
                      step: CGFloat,
                      budget: Int = 64,
                      from x: CGFloat = 0) -> [CGPoint] {
        spacing.points(from: CGPoint(x: x, y: 0),
                       to: CGPoint(x: x + length, y: 0),
                       spacing: step,
                       budget: budget)
    }

    @Test("Spaces sparkles evenly along the segment")
    func evenSpacing() {
        var spacing = TrailSpacing()
        let points = line(&spacing, length: 100, step: 10)

        #expect(points.count == 10)
        for (index, point) in points.enumerated() {
            #expect(abs(point.x - CGFloat(index + 1) * 10) < 0.001)
        }
    }

    @Test("Carries the unused fraction into the next segment")
    func carriesLeftover() {
        var spacing = TrailSpacing()

        // Three segments of 5pt with a 10pt step: one sparkle at the 10pt mark.
        let first = line(&spacing, length: 5, step: 10, from: 0)
        let second = line(&spacing, length: 5, step: 10, from: 5)
        let third = line(&spacing, length: 5, step: 10, from: 10)

        #expect(first.isEmpty)
        #expect(second.count == 1)
        #expect(abs(second[0].x - 10) < 0.001)
        #expect(third.isEmpty)
    }

    /// Without the carry, a slow drag sampled as many short segments would
    /// never reach the step distance and would draw nothing at all.
    @Test("A slow drag still draws")
    func slowDragDraws() {
        var spacing = TrailSpacing()
        var total = 0
        for step in 0..<100 {
            total += line(&spacing, length: 1, step: 10, from: CGFloat(step)).count
        }

        #expect(total == 10)
    }

    @Test("Never returns more than the budget")
    func respectsBudget() {
        var spacing = TrailSpacing()
        let points = line(&spacing, length: 10_000, step: 1, budget: 64)

        #expect(points.count == 64)
    }

    @Test("A capped segment drops its leftover rather than banking it")
    func cappedSegmentResetsLeftover() {
        var spacing = TrailSpacing()
        _ = line(&spacing, length: 10_000, step: 1, budget: 4)

        #expect(spacing.leftover == 0)
    }

    @Test("Ignores a still cursor and nonsense input")
    func ignoresDegenerateInput() {
        var spacing = TrailSpacing()

        #expect(line(&spacing, length: 0, step: 10).isEmpty)
        #expect(line(&spacing, length: 100, step: 0).isEmpty)
        #expect(line(&spacing, length: 100, step: 10, budget: 0).isEmpty)
    }

    @Test("Reset clears the carry")
    func resetClearsCarry() {
        var spacing = TrailSpacing()
        _ = line(&spacing, length: 9, step: 10)
        #expect(spacing.leftover > 0)

        spacing.reset()
        #expect(spacing.leftover == 0)
    }

    @Test("Spacing follows the segment's direction")
    func followsDirection() {
        var spacing = TrailSpacing()
        let points = spacing.points(from: CGPoint(x: 0, y: 0),
                                    to: CGPoint(x: 0, y: -30),
                                    spacing: 10,
                                    budget: 64)

        #expect(points.count == 3)
        #expect(abs(points[0].y + 10) < 0.001)
        #expect(abs(points[2].y + 30) < 0.001)
    }
}
