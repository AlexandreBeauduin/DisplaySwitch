# How it works

[Français](../fr/FONCTIONNEMENT.md)

## Physical displays (HDMI / DisplayPort / USB-C)

```
CGBeginDisplayConfiguration(&cfg)
CGSConfigureDisplayEnabled(cfg, displayID, enabled)   // private, CoreGraphics
CGCompleteDisplayConfiguration(cfg, .permanently)     // kCGConfigurePermanently = 2
```

The display is turned off logically, as if unplugged: macOS rearranges windows and the
desktop layout.

| Private symbol | Framework | Use |
|---|---|---|
| `CGSConfigureDisplayEnabled` | CoreGraphics | enable / disable a display |
| `CGSGetDisplayList` | CoreGraphics | debugging only (contains stale "ghost" IDs) |
| `SLSDetectDisplays` | SkyLight | force macOS to re-detect displays after "Reconnect all" |

All are resolved with `dlopen` / `dlsym` (`Sources/DisplayCore/PrivateAPI.swift`); if a
symbol disappears in a future macOS, the action fails with a clear error.

### Why a memory file

A disabled display disappears from **both** `CGGetActiveDisplayList` and
`CGGetOnlineDisplayList`. To list it and turn it back on, DisplaySwitch remembers its ID in
`~/Library/Application Support/DisplaySwitch/displays.json`.

## Sidecar iPads

`CGSConfigureDisplayEnabled` has **no effect** on a Sidecar display. It is driven through
the private `SidecarCore` framework instead → [SIDECAR.md](SIDECAR.md).

## Tested

- macOS 27.2, Apple Silicon.
- Two external monitors: off then on OK.
- iPad over Sidecar: off then on OK (reconnection ~5–6 s).
