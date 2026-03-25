import Testing
import Foundation
@testable import HeartbeatCore

@Suite("Agent layer")
struct AgentTests {

    // MARK: - Registry

    @Test("Registry contains Claude and Codex by default")
    func registryDefaults() {
        let reg = AgentRegistry()
        #expect(reg.agent(for: "claude") != nil)
        #expect(reg.agent(for: "codex") != nil)
        #expect(reg.allAgents.count == 2)
    }

    @Test("Registry lookup returns nil for unknown agent")
    func registryUnknown() {
        let reg = AgentRegistry()
        #expect(reg.agent(for: "gemini") == nil)
    }

    @Test("Can register a custom agent")
    func registryCustom() {
        let reg = AgentRegistry()
        reg.register(StubAgent(id: "stub", name: "Stub"))
        #expect(reg.agent(for: "stub") != nil)
        #expect(reg.allAgents.count == 3)
    }

    // MARK: - Claude command building

    @Test("Claude builds basic print-mode command")
    func claudeBasic() {
        let claude = ClaudeAgent()
        let cmd = claude.buildCommand(prompt: "hello", options: [:], workingDirectory: "/tmp")
        #expect(cmd.executable == "claude")
        #expect(cmd.arguments.contains("--print"))
        #expect(cmd.arguments.last == "hello")
    }

    @Test("Claude includes model flag")
    func claudeModel() {
        let claude = ClaudeAgent()
        let cmd = claude.buildCommand(
            prompt: "test", options: ["model": "opus"], workingDirectory: "/tmp"
        )
        #expect(cmd.arguments.contains("--model"))
        if let idx = cmd.arguments.firstIndex(of: "--model") {
            #expect(cmd.arguments[idx + 1] == "opus")
        }
    }

    @Test("Claude includes budget flag")
    func claudeBudget() {
        let claude = ClaudeAgent()
        let cmd = claude.buildCommand(
            prompt: "test", options: ["max-budget-usd": "5.00"], workingDirectory: "/tmp"
        )
        #expect(cmd.arguments.contains("--max-budget-usd"))
    }

    @Test("Claude skips empty options")
    func claudeSkipsEmpty() {
        let claude = ClaudeAgent()
        let cmd = claude.buildCommand(
            prompt: "test",
            options: ["model": "", "max-budget-usd": "", "system-prompt": ""],
            workingDirectory: "/tmp"
        )
        #expect(!cmd.arguments.contains("--max-budget-usd"))
        #expect(!cmd.arguments.contains("--system-prompt"))
    }

    @Test("Claude skips default permission mode")
    func claudeDefaultPerm() {
        let claude = ClaudeAgent()
        let cmd = claude.buildCommand(
            prompt: "test", options: ["permission-mode": "default"], workingDirectory: "/tmp"
        )
        #expect(!cmd.arguments.contains("--permission-mode"))
    }

    // MARK: - Codex command building

    @Test("Codex builds exec subcommand")
    func codexBasic() {
        let codex = CodexAgent()
        let cmd = codex.buildCommand(prompt: "hello", options: [:], workingDirectory: "/tmp")
        #expect(cmd.executable == "codex")
        #expect(cmd.arguments.first == "exec")
        #expect(cmd.arguments.last == "hello")
    }

    @Test("Codex includes reasoning effort via config override")
    func codexReasoningEffort() {
        let codex = CodexAgent()
        let cmd = codex.buildCommand(
            prompt: "test",
            options: ["reasoning-effort": "high"],
            workingDirectory: "/tmp"
        )
        #expect(cmd.arguments.contains("-c"))
        // Should contain a config value with reasoning_effort
        let configIdx = cmd.arguments.firstIndex(of: "-c")!
        #expect(cmd.arguments[configIdx + 1].contains("reasoning_effort"))
    }

    @Test("Codex exposes reasoning effort option")
    func codexHasReasoningEffort() {
        let codex = CodexAgent()
        let keys = codex.availableOptions.map(\.key)
        #expect(keys.contains("reasoning-effort"))
    }

    @Test("Codex includes approval and sandbox flags")
    func codexFlags() {
        let codex = CodexAgent()
        let cmd = codex.buildCommand(
            prompt: "test",
            options: ["approval": "never", "sandbox": "workspace-write"],
            workingDirectory: "/tmp"
        )
        #expect(cmd.arguments.contains("-a"))
        #expect(cmd.arguments.contains("never"))
        #expect(cmd.arguments.contains("-s"))
        #expect(cmd.arguments.contains("workspace-write"))
    }

    @Test("Codex full-auto flag")
    func codexFullAuto() {
        let codex = CodexAgent()
        let cmd = codex.buildCommand(
            prompt: "test", options: ["full-auto": "true"], workingDirectory: "/tmp"
        )
        #expect(cmd.arguments.contains("--full-auto"))
    }

    @Test("Codex full-auto false is omitted")
    func codexFullAutoFalse() {
        let codex = CodexAgent()
        let cmd = codex.buildCommand(
            prompt: "test", options: ["full-auto": "false"], workingDirectory: "/tmp"
        )
        #expect(!cmd.arguments.contains("--full-auto"))
    }

    // MARK: - Agent options

    @Test("Claude exposes expected option keys")
    func claudeOptions() {
        let claude = ClaudeAgent()
        let keys = claude.availableOptions.map(\.key)
        #expect(keys.contains("model"))
        #expect(keys.contains("permission-mode"))
        #expect(keys.contains("max-budget-usd"))
    }

    @Test("Codex exposes expected option keys")
    func codexOptions() {
        let codex = CodexAgent()
        let keys = codex.availableOptions.map(\.key)
        #expect(keys.contains("model"))
        #expect(keys.contains("approval"))
        #expect(keys.contains("sandbox"))
        #expect(keys.contains("full-auto"))
    }
}

// MARK: - Test doubles

private struct StubAgent: AgentProvider {
    public var id: String
    public var name: String
    public var iconName: String = "star"
    public var description: String = "Test agent"
    public var availableOptions: [AgentOption] = []

    public func buildCommand(
        prompt: String, options: [String: String], workingDirectory: String
    ) -> AgentCommand {
        AgentCommand(executable: "echo", arguments: [prompt])
    }
}
