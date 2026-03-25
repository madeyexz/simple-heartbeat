import SwiftUI
import HeartbeatCore

struct RunLogView: View {
    let job: HeartbeatJob
    @EnvironmentObject var store: JobStore

    private var runs: [JobRun] {
        store.runsForJob(job.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if runs.isEmpty {
                Text("No runs yet — hit play to run this heartbeat")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(runs.prefix(5)) { run in
                    DisclosureGroup {
                        runDetail(run)
                    } label: {
                        runLabel(run)
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func runLabel(_ run: JobRun) -> some View {
        HStack(spacing: 6) {
            statusIcon(run.status)

            if run.status == .running {
                // Only running jobs get a live counter
                Text(run.startedAt, style: .relative)
                ProgressView()
                    .controlSize(.mini)
            } else {
                // Completed: static timestamp, no live counting
                Text(formatTimestamp(run.startedAt))
                    .foregroundStyle(.secondary)
                if let code = run.exitCode, code != 0 {
                    Text("exit \(code)")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short // "10:30 AM"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a" // "Mar 25, 10:30 AM"
        return f
    }()

    private func formatTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        } else {
            return Self.dateTimeFormatter.string(from: date)
        }
    }

    @ViewBuilder
    private func runDetail(_ run: JobRun) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Session attach button — only on actively running sessions
            if run.status == .running, run.output.contains("session:") {
                HStack(spacing: 6) {
                    Text(run.output)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button(action: { attachToSession() }) {
                        Label("Open", systemImage: "terminal")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.blue)
                }
            } else if !run.output.isEmpty {
                ScrollView {
                    Text(run.output.suffix(2000))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }

            if !run.error.isEmpty {
                Text(run.error.suffix(1000))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
            if run.output.isEmpty && run.error.isEmpty && run.status != .running {
                Text("(no output)")
                    .foregroundStyle(.tertiary)
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attachToSession() {
        let terminal = AppSettings.shared.preferredTerminal
        Task {
            try? await TerminalLauncher.attachToSession(job: job, openIn: terminal)
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: JobRun.Status) -> some View {
        switch status {
        case .running:
            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                .foregroundStyle(.blue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
