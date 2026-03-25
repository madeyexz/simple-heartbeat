import SwiftUI
import HeartbeatCore

struct ContentView: View {
    @EnvironmentObject var store: JobStore
    @EnvironmentObject var scheduler: JobScheduler
    @State private var showingNewJob = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.jobs.isEmpty {
                emptyState
            } else {
                jobList
            }

            Divider()
            footer
        }
        .frame(width: 420, height: 480)
        .sheet(isPresented: $showingNewJob) {
            NewJobView()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
                .font(.title3)
            Text("Simple Heartbeat")
                .font(.headline)
            Spacer()
            Button(action: { showingNewJob = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No heartbeats yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Create a scheduled job powered by Claude Code or Codex")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("New Heartbeat") {
                showingNewJob = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var jobList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(store.jobs) { job in
                    JobRowView(
                        job: job,
                        isRunning: scheduler.runningJobs.contains(job.id)
                    )
                }
            }
            .padding()
        }
    }

    private var footer: some View {
        HStack {
            Text("\(store.jobs.count) heartbeat\(store.jobs.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
