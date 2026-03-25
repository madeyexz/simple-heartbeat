import Foundation

struct HeartbeatJob: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var schedule: String // cron expression (5 fields: min hour dom month dow)
    var agentId: String
    var prompt: String
    var workingDirectory: String
    var options: [String: String] = [:]
    var isEnabled: Bool = true
    var createdAt: Date = Date()
}
