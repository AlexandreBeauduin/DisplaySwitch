# Funktionsweise

[English](../en/HOW-IT-WORKS.md) · [Français](../fr/FONCTIONNEMENT.md) · [Nederlands](../nl/HOE-HET-WERKT.md) · **Deutsch**

## Physische Bildschirme (HDMI / DisplayPort / USB-C)

```
CGBeginDisplayConfiguration(&cfg)
CGSConfigureDisplayEnabled(cfg, displayID, enabled)   // privat, CoreGraphics
CGCompleteDisplayConfiguration(cfg, .permanently)     // kCGConfigurePermanently = 2
```

Der Bildschirm wird logisch abgeschaltet, als wäre das Kabel gezogen: macOS ordnet Fenster
und Schreibtischanordnung neu.

| Privates Symbol | Framework | Zweck |
|---|---|---|
| `CGSConfigureDisplayEnabled` | CoreGraphics | Bildschirm ein- / ausschalten |
| `CGSGetDisplayList` | CoreGraphics | nur zum Debuggen (enthält veraltete "Geister"-IDs) |
| `SLSDetectDisplays` | SkyLight | macOS nach "Alle wieder verbinden" die Bildschirme neu erkennen lassen |

Alle werden mit `dlopen` / `dlsym` aufgelöst (`Sources/DisplayCore/PrivateAPI.swift`);
verschwindet ein Symbol in einer künftigen macOS-Version, schlägt die Aktion mit einer klaren
Fehlermeldung fehl.

### Warum eine Merkdatei

Ein deaktivierter Bildschirm verschwindet aus **beiden** Listen, `CGGetActiveDisplayList` und
`CGGetOnlineDisplayList`. Um ihn anzuzeigen und wieder einzuschalten, merkt sich
DisplaySwitch seine ID in `~/Library/Application Support/DisplaySwitch/displays.json`.

## Sidecar-iPads

`CGSConfigureDisplayEnabled` hat **keine Wirkung** auf einen Sidecar-Bildschirm. Er wird
stattdessen über das private Framework `SidecarCore` gesteuert → [SIDECAR.md](SIDECAR.md).

## Getestet

- macOS 27.2, Apple Silicon.
- Zwei externe Monitore: aus und wieder an OK.
- iPad über Sidecar: aus und wieder an OK (Wiederverbinden ~5–6 s).
