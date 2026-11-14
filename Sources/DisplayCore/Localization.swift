import Foundation

/// Supported UI languages. English is the fallback.
public enum Language: String, CaseIterable, Sendable {
    case en, fr, nl, de

    /// Name of the language in itself (for the language picker).
    public var nativeName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .nl: return "Nederlands"
        case .de: return "Deutsch"
        }
    }

    /// First supported language in the given preference list (e.g. Locale.preferredLanguages).
    public static func preferred(from identifiers: [String]) -> Language {
        for identifier in identifiers {
            let code = String(identifier.prefix { $0 != "-" && $0 != "_" }).lowercased()
            if let language = Language(rawValue: code) { return language }
        }
        return .en
    }
}

/// All user-facing strings, in one place.
/// To add a language: add a case to `Language`, then a column to every `t(...)` call
/// (the compiler lists the missing ones).
public enum L10n {
    /// Override with `DISPLAYSWITCH_LANG=fr` (CLI) or the app's language menu.
    public static var language: Language = {
        if let env = ProcessInfo.processInfo.environment["DISPLAYSWITCH_LANG"], let lang = Language(rawValue: env.lowercased()) {
            return lang
        }
        return Language.preferred(from: Locale.preferredLanguages)
    }()

    static func t(en: String, fr: String, nl: String, de: String) -> String {
        switch language {
        case .en: return en
        case .fr: return fr
        case .nl: return nl
        case .de: return de
        }
    }

    // MARK: - Display names

    public static var builtinDisplay: String {
        t(en: "Built-in display", fr: "Écran intégré", nl: "Ingebouwd scherm", de: "Integrierter Bildschirm")
    }
    public static func display(_ id: UInt32) -> String {
        t(en: "Display \(id)", fr: "Écran \(id)", nl: "Scherm \(id)", de: "Bildschirm \(id)")
    }

    // MARK: - Errors

    public static func apiUnavailable(_ name: String) -> String {
        t(en: "Private API not found: \(name) (macOS may have changed)",
          fr: "API privée introuvable : \(name) (macOS a peut-être changé)",
          nl: "Privé-API niet gevonden: \(name) (macOS is mogelijk gewijzigd)",
          de: "Private API nicht gefunden: \(name) (macOS hat sich möglicherweise geändert)")
    }
    public static func cgError(_ code: Int32) -> String {
        t(en: "CoreGraphics returned error \(code)",
          fr: "CoreGraphics a renvoyé l'erreur \(code)",
          nl: "CoreGraphics gaf fout \(code)",
          de: "CoreGraphics meldete Fehler \(code)")
    }
    public static var lastActiveDisplay: String {
        t(en: "Refused: this is the last active physical display",
          fr: "Refusé : ce serait le dernier écran physique actif",
          nl: "Geweigerd: dit is het laatste actieve fysieke scherm",
          de: "Abgelehnt: Dies ist der letzte aktive physische Bildschirm")
    }
    public static var builtinProtected: String {
        t(en: "Refused: the built-in display is protected (use --force to override)",
          fr: "Refusé : l'écran intégré est protégé (utilise --force pour passer outre)",
          nl: "Geweigerd: het ingebouwde scherm is beschermd (gebruik --force om dit te omzeilen)",
          de: "Abgelehnt: Der integrierte Bildschirm ist geschützt (mit --force übergehen)")
    }
    public static func unknownDisplay(_ id: UInt32) -> String {
        t(en: "Unknown display: \(id)", fr: "Écran inconnu : \(id)", nl: "Onbekend scherm: \(id)", de: "Unbekannter Bildschirm: \(id)")
    }
    public static var airPlayDisplay: String {
        t(en: "AirPlay/Sidecar display: use the sidecar commands",
          fr: "Écran AirPlay/Sidecar : utilise les commandes sidecar",
          nl: "AirPlay/Sidecar-scherm: gebruik de sidecar-commando's",
          de: "AirPlay/Sidecar-Bildschirm: verwende die sidecar-Befehle")
    }
    public static var sidecarUnsupported: String {
        t(en: "Sidecar unavailable (SidecarCore not found or Mac not compatible)",
          fr: "Sidecar indisponible (SidecarCore introuvable ou Mac non compatible)",
          nl: "Sidecar niet beschikbaar (SidecarCore niet gevonden of Mac niet compatibel)",
          de: "Sidecar nicht verfügbar (SidecarCore nicht gefunden oder Mac nicht kompatibel)")
    }
    public static func sidecarNotFound(_ id: String) -> String {
        t(en: "Sidecar device not found or out of range: \(id)",
          fr: "Appareil Sidecar introuvable ou hors de portée : \(id)",
          nl: "Sidecar-apparaat niet gevonden of buiten bereik: \(id)",
          de: "Sidecar-Gerät nicht gefunden oder außer Reichweite: \(id)")
    }
    public static func sidecarFailed(_ message: String) -> String { "Sidecar: \(message)" }
    public static var timeout: String {
        t(en: "timed out", fr: "délai dépassé", nl: "time-out", de: "Zeitüberschreitung")
    }

