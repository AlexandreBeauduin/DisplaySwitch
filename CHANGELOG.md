# Changelog

All notable changes / Tous les changements notables / Alle belangrijke wijzigingen / Alle wesentlichen Änderungen.
Format: [Keep a Changelog](https://keepachangelog.com/), versions: [SemVer](https://semver.org/).

## [1.1.0] - 2026-11-14

### Added / Ajouté / Toegevoegd / Hinzugefügt
- Interface in English, French, Dutch and German, following the macOS language;
  *Language* menu to pick one. CLI: `DISPLAYSWITCH_LANG=en|fr|nl|de`.
  Interface en anglais, français, néerlandais et allemand (suit la langue de macOS, menu *Langue*).
  Interface in het Engels, Frans, Nederlands en Duits (volgt de macOS-taal, menu *Taal*).
  Oberfläche auf Englisch, Französisch, Niederländisch und Deutsch (folgt der macOS-Sprache, Menü *Sprache*).
- Documentation in Dutch and German / Documentation en néerlandais et en allemand /
  Documentatie in het Nederlands en Duits / Dokumentation auf Niederländisch und Deutsch.

### Changed / Modifié / Gewijzigd / Geändert
- English is now the default language when the macOS language is not supported
  (was French) / L'anglais devient la langue par défaut si la langue de macOS n'est pas prise en charge.

## [1.0.0] - 2026-11-14

### Added / Ajouté
- Menu bar app: list displays and Sidecar iPads, connect / disconnect each one.
  App de barre des menus : liste des écrans et iPad Sidecar, connexion / déconnexion.
- Disconnect all but the main display / Tout sauf l'écran principal (iPads included).
- Reconnect all / Tout reconnecter, also on quit / aussi en quittant (default).
- Launch at login / Lancement au démarrage.
- Safety: never the last physical display, built-in display protected.
  Garde-fous : jamais le dernier écran physique, écran intégré protégé.
- `displayctl` command line tool / outil en ligne de commande.
- Universal binary (Apple Silicon + Intel), macOS 14+.
