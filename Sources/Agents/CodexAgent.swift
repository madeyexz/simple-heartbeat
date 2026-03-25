import Foundation

struct CodexAgent: AgentProvider {
    let id = "codex"
    let name = "Codex"
    let iconName = "chevron.left.forwardslash.chevron.right"
    let description = "OpenAI's Codex CLI"

    var availableOptions: [AgentOption] {
        [
            AgentOption(
                key: "model", label: "Model",
                description: "Model to use (e.g. o3, o4-mini)",
                type: .text, defaultValue: "",
                choices: []
            ),
            AgentOption(
                key: "approval", label: "Approval Policy",
                description: "When to ask for human approval",
                type: .dropdown, defaultValue: "never",
                choices: ["untrusted", "on-request", "never"]
            ),
            AgentOption(
                key: "sandbox", label: "Sandbox Mode",
                description: "Sandbox policy for commands",
                type: .dropdown, defaultValue: "workspace-write",
                choices: ["read-only", "workspace-write", "danger-full-access"]
            ),
            AgentOption(
                key: "full-auto", label: "Full Auto",
                description: "Low-friction sandboxed auto execution",
                type: .toggle, defaultValue: "false",
                choices: []
            ),
            AgentOption(
                key: "search", label: "Web Search",
                description: "Enable live web search",
                type: .toggle, defaultValue: "false",
                choices: []
            ),
        ]
    }

    func buildCommand(prompt: String, options: [String: String], workingDirectory: String) -> AgentCommand {
        var args = ["exec"] // non-interactive exec subcommand

        if let model = options["model"], !model.isEmpty {
            args += ["-m", model]
        }
        if let approval = options["approval"], !approval.isEmpty {
            args += ["-a", approval]
        }
        if let sandbox = options["sandbox"], !sandbox.isEmpty {
            args += ["-s", sandbox]
        }
        if options["full-auto"] == "true" {
            args.append("--full-auto")
        }
        if options["search"] == "true" {
            args.append("--search")
        }

        args.append(prompt)

        return AgentCommand(executable: "codex", arguments: args)
    }
}
