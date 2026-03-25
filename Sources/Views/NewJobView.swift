import SwiftUI

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

    private let editing: HeartbeatJob?

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
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text(editing != nil ? "Edit Heartbeat" : "New Heartbeat")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            Form {
                Section("Basics") {
                    TextField("Name", text: $name, prompt: Text("e.g. Daily code review"))

                    Picker("Agent", selection: $agentId) {
                        ForEach(AgentRegistry.shared.allAgents, id: \.id) { agent in
                            HStack {
                                Image(systemName: agent.iconName)
                                Text(agent.name)
                            }
                            .tag(agent.id)
                        }
                    }
                    .onChange(of: agentId) { _, _ in options = [:] }
                }

                Section("Schedule") {
                    TextField("Cron Expression", text: $schedule, prompt: Text("*/30 * * * *"))
                        .font(.system(.body, design: .monospaced))
                    if let cron = CronExpression(from: schedule) {
                        Label(cron.humanReadable, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if !schedule.isEmpty {
                        Label("Invalid cron expression", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section("Working Directory") {
                    HStack {
                        TextField("Path", text: $workingDirectory)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                workingDirectory = url.path
                            }
                        }
                    }
                }

                agentOptionsSection

                Section("Prompt") {
                    TextEditor(text: $prompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(editing != nil ? "Save" : "Create") {
                    saveJob()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(name.isEmpty || prompt.isEmpty || CronExpression(from: schedule) == nil)
            }
            .padding()
        }
        .frame(width: 460, height: 580)
    }

    @ViewBuilder
    private var agentOptionsSection: some View {
        if let agent = AgentRegistry.shared.agent(for: agentId),
           !agent.availableOptions.isEmpty
        {
            Section("\(agent.name) Options") {
                ForEach(agent.availableOptions) { opt in
                    agentOptionField(opt)
                }
            }
        }
    }

    @ViewBuilder
    private func agentOptionField(_ opt: AgentOption) -> some View {
        switch opt.type {
        case .dropdown:
            Picker(opt.label, selection: optionBinding(for: opt)) {
                ForEach(opt.choices, id: \.self) { choice in
                    Text(choice).tag(choice)
                }
            }
        case .toggle:
            Toggle(opt.label, isOn: Binding<Bool>(
                get: { options[opt.key] == "true" || (options[opt.key] == nil && opt.defaultValue == "true") },
                set: { options[opt.key] = $0 ? "true" : "false" }
            ))
        case .text:
            TextField(opt.label, text: optionBinding(for: opt), prompt: Text(opt.description))
        }
    }

    private func optionBinding(for opt: AgentOption) -> Binding<String> {
        Binding<String>(
            get: { options[opt.key] ?? opt.defaultValue },
            set: { options[opt.key] = $0 }
        )
    }

    private func saveJob() {
        // Clean out empty-value options
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
