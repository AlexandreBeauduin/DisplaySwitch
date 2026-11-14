# Architektur

[English](../en/ARCHITECTURE.md) · [Français](../fr/ARCHITECTURE.md) · [Nederlands](../nl/ARCHITECTUUR.md) · **Deutsch**

```
Package.swift (SwiftPM, macOS 14+, Swift-6-Tools / Sprachmodus v5)
Sources/
  DisplayCore/            von App und CLI gemeinsam genutzte Bibliothek
    DisplaySystem.swift   Protokolle DisplaySystem / SidecarControlling + echte Implementierung
    PrivateAPI.swift      dlopen/dlsym: CGSConfigureDisplayEnabled, CGSGetDisplayList, SLSDetectDisplays
    SidecarManager.swift  Wrapper um SidecarCore (devices, connect, disconnect)
    DisplayStore.swift    JSON-Speicherung (Bildschirme + iPads, Flag disconnectedByUs)
    DisplayManager.swift  zusammengeführter Zustand, Schutzprüfungen, Einzel- und Sammelaktionen
    Localization.swift    enum Language + L10n: alle sichtbaren Texte (en, fr, nl, de)
  DisplaySwitch/          Menüleisten-App (SwiftUI MenuBarExtra, LSUIElement)
  displayctl/             CLI
Tests/DisplayCoreTests/   Unit-Tests (swift-testing) mit Fake-Bildschirmen / Fake-Sidecar
Resources/Info.plist      io.github.alexandrebeauduin.DisplaySwitch, Version
scripts/build-app.sh      Universal-Release-Build, baut die .app, Ad-hoc-Signatur, --install
scripts/release.sh        Build + Zip build/DisplaySwitch-<version>.zip (+ .sha256)
.github/workflows/        ci.yml (Test + Build bei Push), release.yml (Veröffentlichung bei Tag v*)
```

## Speicherung

`~/Library/Application Support/DisplaySwitch/displays.json`

```json
{ "displays": [{ "id": 9, "name": "Monitor", "uuid": "…", "isBuiltin": false, "disconnectedByUs": true }],
  "sidecars": [{ "id": "XXXXXXXX-…", "name": "iPad", "model": "iPad13,10", "disconnectedByUs": false }] }
```

Das ältere Format (ein reines Array von Bildschirmen) wird weiterhin gelesen.

## Regeln von `refresh()`

1. AirPlay- / Sidecar-Bildschirme (Vendor `'aapl'`): aus der Bildschirmliste entfernt.
2. Aktive Bildschirme: gemerkt, Flag `disconnectedByUs` gelöscht (anderweitig wieder angesteckt).
3. Bildschirme, die weder aktiv noch online sind und nicht von uns getrennt wurden: entfernt.
4. Gesehene iPads: gemerkt; wenn verbunden, wird das Flag gelöscht.

## Schutzprüfungen

- nie 0 aktive **physische** Bildschirme (ein iPad zählt nicht);
- integrierter Bildschirm geschützt (`--force` in der CLI);
- beim Beenden alles wieder verbinden (Standard), asynchron mit 15 s Obergrenze.

## Start bei der Anmeldung

`SMAppService.mainApp` — nur zuverlässig, wenn die App in `/Applications` liegt
(`scripts/build-app.sh --install`).

## Übersetzungen

Alle sichtbaren Texte (Menü, Fehler, CLI) stehen in `Sources/DisplayCore/Localization.swift`,
ein `t(en:fr:nl:de:)`-Aufruf pro Text, sodass eine fehlende Übersetzung ein Compilerfehler ist.
Die Sprache ist die erste unterstützte in `Locale.preferredLanguages` (Standard Englisch),
überschrieben durch das Menü *Sprache* der App (`UserDefaults`-Schlüssel `language`) oder,
für die CLI, durch `DISPLAYSWITCH_LANG`. Sprache hinzufügen: einen Fall zu `Language` und eine
Spalte zu jedem `t(...)`.

## Tests

`DisplayManager` spricht mit macOS nur über zwei Protokolle, `DisplaySystem` (CoreGraphics)
und `SidecarControlling` (SidecarCore). Die Tests injizieren `FakeDisplays` / `FakeSidecar`,
sodass `swift test` Schutzregeln, Zustandszusammenführung, Speicherung und Sammelaktionen
prüft, ohne einen echten Bildschirm abzuschalten. Echte Hardware wird von Hand getestet.

## Version veröffentlichen

1. `CFBundleShortVersionString` in `Resources/Info.plist` erhöhen.
2. Einen Abschnitt `## [x.y.z] - Datum` in `CHANGELOG.md` ergänzen (dient als Release Notes).
3. `git tag vx.y.z && git push origin vx.y.z` → `release.yml` testet, baut das Universal-Zip
   und erstellt das GitHub-Release. Das Tag muss zur Version in der plist passen.
