# Sidecar (iPad) — SidecarCore-API

[English](../en/SIDECAR.md) · [Français](../fr/SIDECAR.md) · **Nederlands** · [Deutsch](../de/SIDECAR.md)

## Probleem

Een iPad die met Sidecar wordt gebruikt, verschijnt als CoreGraphics-scherm, maar
`CGSConfigureDisplayEnabled` schakelt het niet uit.

## Herkennen aan de CoreGraphics-kant

| Eigenschap | Waarde |
|---|---|
| `CGDisplayVendorNumber` | `0x6161706c` (`'aapl'`) — gedeeld door AirPlay en Sidecar |
| `CGDisplayModelNumber` | `0x69506164` (`'iPad'`) |
| `CGDirectDisplayID` | **verandert bij elke nieuwe verbinding** (bijv. 10 → 11) |

DisplaySwitch sluit deze daarom uit van de lijst "Schermen" (`isAirPlay`) en herkent de iPad
aan de UUID van zijn `SidecarDevice`, die stabiel is.

## API (privé, tijdens het draaien opgezocht)

Framework: `/System/Library/PrivateFrameworks/SidecarCore.framework`

```objc
SidecarDisplayManager *m = [SidecarDisplayManager sharedManager];
m.devices;            // NSArray<SidecarDevice*> binnen bereik (asynchroon gevuld, ~2 s)
m.connectedDevices;   // de apparaten die nu als Sidecar-scherm dienen
[m connectToDevice:dev completion:^(NSError *e){}];
[m disconnectFromDevice:dev completion:^(NSError *e){}];

SidecarDevice: identifier (NSUUID), name, model (bijv. "iPad13,10")
```

Vanuit Swift aangeroepen met `method(for:)` + `unsafeBitCast` naar
`@convention(c) (AnyObject, Selector, AnyObject, @convention(block) (NSError?) -> Void) -> Void`
(zie `Sources/DisplayCore/SidecarManager.swift`).

## Gemeten gedrag

- Loskoppelen: vrijwel direct.
- Opnieuw verbinden: ~5,6 s; het scherm komt terug met een **nieuwe** `CGDirectDisplayID`.
- `devices` is leeg direct na `sharedManager`: de run loop moet draaien (~2 s) →
  `waitForDevices()` in de CLI; de app heeft een permanente run loop.
- Geen bekende publieke melding wanneer een iPad binnen bereik komt: de app vraagt `devices`
  elke 5 s op (in het geheugen, goedkoop) en ververst ook bij
  `CGDisplayRegisterReconfigurationCallback`.

## Integratie

- Menu: sectie "Sidecar" (één schakelaar per iPad, statussen "bezig…" / "buiten bereik").
- "Alles behalve het hoofdscherm" koppelt ook verbonden iPads los.
- "Alles opnieuw verbinden" verbindt de iPads die DisplaySwitch heeft losgekoppeld, indien beschikbaar.
- Stoppen met "Alles opnieuw verbinden bij stoppen": `applicationShouldTerminate` geeft
  `.terminateLater` terug en wacht op voltooiing (max. 15 s).
- CLI: `displayctl sidecar off|on [naam|uuid]`.

## Valkuil: crash "non-escaping closure has escaped"

Geef je een closure-literal rechtstreeks door als `@convention(block)`-argument van een
functiepointer, dan bouwt Swift een **non-escaping** block. SidecarCore bewaart het om het
later aan te roepen, en de Swift-runtime stopt met een trap (`EXC_BREAKPOINT`). Oplossing:
bouw het block eerst in een `let block: Completion = { … }` en geef het dan door.

## Beperkingen

Privé-API: kan breken met een macOS-update; `isSupported` wordt dan `false` en de
Sidecar-acties geven een duidelijke fout in plaats van te crashen.
