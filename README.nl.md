# DisplaySwitch

[![CI](https://github.com/AlexandreBeauduin/DisplaySwitch/actions/workflows/ci.yml/badge.svg)](https://github.com/AlexandreBeauduin/DisplaySwitch/actions/workflows/ci.yml)

[English](README.md) · [Français](README.fr.md) · **Nederlands** · [Deutsch](README.de.md)

Een kleine macOS-menubalkapp (en CLI) om schermen te verbinden / los te koppelen — **ook een
iPad die als Sidecar-scherm wordt gebruikt** — zonder een kabel uit te trekken.

> **Vibe coded.** Dit project is gebouwd in gesprek met een AI-programmeerassistent
> (Claude Code): de mens beschreef het gewenste resultaat, testte op echte hardware en stuurde bij;
> de AI onderzocht de macOS-API's en schreef de code en de documentatie. Het werkt op de
> machine van de auteur; lees de code voordat je het op de jouwe vertrouwt.

## Functies

- Toont schermen en Sidecar-iPads, automatisch bijgewerkt.
- Verbind / koppel elk scherm los vanuit het menu.
- **Alles behalve het hoofdscherm** loskoppelen (iPads inbegrepen) / **Alles opnieuw verbinden**.
- Onthoudt wat het heeft losgekoppeld (een losgekoppeld scherm verdwijnt uit de lijsten van macOS).
- Openen bij inloggen.
- Interface in het **Engels, Frans, Nederlands en Duits**: volgt de taal van macOS, of kies
  er een in het menu (*Taal*).
- Veiligheid: koppelt nooit het laatste fysieke scherm los, beschermt het ingebouwde scherm,
  verbindt alles opnieuw bij het stoppen (standaard).

## Installatie

**Downloaden:** haal `DisplaySwitch-x.y.z.zip` op van de pagina
[Releases](https://github.com/AlexandreBeauduin/DisplaySwitch/releases), pak uit en zet
`DisplaySwitch.app` in `/Applications`. Universele binary (Apple Silicon + Intel), macOS 14+.

**Vanaf de broncode** (Xcode 16 of nieuwer):

```bash
scripts/build-app.sh --install   # bouwt DisplaySwitch.app en kopieert het naar /Applications
```

Een gedownloade kopie is niet ondertekend met een Developer ID: macOS blokkeert hem bij de
eerste start → Systeeminstellingen › Privacy en beveiliging › **Toch openen**.

## CLI

```bash
build/displayctl list
build/displayctl off <id>                 # --force om ook het ingebouwde scherm toe te staan
build/displayctl on <id>
build/displayctl sidecar off [naam|uuid]  # iPad
build/displayctl sidecar on  [naam|uuid]
build/displayctl on-all                   # redding: alles opnieuw verbinden wat we loskoppelden
build/displayctl only-main                # alles behalve het hoofdscherm (iPads inbegrepen)
build/displayctl detect                   # macOS de schermen opnieuw laten detecteren
build/displayctl debug
```

De CLI volgt de taal van macOS; forceer er een met `DISPLAYSWITCH_LANG=en|fr|nl|de`.

## Zo werkt het (kort)

- Fysieke schermen: private CoreGraphics-aanroep `CGSConfigureDisplayEnabled` binnen een
  schermconfiguratie-transactie.
- Sidecar-iPads: privéframework `SidecarCore` (`connectToDevice:` / `disconnectFromDevice:`).
- Alle private symbolen worden tijdens het draaien opgezocht (`dlsym`); er wordt niet tegen
  privéframeworks gelinkt.

Details: [Zo werkt het](docs/nl/HOE-HET-WERKT.md) · [Sidecar](docs/nl/SIDECAR.md) ·
[Architectuur](docs/nl/ARCHITECTUUR.md)

## Ontwikkeling

```bash
swift test                 # unittests (veiligheidsregels, status, opslag) — geen echt scherm geraakt
swift build                # debug-build
scripts/release.sh         # universele build + build/DisplaySwitch-<versie>.zip
```

Een versie uitbrengen: verhoog `CFBundleShortVersionString` in `Resources/Info.plist`, voeg
een sectie toe aan [CHANGELOG.md](CHANGELOG.md) en push dan een overeenkomende tag
(`git tag v1.2.0 && git push origin v1.2.0`): GitHub Actions test, bouwt en publiceert de release.

## Kanttekeningen

- Gebruikt **private Apple-API's**: een macOS-update kan een functie breken; de app toont dan
  een foutmelding in plaats van te crashen. Niet geschikt voor de Mac App Store.
- Laatste redmiddel als een scherm uit blijft: kabel los- en weer aankoppelen, of de Mac herstarten.

## Licentie en disclaimer

MIT — zie [LICENSE](LICENSE). Geleverd **zoals het is, zonder enige garantie**. Dit project
is niet verbonden aan of goedgekeurd door Apple. Het wijzigt je schermconfiguratie via
ongedocumenteerde API's: gebruik op eigen risico.
