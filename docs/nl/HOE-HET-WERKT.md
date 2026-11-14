# Zo werkt het

[English](../en/HOW-IT-WORKS.md) · [Français](../fr/FONCTIONNEMENT.md) · **Nederlands** · [Deutsch](../de/FUNKTIONSWEISE.md)

## Fysieke schermen (HDMI / DisplayPort / USB-C)

```
CGBeginDisplayConfiguration(&cfg)
CGSConfigureDisplayEnabled(cfg, displayID, enabled)   // privé, CoreGraphics
CGCompleteDisplayConfiguration(cfg, .permanently)     // kCGConfigurePermanently = 2
```

Het scherm wordt logisch uitgeschakeld, alsof de kabel eruit is: macOS herschikt de vensters
en de bureaubladindeling.

| Privé-symbool | Framework | Gebruik |
|---|---|---|
| `CGSConfigureDisplayEnabled` | CoreGraphics | scherm in- / uitschakelen |
| `CGSGetDisplayList` | CoreGraphics | alleen voor debuggen (bevat verouderde "spook"-ID's) |
| `SLSDetectDisplays` | SkyLight | macOS de schermen opnieuw laten detecteren na "Alles opnieuw verbinden" |

Ze worden allemaal opgezocht met `dlopen` / `dlsym` (`Sources/DisplayCore/PrivateAPI.swift`);
verdwijnt een symbool in een toekomstige macOS, dan mislukt de actie met een duidelijke fout.

### Waarom een geheugenbestand

Een uitgeschakeld scherm verdwijnt uit **zowel** `CGGetActiveDisplayList` als
`CGGetOnlineDisplayList`. Om het te kunnen tonen en weer aan te zetten, onthoudt
DisplaySwitch de ID in `~/Library/Application Support/DisplaySwitch/displays.json`.

## Sidecar-iPads

`CGSConfigureDisplayEnabled` heeft **geen effect** op een Sidecar-scherm. Dat wordt in plaats
daarvan aangestuurd via het privéframework `SidecarCore` → [SIDECAR.md](SIDECAR.md).

## Getest

- macOS 27.2, Apple Silicon.
- Twee externe monitoren: uit en weer aan OK.
- iPad via Sidecar: uit en weer aan OK (opnieuw verbinden ~5–6 s).
