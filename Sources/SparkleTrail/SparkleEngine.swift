import AppKit
import QuartzCore

private final class Sparkle {
    let layer = CAShapeLayer()
    var age: Double = .infinity
    var lifetime: Double = 0.9
    var position: CGPoint = .zero
    var velocity: CGVector = .zero
    var size: CGFloat = 0
    var angle: CGFloat = 0
    var spin: CGFloat = 0

    var isAlive: Bool { age < lifetime }
}

private func between(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
    low + CGFloat.random(in: 0...1) * (high - low)
}

/// Borderless, click-through, all-spaces window that the trail is drawn into.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Owns the sparkle pool and the display link. The pool is grown on demand and
/// then recycled, exactly like the web version: an idle machine never pays for
/// a single layer it has not earned.
final class SparkleView: NSView {
    private let settings: SparkleSettings
    private var pool: [Sparkle] = []
    private var idle: [Sparkle] = []
    private var nextRecycle = 0

    private var link: CADisplayLink?
    private var previousTimestamp: CFTimeInterval = 0
    private var lastCursor: CGPoint?
    private var leftover: CGFloat = 0
    private var aliveCount = 0

    init(settings: SparkleSettings) {
        self.settings = settings
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isFlipped: Bool { false }

    // MARK: - Lifecycle

    func startAnimating() {
        guard link == nil, window != nil else { return }
        let created = displayLink(target: self, selector: #selector(step(_:)))
        previousTimestamp = 0
        lastCursor = nil
        leftover = 0
        created.add(to: .main, forMode: .common)
        link = created
        applyFrameRate(alive: false)
    }

    func stopAnimating() {
        link?.invalidate()
        link = nil
        retireAll()
    }

    private func retireAll() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for sparkle in pool where sparkle.isAlive {
            sparkle.age = .infinity
            sparkle.layer.opacity = 0
            idle.append(sparkle)
        }
        CATransaction.commit()
        aliveCount = 0
    }

    // MARK: - Frame

    @objc private func step(_ sender: CADisplayLink) {
        let now = sender.timestamp
        if previousTimestamp == 0 { previousTimestamp = now }
        let delta = min(now - previousTimestamp, 0.064)
        previousTimestamp = now

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sampleCursor()
        advance(delta)
        CATransaction.commit()

        applyFrameRate(alive: aliveCount > 0)
    }

    private func applyFrameRate(alive: Bool) {
        guard let link else { return }
        link.preferredFrameRateRange = alive
            ? CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
            : CAFrameRateRange(minimum: 10, maximum: 30, preferred: 30)
    }

    private var motionSuppressed: Bool {
        settings.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Polling `NSEvent.mouseLocation` rather than tapping the event stream keeps
    /// the app free of any accessibility prompt. Sparkles are interpolated along
    /// the segment travelled since the last frame so a fast flick still leaves an
    /// evenly spaced trail instead of one lonely star.
    private func sampleCursor() {
        guard settings.isActive, !motionSuppressed else {
            lastCursor = nil
            return
        }
        emitTrail(to: convertToLocal(NSEvent.mouseLocation))
    }

    func emitTrail(to point: CGPoint) {
        guard let last = lastCursor else {
            lastCursor = point
            return
        }
        lastCursor = point

        let dx = point.x - last.x
        let dy = point.y - last.y
        let distance = hypot(dx, dy)
        guard distance > 0.01 else { return }

        let step = settings.spawnDistance
        let budget = min(64, max(1, Int(settings.maxSparkles)))
        var arc = step - leftover
        var placed = 0

        while arc <= distance && placed < budget {
            let fraction = arc / distance
            spawn(at: CGPoint(x: last.x + dx * fraction, y: last.y + dy * fraction))
            arc += step
            placed += 1
        }

        if placed == 0 {
            leftover += distance
        } else if placed == budget {
            leftover = 0
        } else {
            leftover = distance - (arc - step)
        }
    }

    func advance(_ delta: Double) {
        guard !pool.isEmpty else { return }
        let gravity = CGFloat(settings.gravity)
        let globalOpacity = Float(min(max(settings.opacity, 0), 1))
        var alive = 0

        for sparkle in pool {
            guard sparkle.isAlive else { continue }
            sparkle.age += delta
            if !sparkle.isAlive {
                sparkle.layer.opacity = 0
                idle.append(sparkle)
                continue
            }
            alive += 1

            let dt = CGFloat(delta)
            sparkle.velocity.dy -= gravity * dt
            sparkle.position.x += sparkle.velocity.dx * dt
            sparkle.position.y += sparkle.velocity.dy * dt
            sparkle.angle += sparkle.spin * dt

            let t = CGFloat(sparkle.age / sparkle.lifetime)
            let scale = t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8
            sparkle.layer.opacity = Float(1 - t * t) * globalOpacity
            sparkle.layer.position = sparkle.position
            sparkle.layer.setAffineTransform(
                CGAffineTransform(rotationAngle: sparkle.angle * .pi / 180)
                    .scaledBy(x: scale, y: scale))
        }

        aliveCount = alive
        trimPool()
    }

    // MARK: - Pool

    private func acquire() -> Sparkle {
        if let reusable = idle.popLast() { return reusable }

        let limit = max(1, Int(settings.maxSparkles))
        if pool.count < limit {
            let sparkle = Sparkle()
            let layer = sparkle.layer
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.opacity = 0
            layer.contentsScale = window?.backingScaleFactor ?? 2
            layer.actions = [
                "position": NSNull(), "transform": NSNull(), "opacity": NSNull(),
                "bounds": NSNull(), "path": NSNull(), "fillColor": NSNull(),
                "shadowPath": NSNull(), "shadowRadius": NSNull(), "shadowOpacity": NSNull(),
            ]
            self.layer?.addSublayer(layer)
            pool.append(sparkle)
            return sparkle
        }

        let oldest = pool[nextRecycle % pool.count]
        nextRecycle = (nextRecycle + 1) % pool.count
        return oldest
    }

    /// The pool only ever grows, so a lowered "max sparkles" is honoured by
    /// dropping the surplus layers once they have finished burning out.
    private func trimPool() {
        let limit = max(1, Int(settings.maxSparkles))
        guard pool.count > limit else { return }
        var kept: [Sparkle] = []
        kept.reserveCapacity(limit)
        for sparkle in pool {
            if kept.count < limit || sparkle.isAlive {
                kept.append(sparkle)
            } else {
                sparkle.layer.removeFromSuperlayer()
            }
        }
        if kept.count != pool.count {
            pool = kept
            idle.removeAll { $0.layer.superlayer == nil }
            nextRecycle = 0
        }
    }

    private func nextColor() -> NSColor {
        if settings.usesRainbow {
            return NSColor(hue: .random(in: 0...1), saturation: 0.85, brightness: 1, alpha: 1)
        }
        let colors = settings.activeColors
        return colors.randomElement() ?? .white
    }

    private func spawn(at point: CGPoint, velocity: CGVector? = nil) {
        let sparkle = acquire()
        let range = settings.sizeRange
        let size = between(range.lowerBound, range.upperBound)
        let spinLimit = CGFloat(settings.spin)

        sparkle.age = 0
        sparkle.lifetime = max(0.05, settings.lifetime / 1000)
        sparkle.position = point
        sparkle.velocity = velocity ?? CGVector(
            dx: between(-CGFloat(settings.drift), CGFloat(settings.drift)),
            dy: between(-CGFloat(settings.lift) * 0.25, CGFloat(settings.lift)))
        sparkle.size = size
        sparkle.angle = between(0, 360)
        sparkle.spin = between(-spinLimit, spinLimit)

        let layer = sparkle.layer
        let path = scaledPath(size: size)
        layer.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        layer.path = path
        layer.position = point
        layer.fillColor = nextColor().cgColor
        layer.opacity = 0

        if settings.glow {
            layer.shadowPath = path
            layer.shadowColor = layer.fillColor
            layer.shadowOpacity = 0.85
            layer.shadowRadius = size * 0.28
            layer.shadowOffset = .zero
        } else {
            layer.shadowOpacity = 0
        }

        aliveCount += 1
    }

    private var cachedShape: SparkleShape = .star
    private var cachedUnitPath: CGPath = SparkleShape.star.unitPath

    private func scaledPath(size: CGFloat) -> CGPath {
        let shape = settings.shape
        if shape != cachedShape {
            cachedShape = shape
            cachedUnitPath = shape.unitPath
        }
        var transform = CGAffineTransform(scaleX: size, y: size)
        return cachedUnitPath.copy(using: &transform) ?? cachedUnitPath
    }

    // MARK: - Bursts

    func burst(at globalPoint: CGPoint) {
        guard settings.isActive, !motionSuppressed else { return }
        let origin = convertToLocal(globalPoint)
        let count = max(1, Int(settings.burstCount))
        let speed = CGFloat(max(settings.drift, 40)) * 2.4

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for index in 0..<count {
            let angle = (CGFloat(index) / CGFloat(count)) * .pi * 2 + between(-0.2, 0.2)
            let magnitude = speed * between(0.45, 1.15)
            spawn(at: origin, velocity: CGVector(dx: cos(angle) * magnitude,
                                                 dy: sin(angle) * magnitude))
        }
        CATransaction.commit()
        applyFrameRate(alive: true)
    }

    private func convertToLocal(_ globalPoint: CGPoint) -> CGPoint {
        guard let frame = window?.frame else { return globalPoint }
        return CGPoint(x: globalPoint.x - frame.minX, y: globalPoint.y - frame.minY)
    }
}

@MainActor
final class SparkleEngine {
    private let settings: SparkleSettings
    private var window: OverlayWindow?
    private var view: SparkleView?
    private var monitors: [Any] = []
    private var isRunning = false

    init(settings: SparkleSettings) {
        self.settings = settings
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.layoutOverlay() }
            }
    }

