import Testing
import Foundation
@testable import HeartbeatCore

@Suite("TerminalLauncher")
struct TerminalLauncherTests {

    @Test("Detects available terminals")
    func detectTerminals() {
        let terminals = TerminalLauncher.availableTerminals()
        // Terminal.app is always available on macOS
        #expect(terminals.contains(.terminalApp))
    }

    @Test("All terminal types have display names")
    func terminalNames() {
        for t in TerminalType.allCases {
            #expect(!t.displayName.isEmpty)
        }
    }

    @Test("Builds cmux launch command")
    func cmuxCommand() {
        let cmd = TerminalLauncher.buildLaunchArgs(
            terminal: .cmux,
            command: "claude --print 'hello'",
            workingDirectory: "/tmp/project",
            name: "My Job"
        )
        #expect(cmd.executable == "/Applications/cmux.app/Contents/Resources/bin/cmux")
        #expect(cmd.arguments.contains("new-workspace"))
        #expect(cmd.arguments.contains("--cwd"))
        #expect(cmd.arguments.contains("/tmp/project"))
        #expect(cmd.arguments.contains("--command"))
    }

    @Test("Builds tmux launch command for new session")
    func tmuxNewSession() {
        let cmd = TerminalLauncher.buildLaunchArgs(
            terminal: .tmux,
            command: "codex exec 'test'",
            workingDirectory: "/tmp/project",
            name: "My Job"
        )
        #expect(cmd.executable == "tmux")
        #expect(cmd.arguments.contains("new-session"))
        #expect(cmd.arguments.contains("-s"))
    }

    @Test("Builds Terminal.app launch via open command")
    func terminalAppCommand() {
        let cmd = TerminalLauncher.buildLaunchArgs(
            terminal: .terminalApp,
            command: "claude --print 'hello'",
            workingDirectory: "/tmp/project",
            name: "Test"
        )
        // Terminal.app uses osascript
        #expect(cmd.executable == "osascript")
    }

    @Test("Builds full agent command string from job")
    func fullCommandFromJob() {
        let job = HeartbeatJob(
            name: "Test",
            schedule: "0 9 * * *",
            agentId: "claude",
            prompt: "review PRs",
            workingDirectory: "/tmp",
            options: ["model": "opus"]
        )
        let agent = ClaudeAgent()
        let agentCmd = agent.buildCommand(
            prompt: job.prompt, options: job.options, workingDirectory: job.workingDirectory
        )
        let fullCmd = TerminalLauncher.shellString(from: agentCmd)
        #expect(fullCmd.contains("claude"))
        #expect(fullCmd.contains("--print"))
        #expect(fullCmd.contains("--model"))
        #expect(fullCmd.contains("opus"))
        #expect(fullCmd.contains("review PRs"))
    }
}
