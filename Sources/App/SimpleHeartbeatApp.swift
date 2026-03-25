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

/// NSStatusItem + NSPopover for proper menu bar app behavior:
/// - Popover stays open when interacting inside (buttons, sheets, etc.)
/// - Popover dismisses when clicking outside
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
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

        // Popover
        let contentView = ContentView()
            .environmentObject(store)
            .environmentObject(scheduler)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
