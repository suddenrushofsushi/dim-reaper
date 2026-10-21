# Nightprism

A macOS menubar utility that puts one or more **always-on-top translucent overlay windows** above everything on your screen, dimming whatever's behind them. v1 ships a flat black tint at user-controlled opacity. The rendering path is built on **Metal** (CAMetalLayer + fragment shader) so future versions can drop in real shader effects (blur, gradients, animated noise, color grading) without touching the windowing layer.

- **Target:** macOS 14 Sonoma or newer
- **Language:** Swift 5.10, strict concurrency
- **UI:** SwiftUI (menubar) + AppKit (windows) + Metal (drawing)
- **Build system:** Xcode project, generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen)

---

## Mental model (for someone new to macOS dev)

A macOS GUI app is fundamentally a **bundle** — a `.app` directory with a specific layout: an executable, an `Info.plist` describing the app, optional resources, optional `Assets.xcassets`, and a code signature. You don't really build a "binary" the way you would for a CLI tool; you build a bundle.

Three Apple frameworks matter here:

| Framework | Era | What we use it for |
|---|---|---|
| **AppKit** | Old (since 10.0). Imperative. Objective-C heritage. | `NSWindow`/`NSPanel`, `NSView`. The only way to get fine-grained window behavior like "float above everything, ignore Spaces, no shadow." SwiftUI's `Window` scene type can't do this. |
| **SwiftUI** | New (2019+). Declarative. | The menubar UI (`MenuBarExtra`), state management (`@Observable`), the per-overlay controls (sliders, buttons). |
| **Metal** | GPU API (2014+). | Drawing inside the overlay window. v1 is a one-color fragment shader, but the pipeline is set up so a real shader can replace `Shaders.metal` without restructuring. |

The app is a **menubar-only "agent"** — it sets `LSUIElement = true` in `Info.plist`, which means no Dock icon, no app switcher entry, no main menu bar. The only entry point is the moon icon in the system menu bar.

---

## Prerequisites

You will need:

1. **Xcode** (not just Command Line Tools). Install from the Mac App Store. After install, run once and accept the license:
   ```sh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```
   `xcode-select -p` should print the Xcode path, not `/Library/Developer/CommandLineTools`.

2. **Homebrew** (probably already have it):
   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. **XcodeGen** — generates `Nightprism.xcodeproj` from the declarative `project.yml`. We don't check the `.xcodeproj` into git; it's regenerated.
   ```sh
   brew install xcodegen
   ```

4. **Metal toolchain.** As of Xcode 26, the Metal shader compiler is a separately-downloadable component, not bundled with Xcode. On a fresh Xcode install you must fetch it explicitly:
   ```sh
   xcodebuild -downloadComponent MetalToolchain
   ```
   Without it, building this project fails with confusing linker errors about a missing `__preview.dylib` — the real cause is `Shaders.metal` silently failing to compile. Run the command above once and you're set.

5. **(Optional) xcbeautify** — prettifies `xcodebuild` output:
   ```sh
   brew install xcbeautify
   ```

---

## First run

From the repo root:

```sh
xcodegen generate     # creates Nightprism.xcodeproj
open Nightprism.xcodeproj
```

In Xcode: hit **⌘R** to build and run. A moon icon appears in the menu bar. Click it → **New Overlay** → a translucent dark window appears in the center of your main display.

You can also build from the command line:

```sh
xcodebuild -project Nightprism.xcodeproj \
           -scheme Nightprism \
           -configuration Debug \
           build | xcbeautify
```

The built `.app` lands under `~/Library/Developer/Xcode/DerivedData/Nightprism-…/Build/Products/Debug/Nightprism.app`. You can `open` it directly.

---

## How the pieces fit

```
Sources/
├── NightprismApp.swift          @main App entry; declares the MenuBarExtra scene.
├── OverlayStore.swift           @Observable singleton. Owns the list of overlays,
│                                persists frames + opacity to UserDefaults.
├── OverlayWindowController.swift NSWindowController per overlay. Bridges store
│                                state ↔ NSPanel and reports drag/resize back.
│   └── OverlayPanel             NSPanel subclass: borderless, transparent,
│                                .floating level, joins all Spaces.
├── MetalTintView.swift          NSView backed by CAMetalLayer. Builds the render
│                                pipeline, manages the drawable size, draws on demand.
├── Shaders.metal                Vertex (full-screen triangle) + fragment (tint color).
│                                This is where future visual effects live.
└── MenuBarContent.swift         SwiftUI UI for the menubar popover: list, sliders,
                                 lock/delete buttons, Quit.

Resources/
├── Info.plist                   App metadata. LSUIElement=true → menubar-only.
└── Nightprism.entitlements      Sandbox off for local dev. Flip on for App Store later.

project.yml                       XcodeGen spec. Single source of truth for the project.
```

### Data flow

1. User clicks **New Overlay** → `OverlayStore.addOverlay()` appends an `Overlay` value and instantiates an `OverlayWindowController`.
2. The controller creates an `OverlayPanel`, sets its content view to a `MetalTintView`, and shows it.
3. Slider in the popover updates `Overlay.opacity` → `OverlayStore.update(_:)` → controller's `apply(_:)` → `MetalTintView.setOpacity(_:)` → triggers a redraw.
4. Dragging/resizing the panel fires `NSWindowDelegate` callbacks → controller reports the new frame to the store → store persists.

