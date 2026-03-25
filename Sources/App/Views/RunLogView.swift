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
                // Running: show live elapsed time
                Text(run.startedAt, style: .relative)
                ProgressView()
                    .controlSize(.mini)
            } else if let finished = run.finishedAt {
                // Completed: show static duration
                Text(formatDuration(from: run.startedAt, to: finished))
                Text("ago")
                    .foregroundStyle(.tertiary)
                Text(finished, style: .relative)
                    .foregroundStyle(.tertiary)
            } else {
                // No finish time: show when it started
                Text(run.startedAt, style: .relative)
            }

            if let code = run.exitCode, code != 0 {
                Text("exit \(code)")
                    .foregroundStyle(.red)
            }
        }
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let seconds = Int(end.timeIntervalSince(start))
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        } else {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
    }

    @ViewBuilder
    private func runDetail(_ run: JobRun) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Session attach button — shown when output mentions a session
            if run.output.contains("session:") || run.status == .running {
                HStack(spacing: 6) {
                    if !run.output.isEmpty {
                        Text(run.output)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
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
