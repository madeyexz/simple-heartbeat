import Foundation

public struct JobRun: Identifiable, Codable {
    public var id = UUID()
    public var jobId: UUID
    public var startedAt: Date
    public var finishedAt: Date?
    public var exitCode: Int32?
    public var output: String
    public var error: String
    public var status: Status

    public enum Status: String, Codable {
        case running, success, failure
    }

    public init(
        id: UUID = UUID(),
        jobId: UUID,
        startedAt: Date,
        finishedAt: Date? = nil,
        exitCode: Int32? = nil,
        output: String,
        error: String,
        status: Status
    ) {
        self.id = id
        self.jobId = jobId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.output = output
        self.error = error
        self.status = status
    }
}
