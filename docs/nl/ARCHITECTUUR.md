# Architectuur

[English](../en/ARCHITECTURE.md) · [Français](../fr/ARCHITECTURE.md) · **Nederlands** · [Deutsch](../de/ARCHITEKTUR.md)

```
Package.swift (SwiftPM, macOS 14+, Swift 6-tools / taalmodus v5)
Sources/
  DisplayCore/            bibliotheek gedeeld door app en CLI
    DisplaySystem.swift   protocollen DisplaySystem / SidecarControlling + echte implementatie
    PrivateAPI.swift      dlopen/dlsym: CGSConfigureDisplayEnabled, CGSGetDisplayList, SLSDetectDisplays
    SidecarManager.swift  wrapper rond SidecarCore (devices, connect, disconnect)
    DisplayStore.swift    JSON-opslag (schermen + iPads, vlag disconnectedByUs)
    DisplayManager.swift  samengevoegde status, veiligheidscontroles, losse en groepsacties
    Localization.swift    enum Language + L10n: alle zichtbare teksten (en, fr, nl, de)
  DisplaySwitch/          menubalkapp (SwiftUI MenuBarExtra, LSUIElement)
  displayctl/             CLI
Tests/DisplayCoreTests/   unittests (swift-testing) met nep-schermen / nep-Sidecar
Resources/Info.plist      io.github.alexandrebeauduin.DisplaySwitch, versie
scripts/build-app.sh      universele release-build, stelt de .app samen, ad-hoc-handtekening, --install
scripts/release.sh        build + zip build/DisplaySwitch-<versie>.zip (+ .sha256)
.github/workflows/        ci.yml (test + build bij push), release.yml (publiceren bij tag v*)
```

## Opslag

`~/Library/Application Support/DisplaySwitch/displays.json`

```json
{ "displays": [{ "id": 9, "name": "Monitor", "uuid": "…", "isBuiltin": false, "disconnectedByUs": true }],
  "sidecars": [{ "id": "XXXXXXXX-…", "name": "iPad", "model": "iPad13,10", "disconnectedByUs": false }] }
```

Het oudere formaat (een kale lijst schermen) wordt nog steeds gelezen.

## Regels van `refresh()`

1. AirPlay- / Sidecar-schermen (vendor `'aapl'`): uit de schermlijst gehaald.
2. Actieve schermen: onthouden, vlag `disconnectedByUs` gewist (elders weer aangesloten).
3. Schermen die niet actief en niet online zijn en niet door ons losgekoppeld: opgeruimd.
4. Geziene iPads: onthouden; indien verbonden wordt de vlag gewist.

## Veiligheidscontroles

- nooit 0 actieve **fysieke** schermen (een iPad telt niet mee);
- ingebouwd scherm beschermd (`--force` in de CLI);
- alles opnieuw verbinden bij stoppen (standaard), asynchroon met een limiet van 15 s.

## Openen bij inloggen

`SMAppService.mainApp` — alleen betrouwbaar als de app in `/Applications` staat
(`scripts/build-app.sh --install`).

## Vertalingen

Alle zichtbare teksten (menu, fouten, CLI) staan in `Sources/DisplayCore/Localization.swift`,
één `t(en:fr:nl:de:)`-aanroep per tekst, dus een ontbrekende vertaling is een compileerfout.
De taal is de eerste ondersteunde in `Locale.preferredLanguages` (standaard Engels),
overschreven door het menu *Taal* van de app (`UserDefaults`-sleutel `language`) of, voor de
CLI, door `DISPLAYSWITCH_LANG`. Een taal toevoegen: een case aan `Language` en een kolom aan
elke `t(...)`.

## Tests

`DisplayManager` praat alleen met macOS via twee protocollen, `DisplaySystem` (CoreGraphics)
en `SidecarControlling` (SidecarCore). De tests injecteren `FakeDisplays` / `FakeSidecar`,
zodat `swift test` de veiligheidsregels, het samenvoegen van de status, de opslag en de
groepsacties controleert zonder een echt scherm uit te zetten. Echte hardware wordt met de
hand getest.

## Een versie uitbrengen

1. Verhoog `CFBundleShortVersionString` in `Resources/Info.plist`.
2. Voeg een sectie `## [x.y.z] - datum` toe aan `CHANGELOG.md` (dient als release notes).
3. `git tag vx.y.z && git push origin vx.y.z` → `release.yml` test, bouwt de universele zip
   en maakt de GitHub-release aan. De tag moet overeenkomen met de versie in de plist.
