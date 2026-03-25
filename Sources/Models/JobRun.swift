import Foundation

struct JobRun: Identifiable, Codable {
    var id = UUID()
    var jobId: UUID
    var startedAt: Date
    var finishedAt: Date?
    var exitCode: Int32?
    var output: String
    var error: String
    var status: Status

    enum Status: String, Codable {
        case running, success, failure
    }
}