    // MARK: - Menu (app)

    public static var displays: String { t(en: "Displays", fr: "Écrans", nl: "Schermen", de: "Bildschirme") }
    public static var main: String { t(en: "main", fr: "principal", nl: "hoofdscherm", de: "Hauptbildschirm") }
    public static var builtinProtectedTag: String {
        t(en: "built-in, protected", fr: "intégré, protégé", nl: "ingebouwd, beschermd", de: "integriert, geschützt")
    }
    public static var inProgress: String { t(en: "in progress…", fr: "en cours…", nl: "bezig…", de: "läuft…") }
    public static var outOfRange: String { t(en: "out of range", fr: "hors de portée", nl: "buiten bereik", de: "außer Reichweite") }
    public static var allButMain: String {
        t(en: "All but the main display", fr: "Tout sauf l'écran principal", nl: "Alles behalve het hoofdscherm", de: "Alles außer Hauptbildschirm")
    }
    public static var working: String { t(en: "Working…", fr: "En cours…", nl: "Bezig…", de: "Läuft…") }
    public static var reconnectAll: String { t(en: "Reconnect all", fr: "Tout reconnecter", nl: "Alles opnieuw verbinden", de: "Alle wieder verbinden") }
    public static var launchAtLogin: String {
        t(en: "Launch at login", fr: "Lancer au démarrage", nl: "Openen bij inloggen", de: "Bei der Anmeldung starten")
    }
    public static func launchAtLoginError(_ message: String) -> String { "\(launchAtLogin): \(message)" }
    public static var reconnectOnQuit: String {
        t(en: "Reconnect all on quit", fr: "Tout reconnecter en quittant", nl: "Alles opnieuw verbinden bij stoppen", de: "Beim Beenden alle wieder verbinden")
    }
    public static var languageMenu: String { t(en: "Language", fr: "Langue", nl: "Taal", de: "Sprache") }
    public static var systemLanguage: String { t(en: "System", fr: "Système", nl: "Systeem", de: "System") }
    public static var quit: String {
        t(en: "Quit DisplaySwitch", fr: "Quitter DisplaySwitch", nl: "DisplaySwitch stoppen", de: "DisplaySwitch beenden")
    }

    // MARK: - CLI

