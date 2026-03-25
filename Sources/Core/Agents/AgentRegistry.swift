import Foundation

/// Central registry of available agent backends.
/// To add a new agent: create a struct conforming to `AgentProvider`, then call `register()`.
public final class AgentRegistry {
    public static let shared = AgentRegistry()

    private var agents: [String: any AgentProvider] = [:]

    public init() {
        register(ClaudeAgent())
        register(CodexAgent())
    }

    public func register(_ agent: any AgentProvider) {
        agents[agent.id] = agent
    }

    public func agent(for id: String) -> (any AgentProvider)? {
        agents[id]
    }

    public var allAgents: [any AgentProvider] {
        Array(agents.values).sorted { $0.name < $1.name }
    }

    public var agentIds: [String] {
        allAgents.map(\.id)
    }
}
