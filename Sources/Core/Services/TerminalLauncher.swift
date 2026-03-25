import Foundation

public enum TerminalType: String, CaseIterable, Identifiable, Codable {
    case cmux
    case tmux
    case terminalApp = "terminal"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cmux: "cmux"
        case .tmux: "tmux"
        case .terminalApp: "Terminal.app"
        }
    }
}

public enum TerminalLauncher {

    private static let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    // MARK: - Detection

    public static func availableTerminals() -> [TerminalType] {
        var result: [TerminalType] = []
        if FileManager.default.isExecutableFile(atPath: cmuxPath) {
            result.append(.cmux)
        }
        if ProcessRunner.findExecutable("tmux") != nil {
            result.append(.tmux)
        }
        result.append(.terminalApp)
        return result
    }

    /// Best available multiplexer for background sessions.
    public static var bestBackgroundRunner: TerminalType {
        if FileManager.default.isExecutableFile(atPath: cmuxPath) { return .cmux }
        if ProcessRunner.findExecutable("tmux") != nil { return .tmux }
        return .terminalApp
    }

    // MARK: - Session naming

    /// Stable session name derived from job ID (survives renames).
    public static func sessionName(for job: HeartbeatJob) -> String {
        let slug = job.name
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .lowercased()
            .prefix(24)
        let short = job.id.uuidString.prefix(6).lowercased()
        return "hb-\(slug)-\(short)"
    }

    // MARK: - Run in background session

    /// Spawn the agent command in a detached background session.
    /// The process runs in tmux/cmux — the user can attach later.
    public static func runInBackground(
        job: HeartbeatJob,
        agent: any AgentProvider
    ) async throws {
        let runner = bestBackgroundRunner
        let agentCmd = agent.buildCommand(
            prompt: job.prompt, options: job.options, workingDirectory: job.workingDirectory
        )
        let fullCommand = shellString(from: agentCmd)
        let session = sessionName(for: job)

        switch runner {
        case .cmux:
            // cmux: create a new workspace (it lives in the cmux sidebar)
            let _ = try await ProcessRunner.run(
                executable: cmuxPath,
                arguments: ["new-workspace", "--cwd", job.workingDirectory, "--command", fullCommand],
                workingDirectory: job.workingDirectory
            )

        case .tmux:
            // Kill any stale session with the same name first
            let _ = try? await ProcessRunner.run(
                executable: "tmux", arguments: ["kill-session", "-t", session],
                workingDirectory: job.workingDirectory
            )
            // Create a detached session — runs in background
            let _ = try await ProcessRunner.run(
                executable: "tmux",
                arguments: [
                    "new-session", "-d",
                    "-s", session,
                    "-n", String(job.name.prefix(20)),
                    "-c", job.workingDirectory,
                    fullCommand,
                ],
                workingDirectory: job.workingDirectory
            )

        case .terminalApp:
            // Fallback: no multiplexer, run directly (no background session to attach to later)
            let _ = try await ProcessRunner.run(
                executable: agentCmd.executable,
                arguments: agentCmd.arguments,
                workingDirectory: job.workingDirectory
            )
        }
    }

    // MARK: - Attach to existing session

    /// Check if a background session exists for this job.
    public static func hasSession(for job: HeartbeatJob) -> Bool {
        let session = sessionName(for: job)
        let runner = bestBackgroundRunner

        switch runner {
        case .tmux:
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: ProcessRunner.findExecutable("tmux") ?? "/usr/bin/tmux")
            proc.arguments = ["has-session", "-t", session]
            proc.standardOutput = Pipe()
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0

        case .cmux:
            // cmux workspaces persist in the app — assume session exists if job is running
            return true

        case .terminalApp:
            return false
        }
    }

    /// Open the user's preferred terminal and attach to the background session.
    public static func attachToSession(
        job: HeartbeatJob,
        openIn terminal: TerminalType
    ) async throws {
        let session = sessionName(for: job)
        let runner = bestBackgroundRunner

        switch runner {
        case .tmux:
            switch terminal {
            case .cmux:
                // Open cmux with tmux attach command
                let _ = try await ProcessRunner.run(
                    executable: cmuxPath,
                    arguments: ["new-workspace", "--command", "tmux attach -t '\(session)'"],
                    workingDirectory: job.workingDirectory
                )
            case .tmux, .terminalApp:
                // Open Terminal.app (or current terminal) with tmux attach
                let script = """
                tell application "Terminal"
                    activate
                    do script "tmux attach -t '\(session)'"
                end tell
                """
                let _ = try await ProcessRunner.run(
                    executable: "osascript",
                    arguments: ["-e", script],
                    workingDirectory: job.workingDirectory
                )
            }

        case .cmux:
            // cmux: just activate cmux — the workspace is already there
            let _ = try await ProcessRunner.run(
                executable: "open",
                arguments: ["-a", "cmux"],
                workingDirectory: job.workingDirectory
            )

        case .terminalApp:
            // No background session to attach to
            break
        }
    }

    // MARK: - Helpers

    public static func shellString(from cmd: AgentCommand) -> String {
        let escaped = cmd.arguments.map { arg in
            if arg.contains(" ") || arg.contains("'") || arg.contains("\"")
                || arg.contains("\\") || arg.contains(";") || arg.contains("&")
                || arg.contains("(") || arg.contains(")")
            {
                return "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
            }
            return arg
        }
        return ([cmd.executable] + escaped).joined(separator: " ")
    }

    /// For building custom launch commands (used by tests).
    public static func buildLaunchArgs(
        terminal: TerminalType,
        command: String,
        workingDirectory: String,
        name: String
    ) -> AgentCommand {
        let session = "hb-\(name.prefix(24).replacingOccurrences(of: " ", with: "-").lowercased())"

        switch terminal {
        case .cmux:
            return AgentCommand(
                executable: cmuxPath,
                arguments: ["new-workspace", "--cwd", workingDirectory, "--command", command]
            )
        case .tmux:
            return AgentCommand(
                executable: "tmux",
                arguments: ["new-session", "-d", "-s", session, "-c", workingDirectory, command]
            )
        case .terminalApp:
            let script = """
            tell application "Terminal"
                activate
                do script "cd \(shellQuote(workingDirectory)) && \(command)"
            end tell
            """
            return AgentCommand(executable: "osascript", arguments: ["-e", script])
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
