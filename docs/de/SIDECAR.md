# Sidecar (iPad) — SidecarCore-API

[English](../en/SIDECAR.md) · [Français](../fr/SIDECAR.md) · [Nederlands](../nl/SIDECAR.md) · **Deutsch**

## Problem

Ein iPad, das per Sidecar genutzt wird, erscheint als CoreGraphics-Bildschirm, aber
`CGSConfigureDisplayEnabled` schaltet es nicht ab.

## Erkennung auf der CoreGraphics-Seite

| Eigenschaft | Wert |
|---|---|
| `CGDisplayVendorNumber` | `0x6161706c` (`'aapl'`) — gemeinsam für AirPlay und Sidecar |
| `CGDisplayModelNumber` | `0x69506164` (`'iPad'`) |
| `CGDirectDisplayID` | **ändert sich bei jeder neuen Verbindung** (z. B. 10 → 11) |

DisplaySwitch schließt diese daher aus der Liste "Bildschirme" aus (`isAirPlay`) und erkennt
das iPad an der UUID seines `SidecarDevice`, die stabil bleibt.

## API (privat, zur Laufzeit aufgelöst)

Framework: `/System/Library/PrivateFrameworks/SidecarCore.framework`

```objc
SidecarDisplayManager *m = [SidecarDisplayManager sharedManager];
m.devices;            // NSArray<SidecarDevice*> in Reichweite (asynchron befüllt, ~2 s)
m.connectedDevices;   // die gerade als Sidecar-Bildschirm genutzten Geräte
[m connectToDevice:dev completion:^(NSError *e){}];
[m disconnectFromDevice:dev completion:^(NSError *e){}];

SidecarDevice: identifier (NSUUID), name, model (z. B. "iPad13,10")
```

Aus Swift aufgerufen mit `method(for:)` + `unsafeBitCast` nach
`@convention(c) (AnyObject, Selector, AnyObject, @convention(block) (NSError?) -> Void) -> Void`
(siehe `Sources/DisplayCore/SidecarManager.swift`).

## Gemessenes Verhalten

- Trennen: fast sofort.
- Wiederverbinden: ~5,6 s; der Bildschirm kommt mit einer **neuen** `CGDirectDisplayID` zurück.
- `devices` ist direkt nach `sharedManager` leer: Die Run Loop muss laufen (~2 s) →
  `waitForDevices()` in der CLI; die App hat eine dauerhafte Run Loop.
- Keine bekannte öffentliche Benachrichtigung, wenn ein iPad in Reichweite kommt: Die App
  fragt `devices` alle 5 s ab (im Speicher, günstig) und aktualisiert zusätzlich bei
  `CGDisplayRegisterReconfigurationCallback`.

## Integration

- Menü: Abschnitt "Sidecar" (ein Schalter pro iPad, Zustände "läuft…" / "außer Reichweite").
- "Alles außer Hauptbildschirm" trennt auch verbundene iPads.
- "Alle wieder verbinden" verbindet die von DisplaySwitch getrennten iPads, sofern verfügbar.
- Beenden mit "Beim Beenden alle wieder verbinden": `applicationShouldTerminate` liefert
  `.terminateLater` und wartet auf den Abschluss (max. 15 s).
- CLI: `displayctl sidecar off|on [name|uuid]`.

## Stolperfalle: Absturz "non-escaping closure has escaped"

Übergibt man ein Closure-Literal direkt als `@convention(block)`-Argument eines
Funktionszeigers, baut Swift einen **non-escaping** Block. SidecarCore behält ihn, um ihn
später aufzurufen, und die Swift-Runtime löst einen Trap aus (`EXC_BREAKPOINT`). Lösung:
den Block zuerst in einem `let block: Completion = { … }` erzeugen und dann übergeben.

## Grenzen

Private API: kann mit einem macOS-Update brechen; `isSupported` wird dann `false`, und die
Sidecar-Aktionen liefern einen klaren Fehler statt abzustürzen.
