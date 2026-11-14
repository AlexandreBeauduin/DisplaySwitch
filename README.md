# DisplaySwitch

[![CI](https://github.com/AlexandreBeauduin/DisplaySwitch/actions/workflows/ci.yml/badge.svg)](https://github.com/AlexandreBeauduin/DisplaySwitch/actions/workflows/ci.yml)

**English** · [Français](README.fr.md)

A small macOS menu bar app (and CLI) to connect / disconnect displays — **including an iPad
used as a Sidecar display** — without unplugging any cable.

> **Vibe coded.** This project was built through conversation with an AI coding assistant
> (Claude Code): the human described what they wanted, tested on real hardware and steered;
> the AI investigated the macOS APIs and wrote the code and docs. It works on the author's
> machine; read the code before trusting it on yours.

## Features

- Lists displays and Sidecar iPads, refreshed automatically.
- Connect / disconnect each one from the menu.
- **Disconnect all but the main display** (iPads included) / **Reconnect all**.
- Remembers what it disconnected (a disconnected display disappears from macOS lists).
- Launch at login.
- Safety: never disconnects the last physical display, protects the built-in display,
  reconnects everything on quit (default).

## Install

**Download:** grab `DisplaySwitch-x.y.z.zip` from the
[Releases](https://github.com/AlexandreBeauduin/DisplaySwitch/releases) page, unzip, move
`DisplaySwitch.app` to `/Applications`. Universal binary (Apple Silicon + Intel), macOS 14+.

**From source** (Xcode 16 or later):

```bash
scripts/build-app.sh --install   # builds and copies DisplaySwitch.app to /Applications
```

A downloaded copy is not signed with a Developer ID: macOS blocks it on first launch →
System Settings › Privacy & Security › **Open Anyway**.

## CLI

```bash
build/displayctl list
build/displayctl off <id>                 # --force to allow the built-in display
build/displayctl on <id>
build/displayctl sidecar off [name|uuid]  # iPad
build/displayctl sidecar on  [name|uuid]
build/displayctl on-all                   # rescue: reconnect everything we disconnected
build/displayctl only-main                # everything but the main display (iPads included)
build/displayctl detect                   # ask macOS to re-detect displays
build/displayctl debug
```

## How it works (short)

- Physical displays: private CoreGraphics call `CGSConfigureDisplayEnabled` inside a
  display configuration transaction.
- Sidecar iPads: private `SidecarCore` framework (`connectToDevice:` / `disconnectFromDevice:`).
- All private symbols are resolved at runtime (`dlsym`), nothing links against private frameworks.

Details: [How it works](docs/en/HOW-IT-WORKS.md) · [Sidecar](docs/en/SIDECAR.md) ·
[Architecture](docs/en/ARCHITECTURE.md)

## Development

```bash
swift test                 # unit tests (safety rules, state, persistence) — no real display touched
swift build                # debug build
scripts/release.sh         # universal build + build/DisplaySwitch-<version>.zip
```

Releasing: bump `CFBundleShortVersionString` in `Resources/Info.plist`, add a section to
[CHANGELOG.md](CHANGELOG.md), then push a matching tag (`git tag v1.2.0 && git push origin v1.2.0`):
GitHub Actions tests, builds and publishes the release.

## Caveats

- Relies on **private Apple APIs**: a macOS update may break a feature; the app then shows
  an error instead of crashing. Not eligible for the Mac App Store.
- Last resort if a display stays off: unplug / replug it, or restart the Mac.

## License & disclaimer

MIT — see [LICENSE](LICENSE). Provided **as is, without any warranty**. This project is not
affiliated with or endorsed by Apple. It changes your display configuration through
undocumented APIs: use at your own risk.
