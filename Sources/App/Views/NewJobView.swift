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

    // User-friendly schedule state
    @State private var frequency: ScheduleFrequency
    @State private var intervalMinutes: Int
    @State private var intervalHours: Int
    @State private var dailyHour: Int
    @State private var dailyMinute: Int
    @State private var weeklyDay: Int // 0=Sun..6=Sat
    @State private var showAdvancedCron = false

    private let editing: HeartbeatJob?

    private enum Field: Hashable {
        case name, prompt, schedule
    }

    enum ScheduleFrequency: String, CaseIterable, Identifiable {
        case minutes = "Every N Minutes"
        case hours = "Every N Hours"
        case daily = "Daily"
        case weekly = "Weekly"
        case custom = "Custom (cron)"

        var id: String { rawValue }
    }

    init(editing: HeartbeatJob? = nil) {
        self.editing = editing
        let sched = editing?.schedule ?? "*/30 * * * *"
        _name = State(initialValue: editing?.name ?? "")
        _schedule = State(initialValue: sched)
        _agentId = State(initialValue: editing?.agentId ?? AgentRegistry.shared.agentIds.first ?? "claude")
        _prompt = State(initialValue: editing?.prompt ?? "")
        _workingDirectory = State(initialValue: editing?.workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path)
        _options = State(initialValue: editing?.options ?? [:])
        _isEnabled = State(initialValue: editing?.isEnabled ?? true)

        // Parse existing cron into user-friendly state
        let parsed = Self.parseCron(sched)
        _frequency = State(initialValue: parsed.freq)
        _intervalMinutes = State(initialValue: parsed.intervalMin)
        _intervalHours = State(initialValue: parsed.intervalHr)
        _dailyHour = State(initialValue: parsed.hour)
        _dailyMinute = State(initialValue: parsed.minute)
        _weeklyDay = State(initialValue: parsed.dow)
        _showAdvancedCron = State(initialValue: parsed.freq == .custom)
    }

    private static func parseCron(_ cron: String) -> (freq: ScheduleFrequency, intervalMin: Int, intervalHr: Int, hour: Int, minute: Int, dow: Int) {
        let parts = cron.split(separator: " ").map(String.init)
        guard parts.count == 5 else { return (.custom, 30, 1, 9, 0, 1) }

        // */N * * * * → every N minutes
        if parts[0].hasPrefix("*/"), parts[1...4].allSatisfy({ $0 == "*" }),
           let n = Int(parts[0].dropFirst(2)) {
            return (.minutes, n, 1, 9, 0, 1)
        }
        // M */N * * * → every N hours
        if parts[1].hasPrefix("*/"), parts[2...4].allSatisfy({ $0 == "*" }),
           let m = Int(parts[0]), let n = Int(parts[1].dropFirst(2)) {
            return (.hours, 30, n, 9, m, 1)
        }
        // M H * * dow → weekly
        if parts[2] == "*", parts[3] == "*", let dow = Int(parts[4]),
           let h = Int(parts[1]), let m = Int(parts[0]) {
            return (.weekly, 30, 1, h, m, dow)
        }
        // M H * * * → daily
        if parts[2...4].allSatisfy({ $0 == "*" }),
           let h = Int(parts[1]), let m = Int(parts[0]) {
            return (.daily, 30, 1, h, m, 1)
        }
        // Hourly at :M
        if parts[1...4].allSatisfy({ $0 == "*" }), let m = Int(parts[0]) {
            return (.hours, 30, 1, 9, m, 1)
        }
        return (.custom, 30, 1, 9, 0, 1)
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
            HStack {
                sectionLabel("Schedule")
                Spacer()
                Toggle("Enabled", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Picker("Frequency", selection: $frequency) {
                ForEach(ScheduleFrequency.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: frequency) { _, _ in rebuildCron() }

            // Frequency-specific controls
            switch frequency {
            case .minutes:
                HStack {
                    Text("Every")
                    Picker("", selection: $intervalMinutes) {
                        ForEach([1, 2, 5, 10, 15, 20, 30], id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .frame(width: 70)
                    .onChange(of: intervalMinutes) { _, _ in rebuildCron() }
                    Text("minutes")
                }
                .font(.callout)

            case .hours:
                HStack {
                    Text("Every")
                    Picker("", selection: $intervalHours) {
                        ForEach([1, 2, 3, 4, 6, 8, 12], id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .frame(width: 70)
                    .onChange(of: intervalHours) { _, _ in rebuildCron() }
                    Text("hours at minute")
                    Picker("", selection: $dailyMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { m in
                            Text(":\(String(format: "%02d", m))").tag(m)
                        }
                    }
                    .frame(width: 70)
                    .onChange(of: dailyMinute) { _, _ in rebuildCron() }
                }
                .font(.callout)

            case .daily:
                HStack {
                    Text("Every day at")
                    timePicker
                }
                .font(.callout)

            case .weekly:
                HStack {
                    Text("Every")
                    Picker("", selection: $weeklyDay) {
                        ForEach(Array(dayNames.enumerated()), id: \.offset) { i, name in
                            Text(name).tag(i)
                        }
                    }
                    .frame(width: 110)
                    .onChange(of: weeklyDay) { _, _ in rebuildCron() }
                    Text("at")
                    timePicker
                }
                .font(.callout)

            case .custom:
                HStack {
                    TextField("Cron expression", text: $schedule)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                    if let cron = CronExpression(from: schedule) {
                        Label(cron.humanReadable, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if !schedule.isEmpty {
                        Label("Invalid", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text("Format: min hour day month weekday")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Preview
            if frequency != .custom, let cron = CronExpression(from: schedule) {
                Label(cron.humanReadable, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private var timePicker: some View {
        HStack(spacing: 2) {
            Picker("", selection: $dailyHour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .frame(width: 60)
            .onChange(of: dailyHour) { _, _ in rebuildCron() }
            Text(":")
            Picker("", selection: $dailyMinute) {
                ForEach([0, 5, 10, 15, 20, 30, 45], id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .frame(width: 60)
            .onChange(of: dailyMinute) { _, _ in rebuildCron() }
        }
    }

    private var dayNames: [String] {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    }

    private func rebuildCron() {
        switch frequency {
        case .minutes:
            schedule = "*/\(intervalMinutes) * * * *"
        case .hours:
            schedule = intervalHours == 1
                ? "\(dailyMinute) * * * *"
                : "\(dailyMinute) */\(intervalHours) * * *"
        case .daily:
            schedule = "\(dailyMinute) \(dailyHour) * * *"
        case .weekly:
            schedule = "\(dailyMinute) \(dailyHour) * * \(weeklyDay)"
        case .custom:
            break // User edits directly
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
