import SwiftUI
import HeartbeatCore

@main
struct SimpleHeartbeatApp: App {
    @StateObject private var store = JobStore()
    @StateObject private var scheduler = JobScheduler()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
                .environmentObject(scheduler)
                .onAppear {
                    NSApp.setActivationPolicy(.accessory) // Hide from dock
                    scheduler.start(store: store)
                }
        } label: {
            Image(systemName: "heart.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
