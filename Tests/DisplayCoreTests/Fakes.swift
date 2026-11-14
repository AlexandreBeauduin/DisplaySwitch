import CoreGraphics
import Foundation
@testable import DisplayCore

/// In-memory stand-in for macOS: no real display is ever touched.
final class FakeDisplays: DisplaySystem {
    struct Display {
        var name: String
        var builtin = false
        var airPlay = false
        var active = true
        var online = true
    }

    var displays: [CGDirectDisplayID: Display]
    var main: CGDirectDisplayID
    var setEnabledCalls: [(CGDirectDisplayID, Bool)] = []
    var detectCount = 0
    var failOn: Set<CGDirectDisplayID> = []

    init(_ displays: [CGDirectDisplayID: Display], main: CGDirectDisplayID) {
        self.displays = displays
        self.main = main
    }

    func activeDisplayIDs() -> [CGDirectDisplayID] { displays.filter { $0.value.active }.keys.sorted() }
    func onlineDisplayIDs() -> [CGDirectDisplayID] { displays.filter { $0.value.online }.keys.sorted() }
    func mainDisplayID() -> CGDirectDisplayID { main }
    func isAirPlay(_ id: CGDirectDisplayID) -> Bool { displays[id]?.airPlay ?? false }
    func isBuiltin(_ id: CGDirectDisplayID) -> Bool { displays[id]?.builtin ?? false }
    func name(of id: CGDirectDisplayID) -> String? { displays[id]?.active == true ? displays[id]?.name : nil }
    func uuid(of id: CGDirectDisplayID) -> String? { "UUID-\(id)" }
    func detectDisplays() { detectCount += 1 }

    func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) throws {
        setEnabledCalls.append((id, enabled))
        if failOn.contains(id) { throw DisplayError.cgError(.failure) }
        // Like macOS: a disabled display leaves both the active and the online lists.
        displays[id]?.active = enabled
        displays[id]?.online = enabled
    }
}

final class FakeSidecar: SidecarControlling {
    var available: [SidecarDeviceInfo]
    var failOn: Set<String> = []
    private(set) var calls: [String] = []

    init(_ available: [SidecarDeviceInfo] = []) { self.available = available }

    func devices() -> [SidecarDeviceInfo] { available }

    func connect(_ id: String, completion: @escaping (Error?) -> Void) { act(id, true, completion) }
    func disconnect(_ id: String, completion: @escaping (Error?) -> Void) { act(id, false, completion) }

    private func act(_ id: String, _ connect: Bool, _ completion: @escaping (Error?) -> Void) {
        calls.append("\(connect ? "on" : "off") \(id)")
        if failOn.contains(id) { return completion(SidecarError.failed("boom")) }
        if let i = available.firstIndex(where: { $0.id == id }) { available[i].isConnected = connect }
        completion(nil)
    }
}

func tempStore() -> DisplayStore {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("DisplaySwitchTests-\(UUID().uuidString)")
        .appendingPathComponent("displays.json")
    return DisplayStore(url: url)
}

let iPad = SidecarDeviceInfo(id: "IPAD-1", name: "iPad", model: "iPad13,10", isConnected: true)

/// Bridges the completion-based bulk actions (completion on the main queue) to async tests.
@MainActor
func completion(_ start: (@escaping ([String: Error]) -> Void) -> Void) async -> [String: Error] {
    await withCheckedContinuation { continuation in
        start { continuation.resume(returning: $0) }
    }
}
