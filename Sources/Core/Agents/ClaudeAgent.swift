import Foundation

public struct ClaudeAgent: AgentProvider {
    public let id = "claude"
    public let name = "Claude Code"
    public let iconName = "brain.head.profile"
    public let description = "Anthropic's Claude Code CLI"

    public init() {}

    public var availableOptions: [AgentOption] {
        [
            AgentOption(
                key: "model", label: "Model",
                description: "Claude model to use",
                type: .dropdown, defaultValue: "sonnet",
                choices: [
                    "sonnet", "opus", "haiku",
                    "sonnet[1m]", "opus[1m]",
                    "opusplan",
                    "claude-sonnet-4-6", "claude-opus-4-6",
                    "claude-haiku-4-5",
                ]
            ),
            AgentOption(
                key: "effort", label: "Effort",
                description: "Reasoning effort level",
                type: .dropdown, defaultValue: "high",
                choices: ["low", "medium", "high", "max"]
            ),
            AgentOption(
                key: "permission-mode", label: "Permission Mode",
                description: "How permissions are handled",
                type: .dropdown, defaultValue: "default",
                choices: ["default", "plan", "auto", "bypassPermissions"]
            ),
            AgentOption(
                key: "max-budget-usd", label: "Max Budget ($)",
                description: "Maximum dollar amount to spend",
                type: .text, defaultValue: "",
                choices: []
            ),
            AgentOption(
                key: "system-prompt", label: "System Prompt",
                description: "Custom system prompt override",
                type: .text, defaultValue: "",
                choices: []
            ),
            AgentOption(
                key: "allowedTools", label: "Allowed Tools",
                description: "Space-separated tool names (e.g. Bash Edit Read)",
                type: .text, defaultValue: "",
                choices: []
            ),
        ]
    }

    public func buildCommand(prompt: String, options: [String: String], workingDirectory: String) -> AgentCommand {
        var args = ["--print"] // non-interactive print mode

        if let model = options["model"], !model.isEmpty {
            args += ["--model", model]
        }
        if let effort = options["effort"], !effort.isEmpty, effort != "high" {
            args += ["--effort", effort]
        }
        if let perm = options["permission-mode"], !perm.isEmpty, perm != "default" {
            args += ["--permission-mode", perm]
        }
        if let budget = options["max-budget-usd"], !budget.isEmpty {
            args += ["--max-budget-usd", budget]
        }
        if let sys = options["system-prompt"], !sys.isEmpty {
            args += ["--system-prompt", sys]
        }
        if let tools = options["allowedTools"], !tools.isEmpty {
            args += ["--allowedTools", tools]
        }

        args.append(prompt)

        return AgentCommand(executable: "claude", arguments: args)
    }
}