### Why `NSPanel` and not `NSWindow`?

`NSPanel` is the AppKit type designed for floating utility windows. It can become key without becoming main (so it doesn't steal focus from the app underneath in disruptive ways), and combined with `isFloatingPanel = true` plus a `.floatingWindow` level, it sits above normal app windows. The `collectionBehavior` flags make it appear on every Space and survive full-screen transitions.

### Why Metal for a black rectangle?

For v1, literally a `CALayer` with `backgroundColor = NSColor(white: 0, alpha: 0.5).cgColor` would work. The Metal scaffolding is intentional — you said you want real shader effects later (blur, gradients, etc.), and rebuilding the rendering path after the fact is more work than starting here. The current shader is one of the simplest possible Metal programs; replacing `tint_fragment` in `Shaders.metal` is where v2 begins.

---

## Debugging

- **Inside Xcode:** ⌘R runs under the debugger. Set breakpoints in Swift normally. The View Debugger (Debug → View Debugging → Capture View Hierarchy) is mostly useless here because the content is a Metal drawable, not a view tree.
- **GPU debugging:** Debug → Debug Executable Frame Capture, or click the camera icon in the bottom Xcode bar while running. This drops you into the Metal frame debugger where you can inspect draw calls, shader inputs, and the captured drawable. Indispensable once shaders get non-trivial.
- **Console logs:** any `print(...)` shows up in Xcode's console. For structured logging, use `os.Logger`:
  ```swift
  import os
  let log = Logger(subsystem: "com.cwaterman.Nightprism", category: "overlay")
  log.info("opened overlay \(id)")
  ```
  These show in `Console.app` too, filtered by subsystem.
- **Strict concurrency:** the project enables `SWIFT_STRICT_CONCURRENCY=complete`. You'll see warnings about `Sendable`, actor isolation, etc. Don't silence them — they catch real data races.

---

## Common pitfalls

- **The moon icon doesn't appear.** Activation Policy / `LSUIElement` is in `Info.plist` and only applies to the *built* app. If you `swift run` against random source, it won't bundle properly. Always build via Xcode or `xcodebuild`.
- **Window doesn't float over full-screen apps.** Full-screen Spaces are isolated. `.fullScreenAuxiliary` in `collectionBehavior` is the magic flag. If a specific full-screen app still hides you, that app is using exclusive-fullscreen mode and there's nothing user-space can do.
- **Window won't move.** Check `isMovable` and `isMovableByWindowBackground`. The lock toggle flips `isMovable` to `false`.
- **Black flashing during resize.** Metal drawable resize is asynchronous. Setting `layerContentsRedrawPolicy = .duringViewResize` (already set) reduces this. If it's still bad, you can clamp the drawable size update to `viewDidEndLiveResize` only — costs you live resize fidelity.

---

## Publishing

There are three distribution paths, in increasing order of friction:

### 1. Unsigned, personal use only
Just build in Xcode Release config and copy the `.app` to `/Applications`. Gatekeeper will complain on first launch; right-click → Open to bypass once. **Don't ship this to anyone else.**

### 2. Developer ID signed + notarized (most flexible)
Requires an [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/yr).

1. In Xcode → Settings → Accounts → add your Apple ID with the Developer Program.
2. In `project.yml`, change `CODE_SIGN_IDENTITY` from `"-"` to `"Developer ID Application"` and set a `DEVELOPMENT_TEAM` to your team ID.
3. Build for Release, archive (Product → Archive), then in the Organizer:
   - **Distribute App → Direct Distribution** → Xcode signs and uploads to Apple's notary service.
   - Wait a few minutes for the notarization ticket. Then **Export**.
4. The exported `.app` (or a DMG you build around it) is what you distribute. Gatekeeper accepts it on any Mac.

### 3. Mac App Store
You'd need to:
- Enable the App Sandbox (`com.apple.security.app-sandbox = true` in the entitlements).
- Re-audit which windowing/Spaces APIs you use — some get rejected without justification.
- Use `Apple Distribution` signing identity.
- Submit through App Store Connect.

I'd defer this until v2 features are nailed down. Sandboxing screen-overlay apps in particular gets fiddly with permissions for screen access if you ever add features that read pixels behind the window (e.g. a real blur).

---

## Roadmap notes (not implemented, but the architecture supports)

- **Animated shaders:** flip `MetalTintView.startDisplayLink()` to actually attach a `CADisplayLink` and pass a `time` uniform into `tint_fragment`.
- **Real blur:** the overlay window is composited by `WindowServer` against whatever's behind it. To sample the actual pixels behind for a real Gaussian blur, you'd need `CGWindowListCreateImage` or `ScreenCaptureKit` (the modern API). That requires the **Screen Recording** permission in System Settings → Privacy & Security. Easy hand-wave today, fiddly with sandbox/permissions tomorrow.
- **Per-display pinning, hotkeys, custom shapes:** all reasonable. The `Overlay` struct in `OverlayStore.swift` is where new persisted properties go.

---

## License

TBD.
