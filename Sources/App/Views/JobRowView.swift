import SwiftUI
import HeartbeatCore

struct JobRowView: View {
    let job: HeartbeatJob
    let isRunning: Bool

    @EnvironmentObject var store: JobStore
    @EnvironmentObject var scheduler: JobScheduler
    @State private var showingRuns = false
    @State private var showingEdit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusIndicator
                jobInfo
                Spacer()
                actionButtons
            }

            if showingRuns {
                RunLogView(jobId: job.id)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.2), value: showingRuns)
        .sheet(isPresented: $showingEdit) {
            NewJobView(editing: job)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if isRunning {
            ProgressView()
                .controlSize(.small)
                .frame(width: 14, height: 14)
        } else {
            Circle()
                .fill(job.isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
    }

    private var jobInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(job.name)
                .font(.system(.body, weight: .medium))
                .lineLimit(1)
            HStack(spacing: 8) {
                Label(agentName, systemImage: agentIcon)
                Label(scheduleText, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation { showingRuns.toggle() }
            }) {
                Image(systemName: "list.bullet")
            }
            .help("View run history")

            Button(action: { scheduler.runJob(job) }) {
                Image(systemName: "play.fill")
            }
            .disabled(isRunning)
            .help("Run now")

            Button(action: { store.toggleEnabled(job) }) {
                Image(systemName: job.isEnabled ? "pause.fill" : "play.circle")
            }
            .help(job.isEnabled ? "Disable schedule" : "Enable schedule")

            Button(action: { showingEdit = true }) {
                Image(systemName: "pencil")
            }
            .help("Edit")

            Button(action: { store.delete(job) }) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .help("Delete")
        }
        .buttonStyle(.plain)
        .font(.caption)
    }

    private var agentName: String {
        AgentRegistry.shared.agent(for: job.agentId)?.name ?? job.agentId
    }

    private var agentIcon: String {
        AgentRegistry.shared.agent(for: job.agentId)?.iconName ?? "questionmark"
    }

    private var scheduleText: String {
        CronExpression(from: job.schedule)?.humanReadable ?? job.schedule
    }
}