    public static var usage: String {
        t(en: """
          displayctl — connect / disconnect displays and Sidecar iPads

          Physical displays
            displayctl list                    list displays + Sidecar devices
            displayctl off <id> [--force]      disconnect a display (--force: allow the built-in one)
            displayctl on <id>                 reconnect a display

          Sidecar (iPad)
            displayctl sidecar off [name|uuid] disconnect the iPad (the only connected one if omitted)
            displayctl sidecar on  [name|uuid] connect the iPad (the only available one if omitted)

          Global
            displayctl on-all                  reconnect everything DisplaySwitch disconnected
            displayctl only-main               disconnect everything but the main display (iPad included)
            displayctl detect                  ask macOS to re-detect displays
            displayctl debug                   raw lists

          Language: DISPLAYSWITCH_LANG=en|fr|nl|de
          """,
          fr: """
          displayctl — connecter / déconnecter des écrans et des iPad Sidecar

          Écrans physiques
            displayctl list                    liste écrans + appareils Sidecar
            displayctl off <id> [--force]      déconnecte un écran (--force : autorise l'écran intégré)
            displayctl on <id>                 reconnecte un écran

          Sidecar (iPad)
            displayctl sidecar off [nom|uuid]  déconnecte l'iPad (le seul connecté si omis)
            displayctl sidecar on  [nom|uuid]  connecte l'iPad (le seul disponible si omis)

          Global
            displayctl on-all                  reconnecte tout ce que DisplaySwitch a coupé
            displayctl only-main               déconnecte tout sauf l'écran principal (iPad compris)
            displayctl detect                  demande à macOS de redétecter les écrans
            displayctl debug                   listes brutes

          Langue : DISPLAYSWITCH_LANG=en|fr|nl|de
          """,
          nl: """
          displayctl — schermen en Sidecar-iPads verbinden / loskoppelen

          Fysieke schermen
            displayctl list                    schermen + Sidecar-apparaten tonen
            displayctl off <id> [--force]      scherm loskoppelen (--force: ook het ingebouwde)
            displayctl on <id>                 scherm opnieuw verbinden

          Sidecar (iPad)
            displayctl sidecar off [naam|uuid] iPad loskoppelen (de enige verbonden als weggelaten)
            displayctl sidecar on  [naam|uuid] iPad verbinden (de enige beschikbare als weggelaten)

          Algemeen
            displayctl on-all                  alles opnieuw verbinden wat DisplaySwitch heeft losgekoppeld
            displayctl only-main               alles behalve het hoofdscherm loskoppelen (iPad inbegrepen)
            displayctl detect                  macOS de schermen opnieuw laten detecteren
            displayctl debug                   ruwe lijsten

          Taal: DISPLAYSWITCH_LANG=en|fr|nl|de
          """,
          de: """
          displayctl — Bildschirme und Sidecar-iPads verbinden / trennen

          Physische Bildschirme
            displayctl list                    Bildschirme + Sidecar-Geräte auflisten
            displayctl off <id> [--force]      Bildschirm trennen (--force: auch den integrierten)
            displayctl on <id>                 Bildschirm wieder verbinden

          Sidecar (iPad)
            displayctl sidecar off [name|uuid] iPad trennen (das einzige verbundene, wenn weggelassen)
            displayctl sidecar on  [name|uuid] iPad verbinden (das einzige verfügbare, wenn weggelassen)

          Allgemein
            displayctl on-all                  alles wieder verbinden, was DisplaySwitch getrennt hat
            displayctl only-main               alles außer dem Hauptbildschirm trennen (iPad inklusive)
            displayctl detect                  macOS die Bildschirme neu erkennen lassen
            displayctl debug                   Rohlisten

          Sprache: DISPLAYSWITCH_LANG=en|fr|nl|de
          """)
    }
    public static func error(_ message: String) -> String {
        t(en: "Error: \(message)", fr: "Erreur : \(message)", nl: "Fout: \(message)", de: "Fehler: \(message)")
    }
    public static var invalidID: String {
        t(en: "missing or invalid display id", fr: "id d'écran manquant ou invalide", nl: "ontbrekende of ongeldige scherm-id", de: "fehlende oder ungültige Bildschirm-ID")
    }
    public static var displaysHeader: String { displays.uppercased() }
    public static var stateHeader: String { t(en: "STATE", fr: "ÉTAT", nl: "STATUS", de: "STATUS") }
    public static var nameHeader: String { t(en: "NAME", fr: "NOM", nl: "NAAM", de: "NAME") }
    public static var builtin: String { t(en: "built-in", fr: "intégré", nl: "ingebouwd", de: "integriert") }
    public static var disconnectedByUs: String {
        t(en: "disconnected by DisplaySwitch", fr: "coupé par DisplaySwitch", nl: "losgekoppeld door DisplaySwitch", de: "von DisplaySwitch getrennt")
    }
    public static var connected: String { t(en: "connected", fr: "connecté", nl: "verbonden", de: "verbunden") }
    public static var disconnected: String { t(en: "disconnected", fr: "déconnecté", nl: "losgekoppeld", de: "getrennt") }
    public static var unavailable: String { t(en: "unavailable", fr: "indisponible", nl: "niet beschikbaar", de: "nicht verfügbar") }
    public static var noIPadInRange: String {
        t(en: "no iPad in range", fr: "aucun iPad à portée", nl: "geen iPad binnen bereik", de: "kein iPad in Reichweite")
    }
    public static var noIPadToConnect: String {
        t(en: "no iPad to connect", fr: "aucun iPad à connecter", nl: "geen iPad om te verbinden", de: "kein iPad zum Verbinden")
    }
    public static var noIPadConnected: String {
        t(en: "no iPad connected", fr: "aucun iPad connecté", nl: "geen iPad verbonden", de: "kein iPad verbunden")
    }
    public static var severalIPads: String {
        t(en: "several iPads: give the name or uuid", fr: "plusieurs iPad : précise le nom ou l'uuid",
          nl: "meerdere iPads: geef de naam of uuid op", de: "mehrere iPads: Name oder UUID angeben")
    }
}
