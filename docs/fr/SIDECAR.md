# Sidecar (iPad) — API SidecarCore

[English](../en/SIDECAR.md)

## Problème

Un iPad en Sidecar apparaît comme un écran CoreGraphics, mais `CGSConfigureDisplayEnabled`
ne le coupe pas.

## Le reconnaître côté CoreGraphics

| Propriété | Valeur |
|---|---|
| `CGDisplayVendorNumber` | `0x6161706c` (`'aapl'`) — commun AirPlay / Sidecar |
| `CGDisplayModelNumber` | `0x69506164` (`'iPad'`) |
| `CGDirectDisplayID` | **change à chaque reconnexion** (ex. 10 → 11) |

DisplaySwitch exclut donc ces écrans de la liste « Écrans » (`isAirPlay`) et identifie
l'iPad par l'UUID de son `SidecarDevice`, qui est stable.

## API (privée, résolue au runtime)

Framework : `/System/Library/PrivateFrameworks/SidecarCore.framework`

```objc
SidecarDisplayManager *m = [SidecarDisplayManager sharedManager];
m.devices;            // NSArray<SidecarDevice*> à portée (rempli en asynchrone, ~2 s)
m.connectedDevices;   // ceux actuellement utilisés en Sidecar
[m connectToDevice:dev completion:^(NSError *e){}];
[m disconnectFromDevice:dev completion:^(NSError *e){}];

SidecarDevice : identifier (NSUUID), name, model (ex. "iPad13,10")
```

Appel depuis Swift : `method(for:)` + `unsafeBitCast` vers
`@convention(c) (AnyObject, Selector, AnyObject, @convention(block) (NSError?) -> Void) -> Void`
(voir `Sources/DisplayCore/SidecarManager.swift`).

## Comportement mesuré

- Déconnexion : quasi immédiate.
- Reconnexion : ~5,6 s ; l'écran revient avec un **nouveau** `CGDirectDisplayID`.
- `devices` est vide juste après `sharedManager` : il faut laisser tourner le run loop
  (~2 s) → `waitForDevices()` côté CLI ; l'app a un run loop permanent.
- Pas de notification publique connue quand un iPad arrive à portée : l'app interroge
  `devices` toutes les 5 s (en mémoire, peu coûteux) et se rafraîchit aussi via
  `CGDisplayRegisterReconfigurationCallback`.

## Intégration

- Menu : section « Sidecar » (un interrupteur par iPad, états « en cours… » / « hors de portée »).
- « Tout sauf l'écran principal » coupe aussi les iPad connectés.
- « Tout reconnecter » reconnecte les iPad coupés par DisplaySwitch, s'ils sont disponibles.
- Quitter avec « Tout reconnecter en quittant » : `applicationShouldTerminate` renvoie
  `.terminateLater` et attend la fin (15 s max).
- CLI : `displayctl sidecar off|on [nom|uuid]`.

## Piège : crash « non-escaping closure has escaped »

Une closure littérale passée directement en argument `@convention(block)` d'un pointeur de
fonction est compilée comme bloc **non-escaping**. SidecarCore la retient pour l'appeler
plus tard, et le runtime Swift arrête le process (`EXC_BREAKPOINT`). Correctif : construire
d'abord le bloc dans un `let block: Completion = { … }`, puis le passer.

## Limites

API privée : peut casser avec une mise à jour de macOS ; `isSupported` passe alors à
`false` et les actions Sidecar renvoient une erreur explicite au lieu de planter.