    /// Called for every settings change, so it has to be cheap and idempotent.
    func sync() {
        if settings.isActive {
            guard !isRunning else { return }
            isRunning = true
            start()
        } else if isRunning {
            isRunning = false
            stop()
        }
    }

    private func start() {
        if window == nil { buildOverlay() }
        layoutOverlay()
        window?.orderFrontRegardless()
        view?.startAnimating()
        installMonitors()
    }

    private func stop() {
        view?.stopAnimating()
        window?.orderOut(nil)
        removeMonitors()
    }

    private func buildOverlay() {
        let overlay = OverlayWindow(contentRect: Self.desktopFrame(),
                                    styleMask: [.borderless],
                                    backing: .buffered,
                                    defer: false)
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.ignoresMouseEvents = true
        overlay.level = .screenSaver
        overlay.isReleasedWhenClosed = false
        overlay.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                      .fullScreenAuxiliary, .ignoresCycle]
        overlay.displaysWhenScreenProfileChanges = true

        let content = SparkleView(settings: settings)
        content.autoresizingMask = [.width, .height]
        overlay.contentView = content

        window = overlay
        view = content
    }

    private func layoutOverlay() {
        guard let window else { return }
        let frame = Self.desktopFrame()
        if window.frame != frame { window.setFrame(frame, display: false) }
        view?.frame = CGRect(origin: .zero, size: frame.size)
    }

    /// One window spanning the union of every attached display, so the trail
    /// crosses screen boundaries without a seam.
    private static func desktopFrame() -> CGRect {
        let screens = NSScreen.screens
        guard var union = screens.first?.frame else {
            return CGRect(x: 0, y: 0, width: 1440, height: 900)
        }
        for screen in screens.dropFirst() { union = union.union(screen.frame) }
        return union
    }

    // MARK: - Clicks

    private func installMonitors() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.handleClick() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleClick() }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handleClick() {
        guard settings.clickBurst else { return }
        view?.burst(at: NSEvent.mouseLocation)
    }

    private func removeMonitors() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
    }
}
