# DisplaySwitch

[![CI](https://github.com/AlexandreBeauduin/DisplaySwitch/actions/workflows/ci.yml/badge.svg)](https://github.com/AlexandreBeauduin/DisplaySwitch/actions/workflows/ci.yml)

[English](README.md) · **Français**

Petite app de barre des menus macOS (et outil en ligne de commande) pour connecter /
déconnecter des écrans — **y compris un iPad utilisé en Sidecar** — sans débrancher de câble.

> **Vibe codé.** Ce projet a été réalisé en conversant avec un assistant de code IA
> (Claude Code) : l'humain a décrit ce qu'il voulait, testé sur son matériel et orienté ;
> l'IA a étudié les API macOS et écrit le code et la doc. Ça marche sur la machine de
> l'auteur ; lis le code avant de t'y fier sur la tienne.

## Fonctionnalités

- Liste des écrans et des iPad Sidecar, mise à jour automatiquement.
- Connexion / déconnexion de chacun depuis le menu.
- **Tout sauf l'écran principal** (iPad compris) / **Tout reconnecter**.
- Mémoire de ce qui a été coupé (un écran coupé disparaît des listes de macOS).
- Lancement au démarrage.
- Garde-fous : jamais le dernier écran physique, écran intégré protégé, tout est
  reconnecté en quittant (par défaut).

## Installation

**Téléchargement :** récupère `DisplaySwitch-x.y.z.zip` sur la page
[Releases](https://github.com/AlexandreBeauduin/DisplaySwitch/releases), décompresse, place
`DisplaySwitch.app` dans `/Applications`. Binaire universel (Apple Silicon + Intel), macOS 14+.

**Depuis les sources** (Xcode 16 ou plus récent) :

```bash
scripts/build-app.sh --install   # compile et copie DisplaySwitch.app dans /Applications
```

Une copie téléchargée n'est pas signée avec un Developer ID : macOS la bloque au premier
lancement → Réglages Système › Confidentialité et sécurité › **Ouvrir quand même**.

## CLI

```bash
build/displayctl list
build/displayctl off <id>                 # --force pour autoriser l'écran intégré
build/displayctl on <id>
build/displayctl sidecar off [nom|uuid]   # iPad
build/displayctl sidecar on  [nom|uuid]
build/displayctl on-all                   # secours : rallume tout ce qui a été coupé
build/displayctl only-main                # tout sauf l'écran principal (iPad compris)
build/displayctl detect                   # demande à macOS de redétecter les écrans
build/displayctl debug
```

## Fonctionnement (en bref)

- Écrans physiques : appel privé CoreGraphics `CGSConfigureDisplayEnabled` dans une
  transaction de configuration d'écrans.
- iPad Sidecar : framework privé `SidecarCore` (`connectToDevice:` / `disconnectFromDevice:`).
- Tous les symboles privés sont résolus au runtime (`dlsym`), aucune édition de liens avec
  un framework privé.

Détails : [Fonctionnement](docs/fr/FONCTIONNEMENT.md) · [Sidecar](docs/fr/SIDECAR.md) ·
[Architecture](docs/fr/ARCHITECTURE.md)

## Développement

```bash
swift test                 # tests unitaires (garde-fous, état, persistance) — aucun vrai écran touché
swift build                # build debug
scripts/release.sh         # build universel + build/DisplaySwitch-<version>.zip
```

Publier une version : incrémenter `CFBundleShortVersionString` dans `Resources/Info.plist`,
ajouter une section à [CHANGELOG.md](CHANGELOG.md), puis pousser le tag correspondant
(`git tag v1.2.0 && git push origin v1.2.0`) : GitHub Actions teste, compile et publie la release.

## Limites

- Repose sur des **API privées d'Apple** : une mise à jour de macOS peut casser une
  fonction ; l'app affiche alors une erreur au lieu de planter. Pas d'App Store possible.
- En dernier recours si un écran reste éteint : débrancher / rebrancher, ou redémarrer.

## Licence et avertissement

MIT — voir [LICENSE](LICENSE). Fourni **tel quel, sans aucune garantie**. Ce projet n'est ni
affilié à Apple ni approuvé par Apple. Il modifie la configuration de tes écrans via des API
non documentées : à utiliser à tes risques.
