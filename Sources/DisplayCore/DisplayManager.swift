import AppKit
import CoreGraphics
import Foundation

public enum DisplayError: Error, CustomStringConvertible {
    case apiUnavailable(String)
    case cgError(CGError)
    case lastActiveDisplay
    case builtinProtected
    case unknownDisplay(CGDirectDisplayID)
    case airPlayDisplay

    public var description: String {
        switch self {
        case .apiUnavailable(let name): return "API privée introuvable : \(name) (macOS a peut-être changé)"
        case .cgError(let err): return "CoreGraphics a renvoyé l'erreur \(err.rawValue)"
        case .lastActiveDisplay: return "Refusé : ce serait le dernier écran physique actif"
        case .builtinProtected: return "Refusé : l'écran intégré est protégé (utilise --force pour passer outre)"
        case .unknownDisplay(let id): return "Écran inconnu : \(id)"
        case .airPlayDisplay: return "Écran AirPlay/Sidecar : utilise les commandes sidecar"
        }
    }
}

public struct DisplayStatus: Identifiable, Equatable, Sendable {
    public var id: CGDirectDisplayID
    public var name: String
    public var isBuiltin: Bool
    public var isMain: Bool
    /// Active = part of the desktop layout (shown in System Settings > Displays).
    public var isActive: Bool
    public var disconnectedByUs: Bool
}

public struct SidecarStatus: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var model: String
    /// In range and usable right now (listed by SidecarCore).
    public var isAvailable: Bool
    public var isConnected: Bool
    public var disconnectedByUs: Bool
}

public final class DisplayManager {
    public let store: DisplayStore
    public let system: DisplaySystem
    public let sidecar: SidecarControlling

    public init(store: DisplayStore = DisplayStore(),
                system: DisplaySystem = SystemDisplays(),
                sidecar: SidecarControlling = SidecarManager.shared) {
        self.store = store
        self.system = system
        self.sidecar = sidecar
    }

    /// Displays that keep the Mac usable: active, not AirPlay/Sidecar.
    public func physicalActiveDisplayIDs() -> [CGDirectDisplayID] {
        system.activeDisplayIDs().filter { !system.isAirPlay($0) }
    }

    // MARK: - State

    /// Merge live system state with remembered displays and return a sorted list
    /// of physical displays (AirPlay/Sidecar excluded, see sidecarStatuses()).
    @discardableResult
    public func refresh() -> [DisplayStatus] {
        store.load()
        let active = Set(system.activeDisplayIDs())
        let online = Set(system.onlineDisplayIDs())
        let main = system.mainDisplayID()

        for id in active.union(online) where system.isAirPlay(id) {
            store.forget(id)
        }
        for id in active where !system.isAirPlay(id) {
            let builtin = system.isBuiltin(id)
            let fallback = store.displays[id]?.name ?? (builtin ? "Écran intégré" : "Écran \(id)")
            store.remember(id: id, name: system.name(of: id) ?? fallback, uuid: system.uuid(of: id), isBuiltin: builtin)
            // Reconnected outside of DisplaySwitch (cable, other tool): clear our flag.
            store.setDisconnectedByUs(id, false)
        }
        // Prune displays that are gone and that we are not responsible for.
        for known in store.displays.values
        where !active.contains(known.id) && !online.contains(known.id) && !known.disconnectedByUs {
            store.forget(known.id)
        }
        for device in sidecar.devices() {
            store.rememberSidecar(device)
            if device.isConnected { store.setSidecarDisconnectedByUs(device.id, false) }
        }
        store.save()

        return store.displays.values.map { known in
            DisplayStatus(
                id: known.id,
                name: known.name,
                isBuiltin: known.isBuiltin,
                isMain: known.id == main,
                isActive: active.contains(known.id),
                disconnectedByUs: known.disconnectedByUs
            )
        }
        .sorted { ($0.isMain ? 0 : 1, $0.name) < ($1.isMain ? 0 : 1, $1.name) }
    }

