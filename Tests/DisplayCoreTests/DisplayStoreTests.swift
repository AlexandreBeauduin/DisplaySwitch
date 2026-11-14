import Foundation
import Testing
@testable import DisplayCore

@Suite("DisplayStore")
struct DisplayStoreTests {
    @Test func savesAndReloadsDisplaysAndSidecars() {
        let store = tempStore()
        store.remember(id: 9, name: "Monitor", uuid: "U9", isBuiltin: false)
        store.setDisconnectedByUs(9, true)
        store.rememberSidecar(iPad)
        store.setSidecarDisconnectedByUs(iPad.id, true)
        store.save()

        let reloaded = DisplayStore(url: store.url)
        #expect(reloaded.displays[9]?.name == "Monitor")
        #expect(reloaded.displays[9]?.disconnectedByUs == true)
        #expect(reloaded.sidecars[iPad.id]?.disconnectedByUs == true)
    }

    @Test func readsLegacyBareArrayFormat() throws {
        let store = tempStore()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacy = #"[{"id":5,"name":"Old","isBuiltin":false,"disconnectedByUs":true}]"#
        try Data(legacy.utf8).write(to: store.url)

        store.load()
        #expect(store.displays[5]?.name == "Old")
        #expect(store.displays[5]?.disconnectedByUs == true)
        #expect(store.sidecars.isEmpty)
    }

    @Test func rememberKeepsTheDisconnectedFlag() {
        let store = tempStore()
        store.remember(id: 9, name: "A", uuid: nil, isBuiltin: false)
        store.setDisconnectedByUs(9, true)
        store.remember(id: 9, name: "B", uuid: "U", isBuiltin: false)
        #expect(store.displays[9]?.name == "B")
        #expect(store.displays[9]?.disconnectedByUs == true)
    }

    @Test func missingFileMeansEmptyStore() {
        let store = tempStore()
        #expect(store.displays.isEmpty)
        #expect(store.sidecars.isEmpty)
    }
}
