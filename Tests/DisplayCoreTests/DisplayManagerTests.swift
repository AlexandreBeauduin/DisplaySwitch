import CoreGraphics
import Testing
@testable import DisplayCore

/// Typical desk: main external (1), second external (2), built-in (3), Sidecar iPad (10).
private func desk() -> (DisplayManager, FakeDisplays, FakeSidecar) {
    let system = FakeDisplays([
        1: .init(name: "Main"),
        2: .init(name: "Second"),
        3: .init(name: "Built-in", builtin: true),
        10: .init(name: "iPad", airPlay: true),
    ], main: 1)
    let sidecar = FakeSidecar([iPad])
    return (DisplayManager(store: tempStore(), system: system, sidecar: sidecar), system, sidecar)
}

@Suite("Safety rules")
struct SafetyTests {
    @Test func refusesToDisconnectTheLastPhysicalDisplayEvenWithAnIPad() {
        let system = FakeDisplays([1: .init(name: "Only"), 10: .init(name: "iPad", airPlay: true)], main: 1)
        let manager = DisplayManager(store: tempStore(), system: system, sidecar: FakeSidecar([iPad]))
        #expect {
            try manager.disconnect(1)
        } throws: { error in
            if case DisplayError.lastActiveDisplay = error { return true } else { return false }
        }
        #expect(system.setEnabledCalls.isEmpty)
    }

    @Test func protectsTheBuiltInDisplayUnlessForced() throws {
        let (manager, system, _) = desk()
        #expect {
            try manager.disconnect(3)
        } throws: { error in
            if case DisplayError.builtinProtected = error { return true } else { return false }
        }
        try manager.disconnect(3, allowBuiltin: true)
        #expect(system.displays[3]?.active == false)
    }

    @Test func refusesAirPlayDisplays() {
        let (manager, system, _) = desk()
        #expect {
            try manager.disconnect(10)
        } throws: { error in
            if case DisplayError.airPlayDisplay = error { return true } else { return false }
        }
        #expect(system.setEnabledCalls.isEmpty)
    }

    @Test func unknownDisplayIsAnError() {
        let (manager, _, _) = desk()
        #expect {
            try manager.disconnect(42)
        } throws: { error in
            if case DisplayError.unknownDisplay(42) = error { return true } else { return false }
        }
    }
}

@Suite("State")
struct StateTests {
    @Test func disconnectedDisplayStaysListedAndCanBeReconnected() throws {
        let (manager, system, _) = desk()
        try manager.disconnect(2)

        let second = try #require(manager.refresh().first { $0.id == 2 })
        #expect(!second.isActive)
        #expect(second.disconnectedByUs)
        #expect(second.name == "Second") // remembered name, macOS no longer knows it

        try manager.connect(2)
        #expect(system.displays[2]?.active == true)
        #expect(manager.store.displays[2]?.disconnectedByUs == false)
    }

    @Test func listsPhysicalDisplaysMainFirstWithoutAirPlay() {
        let (manager, _, _) = desk()
        let list = manager.refresh()
        #expect(list.map(\.id) == [1, 3, 2]) // main, then by name
        #expect(list.first?.isMain == true)
        #expect(!list.contains { $0.id == 10 })
    }

    @Test func reconnectedElsewhereClearsOurFlag() throws {
        let (manager, system, _) = desk()
        try manager.disconnect(2)
        system.displays[2]?.active = true // e.g. replugged, or another tool
        manager.refresh()
        #expect(manager.store.displays[2]?.disconnectedByUs == false)
    }

    @Test func prunesDisplaysThatAreGoneAndNotOurs() {
        let (manager, system, _) = desk()
        manager.refresh()
        system.displays[2] = nil // unplugged
        let list = manager.refresh()
        #expect(!list.contains { $0.id == 2 })
    }

    @Test func outOfRangeIPadWeDisconnectedIsStillListed() async {
        let (manager, _, sidecar) = desk()
        manager.refresh()
        _ = await completion { done in manager.disconnectSidecar(iPad.id) { _ in done([:]) } }
        sidecar.available = [] // iPad left

        let statuses = manager.sidecarStatuses()
        #expect(statuses.count == 1)
        #expect(statuses.first?.isAvailable == false)
        #expect(statuses.first?.disconnectedByUs == true)
    }
}

@Suite("Bulk actions")
struct BulkTests {
    @Test func allButMainKeepsMainSkipsBuiltInAndDisconnectsIPads() async {
        let (manager, system, sidecar) = desk()
        let failures = await completion { manager.disconnectAllButMain(completion: $0) }

        #expect(failures.isEmpty)
        #expect(system.displays[1]?.active == true)
        #expect(system.displays[2]?.active == false)
        #expect(system.displays[3]?.active == true)
        #expect(sidecar.calls == ["off IPAD-1"])
    }

    @Test func reconnectAllRestoresOnlyWhatWeDisconnected() async {
        let (manager, system, sidecar) = desk()
        _ = await completion { manager.disconnectAllButMain(completion: $0) }
        system.displays[3]?.active = false // turned off by something else: not ours
        system.displays[3]?.online = true

        let failures = await completion { manager.reconnectAll(completion: $0) }

        #expect(failures.isEmpty)
        #expect(system.displays[2]?.active == true)
        #expect(system.displays[3]?.active == false)
        #expect(sidecar.available.first?.isConnected == true)
        #expect(system.detectCount == 1)
    }

    @Test func failuresAreReportedByName() async {
        let (manager, system, sidecar) = desk()
        system.failOn = [2]
        sidecar.failOn = [iPad.id]
        let failures = await completion { manager.disconnectAllButMain(completion: $0) }
        #expect(Set(failures.keys) == ["Second", "iPad"])
    }
}
