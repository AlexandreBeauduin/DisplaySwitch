import AppKit
import CoreGraphics
import Foundation

/// Everything DisplayManager needs from macOS for physical displays.
/// Abstracted so the safety rules can be unit-tested without touching real screens.
public protocol DisplaySystem {
    func activeDisplayIDs() -> [CGDirectDisplayID]
    func onlineDisplayIDs() -> [CGDirectDisplayID]
    func mainDisplayID() -> CGDirectDisplayID
    /// AirPlay / Sidecar display (not controllable with CGSConfigureDisplayEnabled).
    func isAirPlay(_ id: CGDirectDisplayID) -> Bool
    func isBuiltin(_ id: CGDirectDisplayID) -> Bool
    func name(of id: CGDirectDisplayID) -> String?
    func uuid(of id: CGDirectDisplayID) -> String?
    func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) throws
    func detectDisplays()
}

/// Everything DisplayManager needs from SidecarCore.
public protocol SidecarControlling: AnyObject {
    func devices() -> [SidecarDeviceInfo]
    func connect(_ id: String, completion: @escaping (Error?) -> Void)
    func disconnect(_ id: String, completion: @escaping (Error?) -> Void)
}

extension SidecarManager: SidecarControlling {}

/// The real implementation: public CoreGraphics + private CGS/SLS calls.
public struct SystemDisplays: DisplaySystem {
    public init() {}

    public func activeDisplayIDs() -> [CGDirectDisplayID] {
        Self.list { CGGetActiveDisplayList($0, $1, $2) }
    }

    public func onlineDisplayIDs() -> [CGDirectDisplayID] {
        Self.list { CGGetOnlineDisplayList($0, $1, $2) }
    }

    /// Private list. Contains stale "ghost" IDs: debugging only, never used for state.
    public func privateDisplayIDs() -> [CGDirectDisplayID]? {
        guard let fn = PrivateAPI.getDisplayList else { return nil }
        return Self.list { fn($0, $1, $2) }
    }

    private static func list(_ fetch: (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError) -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard fetch(UInt32(ids.count), &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    public func mainDisplayID() -> CGDirectDisplayID { CGMainDisplayID() }

    /// AirPlay / Sidecar displays report vendor 'aapl' (0x6161706c); Sidecar model is 'iPad'.
    public func isAirPlay(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayVendorNumber(id) == 0x6161_706C
    }

    public func isBuiltin(_ id: CGDirectDisplayID) -> Bool { CGDisplayIsBuiltin(id) != 0 }

    public func name(of id: CGDirectDisplayID) -> String? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
        }?.localizedName
    }

    public func uuid(of id: CGDirectDisplayID) -> String? {
        guard let ref = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, ref) as String?
    }

    /// Raw enable/disable, no safety checks.
    public func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) throws {
        guard let configure = PrivateAPI.configureDisplayEnabled else {
            throw DisplayError.apiUnavailable("CGSConfigureDisplayEnabled")
        }
        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success, let config else { throw DisplayError.cgError(begin) }
        let result = configure(config, id, enabled)
        guard result == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.cgError(result)
        }
        let complete = CGCompleteDisplayConfiguration(config, .permanently)
        guard complete == .success else { throw DisplayError.cgError(complete) }
    }

    public func detectDisplays() {
        _ = PrivateAPI.detectDisplays?()
    }
}
