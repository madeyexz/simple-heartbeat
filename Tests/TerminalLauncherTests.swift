import Testing
import Foundation
@testable import HeartbeatCore

@Suite("TerminalLauncher")
struct TerminalLauncherTests {

    @Test("Detects available terminals")
    func detectTerminals() {
        let terminals = TerminalLauncher.availableTerminals()
        #expect(terminals.contains(.terminalApp))
    }

    @Test("All terminal types have display names")
    func terminalNames() {
        for t in TerminalType.allCases {
            #expect(!t.displayName.isEmpty)
        }
    }

    @Test("Session name is stable and slug-safe")
    func sessionName() {
        let job = HeartbeatJob(
            name: "PR Review Bot",
            schedule: "0 9 * * *",
            agentId: "claude",
            prompt: "test",
            workingDirectory: "/tmp"
        )
        let name = TerminalLauncher.sessionName(for: job)
        #expect(name.hasPrefix("hb-"))
        #expect(!name.contains(" "))
        #expect(!name.contains("."))
        #expect(!name.contains(":"))
        #expect(name.contains("pr-review-bot"))
    }

    @Test("Session name includes job ID prefix for uniqueness")
    func sessionNameUnique() {
        let job1 = HeartbeatJob(
            name: "Same Name", schedule: "* * * * *", agentId: "claude",
            prompt: "a", workingDirectory: "/tmp"
        )
        let job2 = HeartbeatJob(
            name: "Same Name", schedule: "* * * * *", agentId: "claude",
            prompt: "b", workingDirectory: "/tmp"
        )
        #expect(TerminalLauncher.sessionName(for: job1) != TerminalLauncher.sessionName(for: job2))
    }

    @Test("Best background runner prefers tmux/cmux over Terminal.app")
    func bestRunner() {
        let runner = TerminalLauncher.bestBackgroundRunner
        // On a dev machine with tmux installed, it should prefer tmux or cmux
        #expect(runner != .terminalApp || ProcessRunner.findExecutable("tmux") == nil)
    }

    @Test("Builds tmux background session command")
    func tmuxCommand() {
        let cmd = TerminalLauncher.buildLaunchArgs(
            terminal: .tmux,
            command: "claude --print 'hello'",
            workingDirectory: "/tmp/project",
            name: "My Job"
        )
        #expect(cmd.executable == "tmux")
        #expect(cmd.arguments.contains("new-session"))
        #expect(cmd.arguments.contains("-d"))
        #expect(cmd.arguments.contains("-s"))
        #expect(cmd.arguments.contains("-c"))
        #expect(cmd.arguments.contains("/tmp/project"))
    }

    @Test("Shell string escapes arguments with spaces")
    func shellStringEscaping() {
        let cmd = AgentCommand(executable: "claude", arguments: ["--print", "hello world", "--model", "opus"])
        let s = TerminalLauncher.shellString(from: cmd)
        #expect(s.contains("'hello world'"))
        #expect(s.hasPrefix("claude"))
    }

    @Test("Shell string handles single quotes")
    func shellStringQuotes() {
        let cmd = AgentCommand(executable: "claude", arguments: ["it's a test"])
        let s = TerminalLauncher.shellString(from: cmd)
        #expect(s.contains("'it'\\''s a test'"))
    }

    @Test("Builds full agent command string from job")
    func fullCommandFromJob() {
        let agent = ClaudeAgent()
        let agentCmd = agent.buildCommand(
            prompt: "review PRs", options: ["model": "opus"], workingDirectory: "/tmp"
        )
        let fullCmd = TerminalLauncher.shellString(from: agentCmd)
        #expect(fullCmd.contains("claude"))
        #expect(fullCmd.contains("--print"))
        #expect(fullCmd.contains("--model"))
        #expect(fullCmd.contains("opus"))
    }
}
