import SwiftUI
import HeartbeatCore

struct ImportView: View {
    @EnvironmentObject var store: JobStore
    @Environment(\.dismiss) var dismiss

    @State private var codexJobs: [SelectableJob] = []
    @State private var claudeJobs: [SelectableJob] = []
    @State private var isScanning = true

    struct SelectableJob: Identifiable {
        let id = UUID()
        var job: HeartbeatJob
        var isSelected: Bool = true
        let source: String
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if isScanning {
                scanningState
            } else if allJobs.isEmpty {
                emptyState
            } else {
                jobList
            }

            Divider()
            footer
        }
        .frame(width: 480, height: 440)
        .task { await scan() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "square.and.arrow.down")
                .foregroundStyle(.blue)
            Text("Import Automations")
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - States

    private var scanningState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Scanning for automations...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No automations found")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Checked:")
                    .font(.caption.weight(.medium))
                Text("~/.codex/automations/")
                    .font(.caption.monospaced())
                Text("~/.claude/scheduled_tasks.json")
                    .font(.caption.monospaced())
            }
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Job list

    private var jobList: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !codexJobs.isEmpty {
                    sourceSection(
                        title: "Codex Automations",
                        icon: "chevron.left.forwardslash.chevron.right",
                        path: "~/.codex/automations/",
                        jobs: $codexJobs
                    )
                }
                if !claudeJobs.isEmpty {
                    sourceSection(
                        title: "Claude Code Tasks",
                        icon: "brain.head.profile",
                        path: "~/.claude/scheduled_tasks.json",
                        jobs: $claudeJobs
                    )
                }
            }
            .padding()
        }
    }

    private func sourceSection(
        title: String, icon: String, path: String,
        jobs: Binding<[SelectableJob]>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)

            ForEach(jobs) { $selJob in
                importRow(selJob: $selJob)
            }
        }
    }

    private func importRow(selJob: Binding<SelectableJob>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: selJob.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(selJob.wrappedValue.job.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let cron = CronExpression(from: selJob.wrappedValue.job.schedule) {
                        Label(cron.humanReadable, systemImage: "clock")
                    }
                    if let model = selJob.wrappedValue.job.options["model"] {
                        Label(model, systemImage: "cpu")
                    }
                    Label(selJob.wrappedValue.job.isEnabled ? "Active" : "Paused",
                          systemImage: selJob.wrappedValue.job.isEnabled ? "checkmark.circle" : "pause.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(selJob.wrappedValue.job.prompt.prefix(80) + (selJob.wrappedValue.job.prompt.count > 80 ? "..." : ""))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        .opacity(selJob.wrappedValue.isSelected ? 1 : 0.5)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(selectedCount) of \(allJobs.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { dismiss() }
            Button("Import \(selectedCount)") {
                importSelected()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(selectedCount == 0)
        }
        .padding()
    }

    // MARK: - Logic

    private var allJobs: [SelectableJob] { codexJobs + claudeJobs }
    private var selectedCount: Int { allJobs.filter(\.isSelected).count }

    private func scan() async {
        // Run discovery on background thread
        let (codex, claude) = await Task.detached {
            (CodexImporter.discover(), ClaudeImporter.discover())
        }.value

        codexJobs = codex.map { SelectableJob(job: $0, source: "codex") }
        claudeJobs = claude.map { SelectableJob(job: $0, source: "claude") }
        isScanning = false
    }

    private func importSelected() {
        let selected = allJobs.filter(\.isSelected).map(\.job)
        for job in selected {
            // Avoid duplicates by checking name + agentId
            if !store.jobs.contains(where: { $0.name == job.name && $0.agentId == job.agentId }) {
                store.add(job)
            }
        }
    }
}
