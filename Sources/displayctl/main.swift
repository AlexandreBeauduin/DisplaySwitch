import CoreGraphics
import DisplayCore
import Foundation

let usage = """
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
"""

let args = Array(CommandLine.arguments.dropFirst())
let manager = DisplayManager()

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Erreur : \(message)\n".utf8))
    exit(1)
}

func parseID(_ index: Int) -> CGDirectDisplayID {
    guard args.count > index, let id = CGDirectDisplayID(args[index]) else { fail("id d'écran manquant ou invalide\n\n\(usage)") }
    return id
}

func pad(_ s: String, _ n: Int) -> String { s.padding(toLength: max(n, s.count + 1), withPad: " ", startingAt: 0) }

func printList() {
    _ = manager.sidecar.waitForDevices()
    let rows = manager.refresh()
    print("ÉCRANS")
    print(pad("ID", 12) + pad("ÉTAT", 14) + "NOM")
    for d in rows {
        var tags: [String] = []
        if d.isMain { tags.append("principal") }
        if d.isBuiltin { tags.append("intégré") }
        if !d.isActive && d.disconnectedByUs { tags.append("coupé par DisplaySwitch") }
        let suffix = tags.isEmpty ? "" : "  (\(tags.joined(separator: ", ")))"
        print(pad(String(d.id), 12) + pad(d.isActive ? "connecté" : "déconnecté", 14) + d.name + suffix)
    }
    let sidecars = manager.sidecarStatuses()
    print("\nSIDECAR" + (manager.sidecar.isSupported ? "" : " (indisponible)"))
    if sidecars.isEmpty { print("  aucun iPad à portée") }
    for s in sidecars {
        let state = !s.isAvailable ? "hors portée" : (s.isConnected ? "connecté" : "déconnecté")
        print(pad(String(s.id.prefix(8)) + "…", 12) + pad(state, 14) + "\(s.name) (\(s.model))")
    }
}

func report(_ failures: [String: Error]?) {
    guard let failures else { fail("délai dépassé") }
    for (name, error) in failures { FileHandle.standardError.write(Data("  \(name) : \(error)\n".utf8)) }
    if !failures.isEmpty { exit(1) }
}

/// Resolve the target iPad: explicit name/uuid, or the only sensible candidate.
func resolveSidecar(connecting: Bool) -> String {
    let devices = manager.sidecar.waitForDevices()
    if args.count > 2 {
        let query = args[2...].joined(separator: " ")
        guard let device = manager.sidecar.find(query) else { fail(SidecarError.deviceNotFound(query).description) }
        return device.id
    }
    let candidates = devices.filter { $0.isConnected != connecting }
    guard candidates.count == 1, let device = candidates.first else {
        fail(candidates.isEmpty ? "aucun iPad \(connecting ? "à connecter" : "connecté")" : "plusieurs iPad : précise le nom ou l'uuid")
    }
    return device.id
}

switch args.first {
case "list", nil:
    printList()
case "debug":
    print("actifs :", DisplayManager.activeDisplayIDs())
    print("online :", DisplayManager.onlineDisplayIDs())
    print("CGS    :", DisplayManager.privateDisplayIDs().map { "\($0)" } ?? "indisponible", "(contient des IDs fantômes)")
    print("main   :", CGMainDisplayID())
    print("airplay:", DisplayManager.activeDisplayIDs().filter(DisplayManager.isAirPlay))
    print("sidecar:", manager.sidecar.waitForDevices())
case "off":
    do { try manager.disconnect(parseID(1), allowBuiltin: args.contains("--force")) } catch { fail("\(error)") }
    printList()
case "on":
    do { try manager.connect(parseID(1)) } catch { fail("\(error)") }
    printList()
case "sidecar":
    guard args.count > 1, ["on", "off"].contains(args[1]) else { print(usage); exit(1) }
    let connecting = args[1] == "on"
    let id = resolveSidecar(connecting: connecting)
    let result: Error?? = runSync { done in
        connecting ? manager.connectSidecar(id, completion: done) : manager.disconnectSidecar(id, completion: done)
    }
    switch result {
    case nil: fail("délai dépassé")
    case .some(.some(let error)): fail("\(error)")
    default: break
    }
    RunLoop.main.run(until: Date().addingTimeInterval(1)) // let the display list settle
    printList()
case "on-all":
    report(runSync { manager.reconnectAll(completion: $0) })
    printList()
case "only-main":
    report(runSync { manager.disconnectAllButMain(completion: $0) })
    printList()
case "detect":
    manager.detectDisplays()
    printList()
default:
    print(usage)
}
