import SwiftUI
import HeartbeatCore

@main
struct SimpleHeartbeatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // Menu bar apps need at least one scene, but we manage the window ourselves
        Settings { EmptyView() }
    }
}

/// Uses NSStatusItem + NSWindow instead of MenuBarExtra to avoid the
/// popover-dismisses-on-click bug that plagues MenuBarExtra(.window).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private let store = JobStore()
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
            button.action = #selector(toggleWindow)
            button.target = self
        }

        // Floating window (created once, toggled on click)
        let contentView = ContentView()
            .environmentObject(store)
            .environmentObject(scheduler)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.animationBehavior = .utilityWindow
    }

    @objc private func toggleWindow() {
        if window.isVisible {
            window.close()
        } else {
            positionNearStatusItem()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func positionNearStatusItem() {
        guard let buttonFrame = statusItem.button?.window?.frame else { return }
        let x = buttonFrame.midX - window.frame.width / 2
        let y = buttonFrame.minY - window.frame.height
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
