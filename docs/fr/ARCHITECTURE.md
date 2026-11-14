# Architecture

[English](../en/ARCHITECTURE.md)

```
Package.swift (SwiftPM, macOS 14+, outils Swift 6 / mode de langage v5)
Sources/
  DisplayCore/            bibliothèque partagée app + CLI
    DisplaySystem.swift   protocoles DisplaySystem / SidecarControlling + implémentation réelle
    PrivateAPI.swift      dlopen/dlsym : CGSConfigureDisplayEnabled, CGSGetDisplayList, SLSDetectDisplays
    SidecarManager.swift  wrapper SidecarCore (devices, connect, disconnect)
    DisplayStore.swift    persistance JSON (écrans + iPad, drapeau disconnectedByUs)
    DisplayManager.swift  état fusionné, garde-fous, actions unitaires et groupées
  DisplaySwitch/          app barre des menus (SwiftUI MenuBarExtra, LSUIElement)
  displayctl/             CLI
Tests/DisplayCoreTests/   tests unitaires (swift-testing) avec faux écrans / faux Sidecar
Resources/Info.plist      io.github.alexandrebeauduin.DisplaySwitch, version
scripts/build-app.sh      build release universel, assemble le .app, signature ad hoc, --install
scripts/release.sh        build + zip build/DisplaySwitch-<version>.zip (+ .sha256)
.github/workflows/        ci.yml (tests + build à chaque push), release.yml (publication sur tag v*)
```

## Persistance

`~/Library/Application Support/DisplaySwitch/displays.json`

```json
{ "displays": [{ "id": 9, "name": "Moniteur", "uuid": "…", "isBuiltin": false, "disconnectedByUs": true }],
  "sidecars": [{ "id": "XXXXXXXX-…", "name": "iPad", "model": "iPad13,10", "disconnectedByUs": false }] }
```

L'ancien format (tableau nu d'écrans) est encore lu.

## Règles de `refresh()`

1. Écrans AirPlay / Sidecar (vendor `'aapl'`) : retirés de la liste des écrans.
2. Écrans actifs : mémorisés, drapeau `disconnectedByUs` effacé (rebranchés ailleurs).
3. Écrans ni actifs ni online et non coupés par nous : purgés.
4. iPad vus : mémorisés ; si connectés, drapeau effacé.

## Garde-fous

- jamais 0 écran **physique** actif (un iPad ne compte pas) ;
- écran intégré protégé (`--force` en CLI) ;
- tout reconnecter en quittant (par défaut), en asynchrone avec un plafond de 15 s.

## Lancement au démarrage

`SMAppService.mainApp` — fiable seulement si l'app est dans `/Applications`
(`scripts/build-app.sh --install`).

## Tests

`DisplayManager` ne parle à macOS qu'à travers deux protocoles, `DisplaySystem`
(CoreGraphics) et `SidecarControlling` (SidecarCore). Les tests injectent `FakeDisplays` /
`FakeSidecar` : `swift test` vérifie les garde-fous, la fusion d'état, la persistance et les
actions groupées sans couper aucun vrai écran. Le matériel réel est testé à la main.

## Publier une version

1. Incrémenter `CFBundleShortVersionString` dans `Resources/Info.plist`.
2. Ajouter une section `## [x.y.z] - date` à `CHANGELOG.md` (sert de notes de version).
3. `git tag vx.y.z && git push origin vx.y.z` → `release.yml` teste, compile le zip universel
   et crée la release GitHub. Le tag doit correspondre à la version du plist.
