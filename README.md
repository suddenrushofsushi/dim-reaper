# Nightprism

A macOS menu bar app for dimming selected parts of your screen with translucent overlays.

Nightprism is an early personal project for making screen time more comfortable. It currently
renders a flat black tint. The rendering path uses Metal so other visual effects can be explored
later. Product direction and release scope are being worked out in
[GitHub issues](https://github.com/suddenrushofsushi/nightprism/issues).

## Current behavior

- Create multiple independent overlays from the menu bar.
- Move and resize each overlay; adjust opacity from 0–100%.
- Lock movement or delete an overlay from the menu bar controls.
- Restore overlay frames, opacity, and lock state when the app starts.
- Float above ordinary app windows and join all Spaces.

Locking currently prevents movement only. No explicit click-through mode is implemented.
Full-screen and multiple-display behavior needs
interactive validation; saved windows are not repositioned when a display is disconnected.

## Requirements

- **App deployment target:** macOS 14 or newer. Older supported systems have not yet been tested.
- **Development:** Xcode 27.1 with its bundled Swift 6.4 compiler, using Swift 6 language mode.
  Use a macOS version supported by that Xcode release.
- **Project generation:** [XcodeGen 2.46.0](https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0).
- **Shader compilation:** the optional Xcode Metal Toolchain component must be installed to build.

There are no third-party runtime dependencies. The app does not capture your screen; its current
tint renderer does not require Screen Recording permission.

## Build and run

Install Xcode and XcodeGen first. For a new Xcode installation, run these commands yourself to
select Xcode, review its license, and install required components:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license
sudo xcodebuild -runFirstLaunch
```

Then install the Metal compiler and generate the project:

```sh
xcodebuild -downloadComponent metalToolchain
xcodegen generate
open Nightprism.xcodeproj
```

Run the `Nightprism` scheme in Xcode. Click the moon icon in the menu bar, then **New Overlay**.
The app has no Dock icon.

For a command-line development build:

```sh
xcodebuild -project Nightprism.xcodeproj \
  -scheme Nightprism -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/local build
open .build/local/Build/Products/Debug/Nightprism.app
```

The project uses local ad hoc signing. Signed and notarized distribution builds are not set up;
there are no downloadable releases yet.

## Checks

```sh
swift format lint --strict --recursive Sources Tests
xcodebuild -project Nightprism.xcodeproj \
  -scheme Nightprism -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/local \
  CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Nightprism.xcodeproj \
  -scheme Nightprism -configuration Release \
  -destination 'platform=macOS' -derivedDataPath .build/local \
  CODE_SIGNING_ALLOWED=NO build
```

Swift Testing covers overlay creation, updates, removal, persistence, compatibility with the
original saved-state format, and corrupt saved data. Tests use isolated preferences and substitute
window controllers; they do not verify GPU output or mouse interaction. The test runner hosts the
app, so it may briefly appear in the menu bar.

CI runs these checks with Xcode 27.1 on GitHub's `xcode-27` runner. That runner image is currently
in public preview, so availability may change. Workflow actions and XcodeGen downloads are pinned.

## Code map

- `Sources/NightprismApp.swift`: app entry point and menu bar scene.
- `Sources/MenuBarContent.swift`: per-overlay controls.
- `Sources/OverlayStore.swift`: observable state, controller ownership, and versioned preferences.
- `Sources/OverlayWindowController.swift`: AppKit panels, window behavior, and frame updates.
- `Sources/MetalTintView.swift`: on-demand Metal drawing and drawable sizing.
- `Sources/Shaders.metal`: full-screen triangle and premultiplied-alpha tint shader.
- `Tests/OverlayStoreTests.swift`: state and persistence regression tests.

`project.yml` is the source of truth for build settings, targets, metadata, and entitlements.
Regenerate after changing it. Generated Xcode projects and build products are ignored by Git.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md) for development conventions and manual smoke checks.
Report bugs and discuss proposed features in [issues](https://github.com/suddenrushofsushi/nightprism/issues).
Blur, animations, hotkeys, and other effects are possibilities, not committed features.

Nightprism is licensed under the [MIT License](LICENSE). Copyright (c) 2026 Craig Waterman.
