import SwiftUI

struct RunLogView: View {
    let jobId: UUID
    @EnvironmentObject var store: JobStore

    private var runs: [JobRun] {
        store.runsForJob(jobId)
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
            Text(run.startedAt, style: .relative)
            if let code = run.exitCode {
                Text("exit \(code)")
                    .foregroundStyle(.secondary)
            }
            if run.status == .running {
                ProgressView()
                    .controlSize(.mini)
            }
        }
    }

    @ViewBuilder
    private func runDetail(_ run: JobRun) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !run.output.isEmpty {
                ScrollView {
                    Text(run.output.suffix(2000)) // Show last 2k chars
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
