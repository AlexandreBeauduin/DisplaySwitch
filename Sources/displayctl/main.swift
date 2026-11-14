import CoreGraphics
import DisplayCore
import Foundation

let usage = L10n.usage

let args = Array(CommandLine.arguments.dropFirst())
let manager = DisplayManager()

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((L10n.error(message) + "\n").utf8))
    exit(1)
}

func parseID(_ index: Int) -> CGDirectDisplayID {
    guard args.count > index, let id = CGDirectDisplayID(args[index]) else { fail("\(L10n.invalidID)\n\n\(usage)") }
    return id
}

func pad(_ s: String, _ n: Int) -> String { s.padding(toLength: max(n, s.count + 1), withPad: " ", startingAt: 0) }

func printList() {
    _ = SidecarManager.shared.waitForDevices()
    let rows = manager.refresh()
    print(L10n.displaysHeader)
    print(pad("ID", 12) + pad(L10n.stateHeader, 14) + L10n.nameHeader)
    for d in rows {
        var tags: [String] = []
        if d.isMain { tags.append(L10n.main) }
        if d.isBuiltin { tags.append(L10n.builtin) }
        if !d.isActive && d.disconnectedByUs { tags.append(L10n.disconnectedByUs) }
        let suffix = tags.isEmpty ? "" : "  (\(tags.joined(separator: ", ")))"
        print(pad(String(d.id), 12) + pad(d.isActive ? L10n.connected : L10n.disconnected, 14) + d.name + suffix)
    }
    let sidecars = manager.sidecarStatuses()
    print("\nSIDECAR" + (SidecarManager.shared.isSupported ? "" : " (\(L10n.unavailable))"))
    if sidecars.isEmpty { print("  " + L10n.noIPadInRange) }
    for s in sidecars {
        let state = !s.isAvailable ? L10n.outOfRange : (s.isConnected ? L10n.connected : L10n.disconnected)
        print(pad(String(s.id.prefix(8)) + "…", 12) + pad(state, 14) + "\(s.name) (\(s.model))")
    }
}

func report(_ failures: [String: Error]?) {
    guard let failures else { fail(L10n.timeout) }
    for (name, error) in failures { FileHandle.standardError.write(Data("  \(name) : \(error)\n".utf8)) }
    if !failures.isEmpty { exit(1) }
}

/// Resolve the target iPad: explicit name/uuid, or the only sensible candidate.
func resolveSidecar(connecting: Bool) -> String {
    let devices = SidecarManager.shared.waitForDevices()
    if args.count > 2 {
        let query = args[2...].joined(separator: " ")
        guard let device = SidecarManager.shared.find(query) else { fail(SidecarError.deviceNotFound(query).description) }
        return device.id
    }
    let candidates = devices.filter { $0.isConnected != connecting }
    guard candidates.count == 1, let device = candidates.first else {
        fail(candidates.isEmpty ? (connecting ? L10n.noIPadToConnect : L10n.noIPadConnected) : L10n.severalIPads)
    }
    return device.id
}

switch args.first {
case "list", nil:
    printList()
case "debug":
    let system = SystemDisplays()
    print("active :", system.activeDisplayIDs())
    print("online :", system.onlineDisplayIDs())
    print("CGS    :", system.privateDisplayIDs().map { "\($0)" } ?? "unavailable", "(contains ghost IDs)")
    print("main   :", system.mainDisplayID())
    print("airplay:", system.activeDisplayIDs().filter(system.isAirPlay))
    print("sidecar:", SidecarManager.shared.waitForDevices())
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
    case nil: fail(L10n.timeout)
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
