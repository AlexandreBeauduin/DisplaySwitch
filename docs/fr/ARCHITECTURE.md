# Architecture

[English](../en/ARCHITECTURE.md)

```
Package.swift (SwiftPM, macOS 14+, outils Swift 6 / mode de langage v5)
Sources/
  DisplayCore/            bibliothèque partagée app + CLI
    PrivateAPI.swift      dlopen/dlsym : CGSConfigureDisplayEnabled, CGSGetDisplayList, SLSDetectDisplays
    SidecarManager.swift  wrapper SidecarCore (devices, connect, disconnect)
    DisplayStore.swift    persistance JSON (écrans + iPad, drapeau disconnectedByUs)
    DisplayManager.swift  état fusionné, garde-fous, actions unitaires et groupées
  DisplaySwitch/          app barre des menus (SwiftUI MenuBarExtra, LSUIElement)
  displayctl/             CLI
Resources/Info.plist      io.github.alexandrebeauduin.DisplaySwitch
scripts/build-app.sh      build release, assemble le .app, signature ad hoc, --install
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
