# Contributing

## Development setup

Nightprism is a macOS 14 or newer menu bar app. Development uses Xcode 27.1 with Swift 6.4 in Swift 6 mode, plus XcodeGen 2.46.0.

Install Xcode and XcodeGen, then generate the project:

```sh
xcodegen generate
```

`project.yml` is authoritative. The generated `Nightprism.xcodeproj` is ignored and should not be committed.

The Metal toolchain is required to build. If it is not installed, add it with:

```sh
xcodebuild -downloadComponent metalToolchain
```

## Build and check

Run the test action with signing disabled:

```sh
xcodebuild -project Nightprism.xcodeproj -scheme Nightprism -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting with:

```sh
swift format lint --strict --recursive Sources Tests
```

## Manual smoke checks

Before reporting a change that affects app behavior, run the app and check the relevant behavior. The following areas need real interactive checks:

- Add an overlay from the menu bar.
- Change its opacity.
- Drag and resize it.
- Lock it and confirm it cannot move.
- Quit and relaunch, then confirm saved state persists.
- Check behavior across Spaces and multiple displays.

## Changes and issues

The product roadmap is undecided. Open a GitHub issue to report a bug or propose a feature. Discuss feature intent in an issue before starting substantial work so the scope can be agreed on.

Keep pull requests focused. Include what changed, how you checked it, and any manual checks that remain pending. Add screenshots when they help explain a visual change.
