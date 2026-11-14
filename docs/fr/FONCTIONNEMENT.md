# Fonctionnement

[English](../en/HOW-IT-WORKS.md) · **Français** · [Nederlands](../nl/HOE-HET-WERKT.md) · [Deutsch](../de/FUNKTIONSWEISE.md)

## Écrans physiques (HDMI / DisplayPort / USB-C)

```
CGBeginDisplayConfiguration(&cfg)
CGSConfigureDisplayEnabled(cfg, displayID, enabled)   // privé, CoreGraphics
CGCompleteDisplayConfiguration(cfg, .permanently)     // kCGConfigurePermanently = 2
```

L'écran est éteint logiquement, comme s'il était débranché : macOS réorganise les
fenêtres et la disposition du bureau.

| Symbole privé | Framework | Usage |
|---|---|---|
| `CGSConfigureDisplayEnabled` | CoreGraphics | allumer / couper un écran |
| `CGSGetDisplayList` | CoreGraphics | debug seulement (contient des IDs « fantômes ») |
| `SLSDetectDisplays` | SkyLight | forcer la redétection après « Tout reconnecter » |

Tous sont résolus via `dlopen` / `dlsym` (`Sources/DisplayCore/PrivateAPI.swift`) ; si un
symbole disparaît dans un futur macOS, l'action échoue avec une erreur claire.

### Pourquoi un fichier mémoire

Un écran coupé disparaît **à la fois** de `CGGetActiveDisplayList` et de
`CGGetOnlineDisplayList`. Pour le lister et le rallumer, DisplaySwitch mémorise son ID dans
`~/Library/Application Support/DisplaySwitch/displays.json`.

## iPad Sidecar

`CGSConfigureDisplayEnabled` n'a **aucun effet** sur un écran Sidecar. Il est piloté via le
framework privé `SidecarCore` → [SIDECAR.md](SIDECAR.md).

## Testé

- macOS 27.2, Apple Silicon.
- Deux écrans externes : coupés puis rallumés OK.
- iPad en Sidecar : coupé puis rallumé OK (reconnexion ~5–6 s).
