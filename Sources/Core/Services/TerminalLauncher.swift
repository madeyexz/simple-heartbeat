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

    /// Detect which terminal multiplexers are available.
    public static func availableTerminals() -> [TerminalType] {
        var result: [TerminalType] = []
        if FileManager.default.isExecutableFile(atPath: cmuxPath) {
            result.append(.cmux)
        }
        if ProcessRunner.findExecutable("tmux") != nil {
            result.append(.tmux)
        }
        // Terminal.app is always available on macOS
        result.append(.terminalApp)
        return result
    }

    /// Build a shell-escaped command string from an AgentCommand.
    public static func shellString(from cmd: AgentCommand) -> String {
        let escaped = cmd.arguments.map { arg in
            if arg.contains(" ") || arg.contains("'") || arg.contains("\"") || arg.contains("\\") {
                return "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
            }
            return arg
        }
        return ([cmd.executable] + escaped).joined(separator: " ")
    }

    /// Build the launch command for a given terminal type.
    public static func buildLaunchArgs(
        terminal: TerminalType,
        command: String,
        workingDirectory: String,
        name: String
    ) -> AgentCommand {
        switch terminal {
        case .cmux:
            return AgentCommand(
                executable: cmuxPath,
                arguments: [
                    "new-workspace",
                    "--cwd", workingDirectory,
                    "--command", command,
                ]
            )

        case .tmux:
            // Sanitize session name for tmux (no dots or colons)
            let safeName = name
                .replacingOccurrences(of: ".", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .prefix(30)
            return AgentCommand(
                executable: "tmux",
                arguments: [
                    "new-session", "-d",
                    "-s", "hb-\(safeName)",
                    "-n", String(safeName),
                    "-c", workingDirectory,
                    command,
                ]
            )

        case .terminalApp:
            let script = """
            tell application "Terminal"
                activate
                do script "cd \(shellQuote(workingDirectory)) && \(command)"
            end tell
            """
            return AgentCommand(
                executable: "osascript",
                arguments: ["-e", script]
            )
        }
    }

    /// Launch a heartbeat job's agent command in the specified terminal.
    public static func launch(
        job: HeartbeatJob,
        agent: any AgentProvider,
        terminal: TerminalType
    ) async throws {
        let agentCmd = agent.buildCommand(
            prompt: job.prompt, options: job.options, workingDirectory: job.workingDirectory
        )
        let fullCommand = shellString(from: agentCmd)
        let launchCmd = buildLaunchArgs(
            terminal: terminal,
            command: fullCommand,
            workingDirectory: job.workingDirectory,
            name: job.name
        )

        let _ = try await ProcessRunner.run(
            executable: launchCmd.executable,
            arguments: launchCmd.arguments,
            workingDirectory: job.workingDirectory
        )

        // For tmux: attach to the session after creating it
        if terminal == .tmux {
            let safeName = job.name
                .replacingOccurrences(of: ".", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .prefix(30)
            // Open Terminal.app with tmux attach
            let attachScript = """
            tell application "Terminal"
                activate
                do script "tmux attach -t 'hb-\(safeName)'"
            end tell
            """
            let _ = try await ProcessRunner.run(
                executable: "osascript",
                arguments: ["-e", attachScript],
                workingDirectory: job.workingDirectory
            )
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
