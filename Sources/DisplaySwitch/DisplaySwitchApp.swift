import AppKit
import CoreGraphics
import DisplayCore
import ServiceManagement
import SwiftUI

@main
struct DisplaySwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var model = DisplayModel.shared

    var body: some Scene {
        MenuBarExtra("DisplaySwitch", systemImage: "display.2") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DisplayModel.shared.start()
    }

    /// Reconnecting Sidecar is asynchronous (~5 s): delay termination until it is done.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard DisplayModel.shared.reconnectOnQuit else { return .terminateNow }
        var replied = false
        let reply = {
            guard !replied else { return }
            replied = true
            sender.reply(toApplicationShouldTerminate: true)
        }
        DisplayModel.shared.manager.reconnectAll { _ in reply() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: reply) // never hang on quit
        return .terminateLater
    }
}

// MARK: - Model

final class DisplayModel: ObservableObject {
    static let shared = DisplayModel()

    let manager = DisplayManager()
    @Published private(set) var displays: [DisplayStatus] = []
    @Published private(set) var sidecars: [SidecarStatus] = []
    /// Sidecar devices with a connect/disconnect in flight.
    @Published private(set) var pendingSidecars: Set<String> = []
    @Published private(set) var busy = false
    @Published var lastError: String?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    @Published var reconnectOnQuit: Bool = UserDefaults.standard.object(forKey: "reconnectOnQuit") as? Bool ?? true {
        didSet { UserDefaults.standard.set(reconnectOnQuit, forKey: "reconnectOnQuit") }
    }

    /// "" = follow the system, otherwise a Language raw value.
    @Published var languageChoice: String = UserDefaults.standard.string(forKey: "language") ?? "" {
        didSet {
            UserDefaults.standard.set(languageChoice, forKey: "language")
            Self.applyLanguage(languageChoice)
            refresh() // display names stored with a localized fallback
        }
    }

    static func applyLanguage(_ choice: String) {
        L10n.language = Language(rawValue: choice) ?? Language.preferred(from: Locale.preferredLanguages)
    }

    private var pendingRefresh: DispatchWorkItem?
    private var pollTimer: Timer?

    func start() {
        Self.applyLanguage(languageChoice)
        refresh()
        // Notified by macOS on every display change (cable, sleep/wake, Sidecar, our own toggles).
        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            guard !flags.contains(.beginConfigurationFlag) else { return }
            DispatchQueue.main.async { DisplayModel.shared.scheduleRefresh() }
        }, nil)
        // SidecarCore has no public change notification: poll iPad availability (cheap, in-memory).
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            DisplayModel.shared.refreshSidecarsIfChanged()
        }
    }

    /// Display changes arrive in bursts; coalesce them.
    func scheduleRefresh() {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func refresh() {
        displays = manager.refresh()
        sidecars = manager.sidecarStatuses()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func refreshSidecarsIfChanged() {
        let current = manager.sidecarStatuses()
        if current != sidecars { refresh() }
    }

    // MARK: Actions

    func toggle(_ display: DisplayStatus) {
        do {
            if display.isActive {
                try manager.disconnect(display.id)
            } else {
                try manager.connect(display.id)
            }
            lastError = nil
        } catch {
            lastError = "\(display.name) : \(error)"
        }
        refresh()
    }

    func toggle(_ device: SidecarStatus) {
        guard !pendingSidecars.contains(device.id) else { return }
        pendingSidecars.insert(device.id)
        let done: (Error?) -> Void = { [weak self] error in
            guard let self else { return }
            self.pendingSidecars.remove(device.id)
            self.lastError = error.map { "\(device.name) : \($0)" }
            self.refresh()
        }
        if device.isConnected {
            manager.disconnectSidecar(device.id, completion: done)
        } else {
            manager.connectSidecar(device.id, completion: done)
        }
    }

    func disconnectAllButMain() {
        busy = true
        manager.disconnectAllButMain { [weak self] in self?.finishBulk($0) }
    }

    func reconnectAll() {
        busy = true
        manager.reconnectAll { [weak self] in self?.finishBulk($0) }
    }

    private func finishBulk(_ failures: [String: Error]) {
        busy = false
        lastError = failures.isEmpty ? nil : failures.map { "\($0.key) : \($0.value)" }.sorted().joined(separator: "\n")
        refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            lastError = nil
        } catch {
            lastError = L10n.launchAtLoginError(error.localizedDescription)
        }
        refresh()
    }
}

// MARK: - Menu

struct MenuContent: View {
    @ObservedObject var model: DisplayModel

    var body: some View {
        Section(L10n.displays) {
            ForEach(model.displays) { display in
                Toggle(isOn: Binding(get: { display.isActive }, set: { _ in model.toggle(display) })) {
                    Text(label(for: display))
                }
                .disabled(display.isBuiltin && display.isActive)
            }
        }

        if !model.sidecars.isEmpty {
            Section("Sidecar") {
                ForEach(model.sidecars) { device in
                    Toggle(isOn: Binding(get: { device.isConnected }, set: { _ in model.toggle(device) })) {
                        Text(label(for: device))
                    }
                    .disabled(!device.isAvailable || model.pendingSidecars.contains(device.id))
                }
            }
        }

        Divider()

        Button(L10n.allButMain) { model.disconnectAllButMain() }
            .disabled(model.busy || (model.displays.allSatisfy { !$0.isActive || $0.isMain }
                                     && model.sidecars.allSatisfy { !$0.isConnected }))
        Button(model.busy ? L10n.working : L10n.reconnectAll) { model.reconnectAll() }
            .keyboardShortcut("r")
            .disabled(model.busy)

        if let error = model.lastError {
            Divider()
            Text("⚠︎ \(error)")
        }

        Divider()

        Toggle(L10n.launchAtLogin, isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
        Toggle(L10n.reconnectOnQuit, isOn: $model.reconnectOnQuit)

        Picker(L10n.languageMenu, selection: $model.languageChoice) {
            Text(L10n.systemLanguage).tag("")
            ForEach(Language.allCases, id: \.rawValue) { Text($0.nativeName).tag($0.rawValue) }
        }

        Divider()

        Button(L10n.quit) { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func label(for display: DisplayStatus) -> String {
        var tags: [String] = []
        if display.isMain { tags.append(L10n.main) }
        if display.isBuiltin { tags.append(L10n.builtinProtectedTag) }
        return tags.isEmpty ? display.name : "\(display.name) — \(tags.joined(separator: ", "))"
    }

    private func label(for device: SidecarStatus) -> String {
        if model.pendingSidecars.contains(device.id) { return "\(device.name) — \(L10n.inProgress)" }
        if !device.isAvailable { return "\(device.name) — \(L10n.outOfRange)" }
        return device.name
    }
}
