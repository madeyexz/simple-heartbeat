import Foundation

/// Central registry of available agent backends.
/// To add a new agent: create a struct conforming to `AgentProvider`, then call `register()`.
final class AgentRegistry {
    static let shared = AgentRegistry()

    private var agents: [String: any AgentProvider] = [:]

    init() {
        register(ClaudeAgent())
        register(CodexAgent())
    }

    func register(_ agent: any AgentProvider) {
        agents[agent.id] = agent
    }

    func agent(for id: String) -> (any AgentProvider)? {
        agents[id]
    }

    var allAgents: [any AgentProvider] {
        Array(agents.values).sorted { $0.name < $1.name }
    }

    var agentIds: [String] {
        allAgents.map(\.id)
    }
}
