import SwiftUI
import HeartbeatCore

@main
struct SimpleHeartbeatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(delegate.store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var globalMonitor: Any?
    private var localMonitor: Any?
    let store = JobStore()
    private let scheduler = JobScheduler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        scheduler.start(store: store)

        // Status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "heart.fill",
                accessibilityDescription: "Simple Heartbeat"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Popover — use applicationDefined so WE control all closing
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 480)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self

        let contentView = ContentView()
            .environmentObject(store)
            .environmentObject(scheduler)
            .environment(\.closePopover, { [weak self] in self?.closePopover() })

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    // MARK: - App lifecycle

    /// Close popover whenever the entire app loses focus (user clicked another app)
    func applicationDidResignActive(_ notification: Notification) {
        closePopover()
    }

    // MARK: - Popover management

    func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
        removeMonitors()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            installMonitors()
        }
    }

    // MARK: - Click-outside monitors

    private func installMonitors() {
        // Global: clicks on other apps
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
        // Local: clicks within our app but outside the popover (e.g. clicking the menu bar item again)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // If the click is on the status bar button, let togglePopover handle it
            if let button = self?.statusItem.button, event.window == button.window {
                return event
            }
            // If the click is inside the popover or its sheets, let it through
            if let popoverWindow = self?.popover.contentViewController?.view.window,
               event.window == popoverWindow {
                return event
            }
            // Any attached sheet windows should also pass through
            if let popoverWindow = self?.popover.contentViewController?.view.window,
               popoverWindow.sheets.contains(where: { $0 == event.window }) {
                return event
            }
            // Click was somewhere else in our app — close the popover
            Task { @MainActor in self?.closePopover() }
            return event
        }
    }

    private func removeMonitors() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    // MARK: - NSPopoverDelegate

    func popoverShouldClose(_ popover: NSPopover) -> Bool { true }

    func popoverDidClose(_ notification: Notification) {
        removeMonitors()
    }
}

// MARK: - Environment key for closing the popover from any view

private struct ClosePopoverKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var closePopover: () -> Void {
        get { self[ClosePopoverKey.self] }
        set { self[ClosePopoverKey.self] = newValue }
    }
}
