import CoreGraphics

/// Decides where along the cursor's path a sparkle belongs.
///
/// The cursor is sampled once a frame, so a fast flick arrives as one long
/// segment. Sparkles are spread evenly along it rather than dropped at the end,
/// and `leftover` carries the unused fraction of a step into the next frame so
/// the spacing stays even across frame boundaries instead of restarting at each
/// sample.
struct TrailSpacing {
    private(set) var leftover: CGFloat = 0

    mutating func reset() { leftover = 0 }

    /// - Parameters:
    ///   - spacing: distance between sparkles, always positive.
    ///   - budget: the most points to return, so one enormous jump cannot spawn
    ///     an unbounded number in a single frame.
    mutating func points(from start: CGPoint,
                         to end: CGPoint,
                         spacing: CGFloat,
                         budget: Int) -> [CGPoint] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0.01, spacing > 0, budget > 0 else { return [] }

        var placed: [CGPoint] = []
        var arc = spacing - leftover

        while arc <= distance && placed.count < budget {
            let fraction = arc / distance
            placed.append(CGPoint(x: start.x + dx * fraction, y: start.y + dy * fraction))
            arc += spacing
        }

        if placed.isEmpty {
            leftover += distance
        } else if placed.count == budget {
            leftover = 0
        } else {
            leftover = distance - (arc - spacing)
        }
        return placed
    }
}
