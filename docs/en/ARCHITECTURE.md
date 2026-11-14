# Architecture

[Français](../fr/ARCHITECTURE.md)

```
Package.swift (SwiftPM, macOS 14+, Swift 6 tools / language mode v5)
Sources/
  DisplayCore/            library shared by the app and the CLI
    DisplaySystem.swift   DisplaySystem / SidecarControlling protocols + real implementation
    PrivateAPI.swift      dlopen/dlsym: CGSConfigureDisplayEnabled, CGSGetDisplayList, SLSDetectDisplays
    SidecarManager.swift  SidecarCore wrapper (devices, connect, disconnect)
    DisplayStore.swift    JSON persistence (displays + iPads, disconnectedByUs flag)
    DisplayManager.swift  merged state, safety checks, single and bulk actions
  DisplaySwitch/          menu bar app (SwiftUI MenuBarExtra, LSUIElement)
  displayctl/             CLI
Tests/DisplayCoreTests/   unit tests (swift-testing) with fake displays / fake Sidecar
Resources/Info.plist      io.github.alexandrebeauduin.DisplaySwitch, version
scripts/build-app.sh      universal release build, assembles the .app, ad-hoc signature, --install
scripts/release.sh        build + zip build/DisplaySwitch-<version>.zip (+ .sha256)
.github/workflows/        ci.yml (test + build on push), release.yml (publish on tag v*)
```

## Persistence

`~/Library/Application Support/DisplaySwitch/displays.json`

```json
{ "displays": [{ "id": 9, "name": "Monitor", "uuid": "…", "isBuiltin": false, "disconnectedByUs": true }],
  "sidecars": [{ "id": "XXXXXXXX-…", "name": "iPad", "model": "iPad13,10", "disconnectedByUs": false }] }
```

The older format (a bare array of displays) is still read.

## `refresh()` rules

1. AirPlay / Sidecar displays (vendor `'aapl'`): dropped from the display list.
2. Active displays: remembered, `disconnectedByUs` flag cleared (replugged elsewhere).
3. Displays neither active nor online and not disconnected by us: pruned.
4. iPads seen: remembered; if connected, flag cleared.

## Safety checks

- never 0 active **physical** display (an iPad does not count);
- built-in display protected (`--force` in the CLI);
- reconnect everything on quit (default), asynchronous with a 15 s cap.

## Launch at login

`SMAppService.mainApp` — reliable only when the app lives in `/Applications`
(`scripts/build-app.sh --install`).

## Tests

`DisplayManager` talks to macOS only through two protocols, `DisplaySystem` (CoreGraphics)
and `SidecarControlling` (SidecarCore). Tests inject `FakeDisplays` / `FakeSidecar`, so
`swift test` checks the safety rules, state merging, persistence and bulk actions without
turning any real display off. Real hardware is tested by hand.

## Release

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist`.
2. Add a `## [x.y.z] - date` section to `CHANGELOG.md` (used as release notes).
3. `git tag vx.y.z && git push origin vx.y.z` → `release.yml` tests, builds the universal
   zip and creates the GitHub release. The tag must match the plist version.
