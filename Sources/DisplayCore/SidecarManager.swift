import Foundation

/// A Sidecar-capable device (iPad) as reported by SidecarCore.
public struct SidecarDeviceInfo: Identifiable, Equatable, Sendable {
    /// SidecarDevice.identifier (stable across reconnections, unlike the CGDirectDisplayID).
    public var id: String
    public var name: String
    public var model: String
    public var isConnected: Bool
}

public enum SidecarError: Error, CustomStringConvertible {
    case unsupported
    case deviceNotFound(String)
    case failed(String)
    case timeout

    public var description: String {
        switch self {
        case .unsupported: return "Sidecar indisponible (SidecarCore introuvable ou Mac non compatible)"
        case .deviceNotFound(let id): return "Appareil Sidecar introuvable ou hors de portée : \(id)"
        case .failed(let message): return "Sidecar : \(message)"
        case .timeout: return "Sidecar : délai dépassé"
        }
    }
}

/// Wrapper around the private SidecarCore framework:
///   SidecarDisplayManager.sharedManager
///     .devices / .connectedDevices            -> [SidecarDevice]
///     -connectToDevice:completion:            completion: ^(NSError *)
///     -disconnectFromDevice:completion:
/// Everything is resolved at runtime; if Apple changes the API, isSupported is false.
public final class SidecarManager {
    public static let shared = SidecarManager()

    private typealias Completion = @convention(block) (NSError?) -> Void
    private typealias DeviceActionFn = @convention(c) (AnyObject, Selector, AnyObject, Completion) -> Void

    private let manager: NSObject?
    private let connectSel = NSSelectorFromString("connectToDevice:completion:")
    private let disconnectSel = NSSelectorFromString("disconnectFromDevice:completion:")

    private init() {
        dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore", RTLD_LAZY)
        guard let cls = NSClassFromString("SidecarDisplayManager") as? NSObject.Type,
              cls.responds(to: NSSelectorFromString("sharedManager")),
              let mgr = cls.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() as? NSObject
        else {
            manager = nil
            return
        }
        manager = mgr
    }

    public var isSupported: Bool {
        guard let manager else { return false }
        return manager.responds(to: connectSel) && manager.responds(to: disconnectSel)
    }

    private func rawDevices(_ key: String) -> [NSObject] {
        (manager?.value(forKey: key) as? [NSObject]) ?? []
    }

    private static func identifier(of device: NSObject) -> String? {
        (device.value(forKey: "identifier") as? UUID)?.uuidString
    }

    /// Devices currently available (in range / plugged) plus their connection state.
    /// The list is filled asynchronously after the first access to sharedManager.
    public func devices() -> [SidecarDeviceInfo] {
        let connected = Set(rawDevices("connectedDevices").compactMap(Self.identifier))
        return rawDevices("devices").compactMap { device in
            guard let id = Self.identifier(of: device) else { return nil }
            return SidecarDeviceInfo(
                id: id,
                name: device.value(forKey: "name") as? String ?? "iPad",
                model: device.value(forKey: "model") as? String ?? "",
                isConnected: connected.contains(id)
            )
        }
    }

    /// For command-line use: spin the main run loop until devices are discovered.
    public func waitForDevices(timeout: TimeInterval = 2) -> [SidecarDeviceInfo] {
        let deadline = Date().addingTimeInterval(timeout)
        while rawDevices("devices").isEmpty && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        return devices()
    }

    /// Accepts a device UUID or a (case-insensitive) name.
    public func find(_ query: String) -> SidecarDeviceInfo? {
        devices().first { $0.id.caseInsensitiveCompare(query) == .orderedSame }
            ?? devices().first { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }
    }

    public func connect(_ id: String, completion: @escaping (Error?) -> Void) {
        perform(connectSel, id, completion)
    }

    public func disconnect(_ id: String, completion: @escaping (Error?) -> Void) {
        perform(disconnectSel, id, completion)
    }

    private func perform(_ selector: Selector, _ id: String, _ completion: @escaping (Error?) -> Void) {
        guard isSupported, let manager else { return completion(SidecarError.unsupported) }
        guard let device = rawDevices("devices").first(where: { Self.identifier(of: $0) == id }) else {
            return completion(SidecarError.deviceNotFound(id))
        }
        let fn = unsafeBitCast(manager.method(for: selector), to: DeviceActionFn.self)
        // Must be a stored (escaping) block: SidecarCore keeps it and calls it later.
        // Passing a closure literal directly makes Swift build a non-escaping block,
        // and the runtime traps ("non-escaping closure has escaped") once SidecarCore retains it.
        let block: Completion = { error in
            let result: Error? = error.map { SidecarError.failed($0.localizedDescription) }
            DispatchQueue.main.async { completion(result) }
        }
        fn(manager, selector, device, block)
    }
}
