import CoreGraphics
import Foundation

/// What we remember about a display, so it can still be listed (and
/// reconnected) once it has disappeared from the system display lists.
public struct KnownDisplay: Codable, Equatable, Sendable {
    public var id: CGDirectDisplayID
    public var name: String
    public var uuid: String?
    public var isBuiltin: Bool
    /// True when DisplaySwitch disconnected it and has not reconnected it yet.
    public var disconnectedByUs: Bool
}

/// A Sidecar device (iPad) we have seen, keyed by its SidecarDevice identifier.
public struct KnownSidecar: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var model: String
    public var disconnectedByUs: Bool
}

/// JSON persistence in ~/Library/Application Support/DisplaySwitch/displays.json.
/// Shared by the CLI and the menu bar app.
public final class DisplayStore {
    public private(set) var displays: [CGDirectDisplayID: KnownDisplay] = [:]
    public private(set) var sidecars: [String: KnownSidecar] = [:]
    private let url: URL

    private struct FileFormat: Codable {
        var displays: [KnownDisplay]
        var sidecars: [KnownSidecar]
    }

    public init(url: URL? = nil) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DisplaySwitch", isDirectory: true)
        self.url = url ?? dir.appendingPathComponent("displays.json")
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        if let file = try? decoder.decode(FileFormat.self, from: data) {
            displays = Dictionary(file.displays.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
            sidecars = Dictionary(file.sidecars.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        } else if let legacy = try? decoder.decode([KnownDisplay].self, from: data) {
            // v1 format: a bare array of displays.
            displays = Dictionary(legacy.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        }
    }

    public func save() {
        let file = FileFormat(
            displays: displays.values.sorted { $0.id < $1.id },
            sidecars: sidecars.values.sorted { $0.id < $1.id }
        )
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(file).write(to: url, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("DisplaySwitch: cannot save \(url.path): \(error)\n".utf8))
        }
    }

    // MARK: Displays

    /// Insert or refresh a display seen live, keeping its disconnectedByUs flag.
    public func remember(id: CGDirectDisplayID, name: String, uuid: String?, isBuiltin: Bool) {
        var entry = displays[id] ?? KnownDisplay(id: id, name: name, uuid: uuid, isBuiltin: isBuiltin, disconnectedByUs: false)
        entry.name = name
        if let uuid { entry.uuid = uuid }
        entry.isBuiltin = isBuiltin
        displays[id] = entry
    }

    public func setDisconnectedByUs(_ id: CGDirectDisplayID, _ value: Bool) {
        displays[id]?.disconnectedByUs = value
    }

    public func forget(_ id: CGDirectDisplayID) {
        displays[id] = nil
    }

    // MARK: Sidecar

    public func rememberSidecar(_ device: SidecarDeviceInfo) {
        var entry = sidecars[device.id] ?? KnownSidecar(id: device.id, name: device.name, model: device.model, disconnectedByUs: false)
        entry.name = device.name
        entry.model = device.model
        sidecars[device.id] = entry
    }

    public func setSidecarDisconnectedByUs(_ id: String, _ value: Bool) {
        sidecars[id]?.disconnectedByUs = value
    }
}
