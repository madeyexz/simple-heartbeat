import Foundation

/// Normalized abstraction for AI agent backends.
/// Conform to this protocol to add a new agent (e.g. Gemini, local Ollama, etc.)
protocol AgentProvider {
    var id: String { get }
    var name: String { get }
    var iconName: String { get }
    var description: String { get }
    var availableOptions: [AgentOption] { get }

    /// Build the shell command to run this agent non-interactively.
    func buildCommand(
        prompt: String,
        options: [String: String],
        workingDirectory: String
    ) -> AgentCommand
}

struct AgentCommand {
    let executable: String
    let arguments: [String]
}
