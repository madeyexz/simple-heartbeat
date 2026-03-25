import SwiftUI
import HeartbeatCore

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @EnvironmentObject var store: JobStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Form {
                Section("Appearance") {
                    Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                    Toggle("Auto-dismiss popover on outside click", isOn: $settings.closePopoverOnOutsideClick)
                }

                Section("Startup") {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                }

                Section("Data") {
                    HStack {
                        Text("Storage")
                        Spacer()
                        Text(settings.dataDirectory.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Reveal") {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.dataDirectory.path)
                        }
                        .controlSize(.small)
                    }

                    HStack {
                        Text("Jobs")
                        Spacer()
                        Text("\(store.jobs.count) heartbeats, \(store.runs.count) runs")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Simple Heartbeat")
                        Spacer()
                        Text("v0.1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Agents")
                        Spacer()
                        Text(AgentRegistry.shared.allAgents.map(\.name).joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

        }
        .frame(width: 440, height: 420)
    }

    private var header: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.headline)
            Spacer()
        }
        .padding()
    }
}
