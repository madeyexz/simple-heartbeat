import Foundation

public struct HeartbeatJob: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var schedule: String // cron expression (5 fields: min hour dom month dow)
    public var agentId: String
    public var prompt: String
    public var workingDirectory: String
    public var options: [String: String] = [:]
    public var isEnabled: Bool = true
    public var createdAt: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String,
        schedule: String,
        agentId: String,
        prompt: String,
        workingDirectory: String,
        options: [String: String] = [:],
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.schedule = schedule
        self.agentId = agentId
        self.prompt = prompt
        self.workingDirectory = workingDirectory
        self.options = options
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}
