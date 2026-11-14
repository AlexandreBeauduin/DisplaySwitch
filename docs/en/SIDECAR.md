# Sidecar (iPad) — SidecarCore API

**English** · [Français](../fr/SIDECAR.md) · [Nederlands](../nl/SIDECAR.md) · [Deutsch](../de/SIDECAR.md)

## Problem

An iPad used with Sidecar shows up as a CoreGraphics display, but
`CGSConfigureDisplayEnabled` does not turn it off.

## How to recognise it on the CoreGraphics side

| Property | Value |
|---|---|
| `CGDisplayVendorNumber` | `0x6161706c` (`'aapl'`) — shared by AirPlay and Sidecar |
| `CGDisplayModelNumber` | `0x69506164` (`'iPad'`) |
| `CGDirectDisplayID` | **changes on every reconnection** (e.g. 10 → 11) |

So DisplaySwitch excludes these from the "Displays" list (`isAirPlay`) and identifies the
iPad by its `SidecarDevice` UUID, which is stable.

## API (private, resolved at runtime)

Framework: `/System/Library/PrivateFrameworks/SidecarCore.framework`

```objc
SidecarDisplayManager *m = [SidecarDisplayManager sharedManager];
m.devices;            // NSArray<SidecarDevice*> in range (filled asynchronously, ~2 s)
m.connectedDevices;   // those currently used as Sidecar displays
[m connectToDevice:dev completion:^(NSError *e){}];
[m disconnectFromDevice:dev completion:^(NSError *e){}];

SidecarDevice: identifier (NSUUID), name, model (e.g. "iPad13,10")
```

Called from Swift with `method(for:)` + `unsafeBitCast` to
`@convention(c) (AnyObject, Selector, AnyObject, @convention(block) (NSError?) -> Void) -> Void`
(see `Sources/DisplayCore/SidecarManager.swift`).

## Measured behaviour

- Disconnect: almost instant.
- Reconnect: ~5.6 s; the display comes back with a **new** `CGDirectDisplayID`.
- `devices` is empty right after `sharedManager`: the run loop must spin (~2 s) →
  `waitForDevices()` in the CLI; the app has a permanent run loop.
- No known public notification when an iPad comes in range: the app polls `devices` every
  5 s (in-memory, cheap) and also refreshes on `CGDisplayRegisterReconfigurationCallback`.

## Integration

- Menu: "Sidecar" section (one toggle per iPad, "in progress…" / "out of range" states).
- "Disconnect all but main" also disconnects connected iPads.
- "Reconnect all" reconnects iPads DisplaySwitch disconnected, if available.
- Quit with "Reconnect all on quit": `applicationShouldTerminate` returns `.terminateLater`
  and waits for completion (15 s max).
- CLI: `displayctl sidecar off|on [name|uuid]`.

## Pitfall: "non-escaping closure has escaped" crash

Passing a closure literal directly as a `@convention(block)` argument of a function pointer
makes Swift build a **non-escaping** block. SidecarCore retains it to call it later, and the
Swift runtime traps (`EXC_BREAKPOINT`). Fix: build the block in a
`let block: Completion = { … }` first, then pass it.

## Limits

Private API: may break with a macOS update; `isSupported` then becomes `false` and Sidecar
actions return an explicit error instead of crashing.
