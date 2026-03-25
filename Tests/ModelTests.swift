import Testing
import Foundation
@testable import HeartbeatCore

@Suite("Models")
struct ModelTests {

    // MARK: - HeartbeatJob

    @Test("HeartbeatJob round-trips through JSON")
    func jobCodable() throws {
        let job = HeartbeatJob(
            name: "Test Job",
            schedule: "*/5 * * * *",
            agentId: "claude",
            prompt: "do something",
            workingDirectory: "/tmp",
            options: ["model": "opus"]
        )
        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(HeartbeatJob.self, from: data)
        #expect(decoded.name == "Test Job")
        #expect(decoded.schedule == "*/5 * * * *")
        #expect(decoded.agentId == "claude")
        #expect(decoded.prompt == "do something")
        #expect(decoded.options["model"] == "opus")
        #expect(decoded.isEnabled == true)
        #expect(decoded.id == job.id)
    }

    @Test("HeartbeatJob defaults")
    func jobDefaults() {
        let job = HeartbeatJob(
            name: "x", schedule: "* * * * *", agentId: "claude",
            prompt: "y", workingDirectory: "/tmp"
        )
        #expect(job.isEnabled == true)
        #expect(job.options.isEmpty)
    }

    // MARK: - JobRun

    @Test("JobRun round-trips through JSON")
    func runCodable() throws {
        var run = JobRun(
            jobId: UUID(),
            startedAt: Date(),
            output: "hello",
            error: "",
            status: .success
        )
        run.finishedAt = Date()
        run.exitCode = 0

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(run)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(JobRun.self, from: data)

        #expect(decoded.status == .success)
        #expect(decoded.output == "hello")
        #expect(decoded.exitCode == 0)
    }

    @Test("JobRun status values")
    func runStatuses() {
        #expect(JobRun.Status.running.rawValue == "running")
        #expect(JobRun.Status.success.rawValue == "success")
        #expect(JobRun.Status.failure.rawValue == "failure")
    }

    // MARK: - AgentOption

    @Test("AgentOption id is derived from key")
    func optionId() {
        let opt = AgentOption(
            key: "model", label: "Model", description: "desc",
            type: .dropdown, defaultValue: "sonnet", choices: ["sonnet", "opus"]
        )
        #expect(opt.id == "model")
    }
}
