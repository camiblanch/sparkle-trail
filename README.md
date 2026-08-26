# Sparkle Trail

A macOS menu bar app that trails sparkles behind the mouse cursor, ported from
the DOM version in [`reference/sparkle-cursor.js`](reference/sparkle-cursor.js).
Same physics — pooled sparkles, gravity, spin, grow-then-fade — drawn with Core
Animation layers in a click-through overlay window that spans every display.

## Download

Grab [`dist/SparkleTrail.zip`](dist/SparkleTrail.zip) — click it on GitHub, then
**Download raw file**. Unzip it and drag `Sparkle Trail.app` to `/Applications`.
Universal binary (Apple Silicon and Intel), macOS 14 or later, about 250 KB.

The app is signed ad hoc rather than with a Developer ID, so Gatekeeper will
refuse the first launch of a downloaded copy. Either:

- open **System Settings → Privacy & Security**, scroll to the message about
  Sparkle Trail and click **Open Anyway**; or
- clear the quarantine flag yourself:

  ```sh
  xattr -dr com.apple.quarantine "/Applications/Sparkle Trail.app"
  ```

Nothing else is needed — the app asks for no permissions at all. It has no dock
icon; look for the sparkles in the menu bar.

## Build from source

Requires macOS 14+ and the Xcode Command Line Tools (a full Xcode install is
not needed).

```sh
./build.sh          # produces build/Sparkle Trail.app for this Mac
make run            # build, then launch it
make install        # copy to /Applications and launch
make uninstall      # quit and remove from /Applications
make universal      # arm64 + x86_64 build
make dist           # universal build, packaged as dist/SparkleTrail.zip
```

`make dist` regenerates the committed download; run it and commit the zip
whenever the app changes. It cross-compiles the second architecture and `lipo`s
the slices together, because SwiftPM's own `--arch` needs xcbuild, which ships
with Xcode rather than the Command Line Tools.

No permission prompts: the cursor is read with `NSEvent.mouseLocation` polling
rather than an event tap, so there is nothing to approve in System Settings.

## Menu bar

The icon is always present while the app runs — filled sparkles when the trail
is active, a single outline sparkle when it is paused. Clicking it opens a panel
with the switch, the colour schemes, and the controls reached for most often.
`Advanced…` opens the full settings window, an AppKit-owned window rather than a
SwiftUI `Window` scene, which does not reliably open from a menu bar extra in an
accessory app.

## Controls

**Trail** — Amount (spacing between sparkles, 3–48 pt of cursor travel),
maximum sparkles, lifetime, smallest/largest size, overall opacity.

**Motion** — Gravity (negative floats them upward), sideways drift, upward kick,
spin rate.

**Appearance** — Shape (eight-point star, sparkle, diamond, dot, heart), colour
scheme, glow.

**Colour schemes** — Soft Blush (the original web palette), Aurora, Sunset,
Neon, Gold Dust, Ice, Ember, Monochrome, Rainbow (a fresh hue per sparkle), and
Custom. Picking Custom reveals its editor right in the menu bar panel: one to
six colours, each set with a colour well or by typing a hex value. The same
editor appears in the advanced window.

**Behaviour** — Burst on click and its size, pause when the system Reduce Motion
setting is on, open at login.

Every setting is written to `UserDefaults` as it changes and applies live.
`Restore Defaults` in the advanced window resets all of them.

## How it works

- `SparkleEngine` owns one borderless `OverlayWindow` covering the union of all
  screen frames, at `.screenSaver` level with `ignoresMouseEvents`, joining all
  spaces so the trail survives a space switch or a full-screen app.
- `SparkleView` runs a `CADisplayLink`. Each frame it samples the cursor and
  interpolates spawn points along the segment travelled since the last frame, so
  a fast flick still leaves evenly spaced sparkles instead of one lonely star.
- Sparkle layers are allocated on demand up to the configured maximum and then
  recycled round-robin; a paused or idle machine holds no layers it has not
  earned, and the display link drops to 30 Hz while nothing is alive.
- Each sparkle is a `CAShapeLayer` sized in points with the shape path baked in,
  so only rotation and the grow/shrink scale ride on the transform and the
  geometry stays crisp.

## Layout

```
Sources/SparkleTrail/
  SparkleTrailApp.swift        @main, menu bar scene, app delegate
  MenuPanel.swift              menu bar panel and palette swatches
  AdvancedSettingsView.swift   full settings window
  SparkleSettings.swift        observable, UserDefaults-backed settings
  SparkleEngine.swift          overlay window, sparkle pool, physics
  Palette.swift                colour schemes, shapes, hex helpers
Resources/Info.plist           LSUIElement bundle metadata
dist/SparkleTrail.zip          the packaged download
reference/sparkle-cursor.js    the original browser implementation
```
