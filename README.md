# DisplaySwitch

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

```bash
scripts/build-app.sh --install   # builds and copies DisplaySwitch.app to /Applications
```

Requires macOS 14 (Sonoma) or later and the Xcode command line tools.

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

## Caveats

- Relies on **private Apple APIs**: a macOS update may break a feature; the app then shows
  an error instead of crashing. Not eligible for the Mac App Store.
- Last resort if a display stays off: unplug / replug it, or restart the Mac.

## License

MIT — see [LICENSE](LICENSE).
