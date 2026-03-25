import SwiftUI
import HeartbeatCore

struct NewJobView: View {
    @EnvironmentObject var store: JobStore
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var schedule: String
    @State private var agentId: String
    @State private var prompt: String
    @State private var workingDirectory: String
    @State private var options: [String: String]
    @State private var isEnabled: Bool
    @FocusState private var focusedField: Field?

    private let editing: HeartbeatJob?

    private enum Field: Hashable {
        case name, prompt, schedule
    }

    init(editing: HeartbeatJob? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _schedule = State(initialValue: editing?.schedule ?? "*/30 * * * *")
        _agentId = State(initialValue: editing?.agentId ?? AgentRegistry.shared.agentIds.first ?? "claude")
        _prompt = State(initialValue: editing?.prompt ?? "")
        _workingDirectory = State(initialValue: editing?.workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path)
        _options = State(initialValue: editing?.options ?? [:])
        _isEnabled = State(initialValue: editing?.isEnabled ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    instructionsCard
                    nameAndAgentSection
                    promptSection
                    scheduleSection
                    directorySection
                    agentOptionsSection
                }
                .padding()
            }
            Divider()
            footer
        }
        .frame(width: 480, height: 620)
        .onAppear { focusedField = .name }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
            Text(editing != nil ? "Edit Heartbeat" : "New Heartbeat")
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

    // MARK: - Instructions

    private var instructionsCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("A heartbeat runs an AI agent on a schedule.")
                    .font(.callout.weight(.medium))
                Text("Write a prompt, pick an agent (Claude Code or Codex), choose how often it runs, and point it at a directory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Name & Agent

    private var nameAndAgentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Name & Agent")
            TextField("Name", text: $name, prompt: Text("e.g. Daily code review"))
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)

            Picker("Agent", selection: $agentId) {
                ForEach(AgentRegistry.shared.allAgents, id: \.id) { agent in
                    Label(agent.name, systemImage: agent.iconName).tag(agent.id)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: agentId) { _, _ in options = [:] }
        }
    }

    // MARK: - Prompt (moved up — it's the core of a heartbeat)

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Instructions")
            Text("What should the agent do each time this heartbeat fires?")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $prompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90, maxHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("e.g. Review open PRs and summarize findings...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Schedule")

            // Quick presets
            HStack(spacing: 6) {
                ForEach(schedulePresets, id: \.cron) { preset in
                    Button(preset.label) {
                        schedule = preset.cron
                    }
                    .buttonStyle(.bordered)
                    .tint(schedule == preset.cron ? .red : nil)
                    .controlSize(.small)
                }
            }

            HStack {
                TextField("Cron", text: $schedule)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)

                if let cron = CronExpression(from: schedule) {
                    Label(cron.humanReadable, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if !schedule.isEmpty {
                    Label("Invalid", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                Toggle("Enabled", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Text("min  hour  day  month  weekday  — use * for any, */N for every N")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Working Directory

    private var directorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Working Directory")
            HStack {
                TextField("Path", text: $workingDirectory)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        workingDirectory = url.path
                    }
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Agent Options

    @ViewBuilder
    private var agentOptionsSection: some View {
        if let agent = AgentRegistry.shared.agent(for: agentId),
           !agent.availableOptions.isEmpty
        {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("\(agent.name) Options")
                ForEach(agent.availableOptions) { opt in
                    agentOptionField(opt)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()

            if !canCreate {
                Text(validationHint)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button(editing != nil ? "Save" : "Create Heartbeat") {
                saveJob()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!canCreate)
        }
        .padding()
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        !name.isEmpty && !prompt.isEmpty && CronExpression(from: schedule) != nil
    }

    private var validationHint: String {
        if name.isEmpty { return "Name required" }
        if prompt.isEmpty { return "Instructions required" }
        if CronExpression(from: schedule) == nil { return "Invalid schedule" }
        return ""
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var schedulePresets: [(label: String, cron: String)] {
        [
            ("5 min", "*/5 * * * *"),
            ("30 min", "*/30 * * * *"),
            ("Hourly", "0 * * * *"),
            ("Daily 9am", "0 9 * * *"),
            ("Weekly Mon", "0 9 * * 1"),
        ]
    }

    @ViewBuilder
    private func agentOptionField(_ opt: AgentOption) -> some View {
        switch opt.type {
        case .dropdown:
            HStack {
                Text(opt.label)
                    .font(.callout)
                Spacer()
                Picker("", selection: optionBinding(for: opt)) {
                    ForEach(opt.choices, id: \.self) { choice in
                        Text(choice).tag(choice)
                    }
                }
                .frame(width: 160)
            }
        case .toggle:
            Toggle(opt.label, isOn: Binding<Bool>(
                get: { options[opt.key] == "true" || (options[opt.key] == nil && opt.defaultValue == "true") },
                set: { options[opt.key] = $0 ? "true" : "false" }
            ))
            .font(.callout)
        case .text:
            HStack {
                Text(opt.label)
                    .font(.callout)
                Spacer()
                TextField("", text: optionBinding(for: opt), prompt: Text(opt.description))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
        }
    }

    private func optionBinding(for opt: AgentOption) -> Binding<String> {
        Binding<String>(
            get: { options[opt.key] ?? opt.defaultValue },
            set: { options[opt.key] = $0 }
        )
    }

    private func saveJob() {
        let cleanOptions = options.filter { !$0.value.isEmpty }

        if var existing = editing {
            existing.name = name
            existing.schedule = schedule
            existing.agentId = agentId
            existing.prompt = prompt
            existing.workingDirectory = workingDirectory
            existing.options = cleanOptions
            existing.isEnabled = isEnabled
            store.update(existing)
        } else {
            let job = HeartbeatJob(
                name: name,
                schedule: schedule,
                agentId: agentId,
                prompt: prompt,
                workingDirectory: workingDirectory,
                options: cleanOptions,
                isEnabled: isEnabled
            )
            store.add(job)
        }
    }
}