    /// Sidecar devices: those in range, plus those we disconnected (even if out of range).
    public func sidecarStatuses() -> [SidecarStatus] {
        let live = Dictionary(sidecar.devices().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return store.sidecars.values
            .filter { live[$0.id] != nil || $0.disconnectedByUs }
            .map { known in
                SidecarStatus(
                    id: known.id,
                    name: known.name,
                    model: known.model,
                    isAvailable: live[known.id] != nil,
                    isConnected: live[known.id]?.isConnected ?? false,
                    disconnectedByUs: known.disconnectedByUs
                )
            }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Physical display actions (synchronous)

    public func disconnect(_ id: CGDirectDisplayID, allowBuiltin: Bool = false) throws {
        refresh()
        let active = system.activeDisplayIDs()
        guard active.contains(id) else {
            if store.displays[id] == nil { throw DisplayError.unknownDisplay(id) }
            return // already inactive
        }
        if system.isAirPlay(id) { throw DisplayError.airPlayDisplay }
        if physicalActiveDisplayIDs().filter({ $0 != id }).isEmpty { throw DisplayError.lastActiveDisplay }
        if system.isBuiltin(id) && !allowBuiltin { throw DisplayError.builtinProtected }

        try system.setEnabled(id, false)
        store.setDisconnectedByUs(id, true)
        store.save()
    }

    public func connect(_ id: CGDirectDisplayID) throws {
        refresh()
        if system.isAirPlay(id) { throw DisplayError.airPlayDisplay }
        try system.setEnabled(id, true)
        store.setDisconnectedByUs(id, false)
        store.save()
    }

    public func detectDisplays() {
        system.detectDisplays()
    }

    // MARK: - Sidecar actions (asynchronous, completion on main queue)

    public func connectSidecar(_ id: String, completion: @escaping (Error?) -> Void) {
        sidecar.connect(id) { [store] error in
            if error == nil { store.load(); store.setSidecarDisconnectedByUs(id, false); store.save() }
            completion(error)
        }
    }

    public func disconnectSidecar(_ id: String, completion: @escaping (Error?) -> Void) {
        sidecar.disconnect(id) { [store] error in
            if error == nil { store.load(); store.setSidecarDisconnectedByUs(id, true); store.save() }
            completion(error)
        }
    }

    // MARK: - Bulk actions (completion on main queue with failures keyed by display name)

    /// Re-enable every display and Sidecar device we disconnected, then ask macOS to re-detect.
    public func reconnectAll(completion: @escaping ([String: Error]) -> Void) {
        refresh()
        var failures: [String: Error] = [:]
        for known in store.displays.values where known.disconnectedByUs {
            do {
                try system.setEnabled(known.id, true)
                store.setDisconnectedByUs(known.id, false)
            } catch {
                failures[known.name] = error
            }
        }
        store.save()
        detectDisplays()

        let group = DispatchGroup()
        for device in sidecarStatuses() where device.disconnectedByUs && device.isAvailable && !device.isConnected {
            group.enter()
            connectSidecar(device.id) { error in
                if let error { failures[device.name] = error }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(failures) }
    }

    /// Disconnect every display except the main one (the one with the menu bar),
    /// including Sidecar devices.
    public func disconnectAllButMain(allowBuiltin: Bool = false, completion: @escaping ([String: Error]) -> Void) {
        let main = system.mainDisplayID()
        var failures: [String: Error] = [:]
        for id in physicalActiveDisplayIDs() where id != main {
            if system.isBuiltin(id) && !allowBuiltin { continue }
            do { try disconnect(id, allowBuiltin: allowBuiltin) } catch {
                failures[store.displays[id]?.name ?? "\(id)"] = error
            }
        }

        let group = DispatchGroup()
        for device in sidecarStatuses() where device.isConnected {
            group.enter()
            disconnectSidecar(device.id) { error in
                if let error { failures[device.name] = error }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(failures) }
    }
}

/// Helper for command-line use: run an async-with-completion operation and spin
/// the main run loop until it finishes (main thread only).
public func runSync<T>(timeout: TimeInterval = 30, _ start: (@escaping (T) -> Void) -> Void) -> T? {
    var result: T?
    start { result = $0 }
    let deadline = Date().addingTimeInterval(timeout)
    while result == nil && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
    return result
}
