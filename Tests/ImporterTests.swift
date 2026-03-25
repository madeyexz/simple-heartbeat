import Testing
import Foundation
@testable import HeartbeatCore

@Suite("TOML Parser")
struct TOMLParserTests {

    @Test("Parses string values")
    func parseStrings() {
        let toml = SimpleTOML.parse("""
        name = "Hello World"
        id = "test-123"
        """)
        #expect(toml["name"] == "Hello World")
        #expect(toml["id"] == "test-123")
    }

    @Test("Parses integer values")
    func parseIntegers() {
        let toml = SimpleTOML.parse("""
        version = 1
        created_at = 1773208155194
        """)
        #expect(toml["version"] == "1")
        #expect(toml["created_at"] == "1773208155194")
    }

    @Test("Parses string arrays")
    func parseArrays() {
        let toml = SimpleTOML.parse("""
        cwds = ["/Users/test/project"]
        """)
        #expect(toml["cwds"] == "/Users/test/project")
    }

    @Test("Parses multi-element arrays (takes first)")
    func parseMultiElementArray() {
        let toml = SimpleTOML.parse("""
        cwds = ["/path/a", "/path/b"]
        """)
        #expect(toml["cwds"] == "/path/a")
    }

    @Test("Handles escaped newlines in strings")
    func parseEscapedNewlines() {
        let toml = SimpleTOML.parse(#"prompt = "line1\nline2""#)
        #expect(toml["prompt"]?.contains("\n") == true)
    }

    @Test("Skips comment lines")
    func skipComments() {
        let toml = SimpleTOML.parse("""
        # This is a comment
        name = "test"
        """)
        #expect(toml["name"] == "test")
        #expect(toml.count == 1)
    }

    @Test("Skips empty lines")
    func skipEmpty() {
        let toml = SimpleTOML.parse("""
        name = "test"

        id = "123"
        """)
        #expect(toml.count == 2)
    }

    @Test("Real Codex automation.toml")
    func realCodexToml() {
        let toml = SimpleTOML.parse("""
        version = 1
        id = "tiktok-growth-loop"
        name = "TikTok Growth Loop"
        prompt = "Follow the instructions"
        status = "ACTIVE"
        rrule = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU;BYHOUR=9;BYMINUTE=0"
        execution_environment = "local"
        model = "gpt-5.4"
        reasoning_effort = "high"
        cwds = ["/Users/test/project"]
        created_at = 1773208155194
        updated_at = 1773366477848
        """)
        #expect(toml["id"] == "tiktok-growth-loop")
        #expect(toml["name"] == "TikTok Growth Loop")
        #expect(toml["rrule"] == "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU;BYHOUR=9;BYMINUTE=0")
        #expect(toml["model"] == "gpt-5.4")
        #expect(toml["cwds"] == "/Users/test/project")
        #expect(toml["status"] == "ACTIVE")
    }
}

@Suite("CodexImporter")
struct CodexImporterTests {

    @Test("Converts Codex automation to HeartbeatJob")
    func convertToJob() throws {
        let toml: [String: String] = [
            "id": "test-auto",
            "name": "Test Automation",
            "prompt": "Do something useful",
            "status": "ACTIVE",
            "rrule": "FREQ=DAILY;BYHOUR=9;BYMINUTE=0",
            "model": "gpt-5.4",
            "reasoning_effort": "high",
            "cwds": "/Users/test/project",
        ]

        let job = try CodexImporter.toHeartbeatJob(from: toml)
        #expect(job.name == "Test Automation")
        #expect(job.prompt == "Do something useful")
        #expect(job.schedule == "0 9 * * *")
        #expect(job.agentId == "codex")
        #expect(job.workingDirectory == "/Users/test/project")
        #expect(job.options["model"] == "gpt-5.4")
        #expect(job.isEnabled == true)
    }

    @Test("Paused automation imports as disabled")
    func pausedIsDisabled() throws {
        let toml: [String: String] = [
            "name": "Paused",
            "prompt": "test",
            "status": "PAUSED",
            "rrule": "FREQ=HOURLY;BYMINUTE=0",
            "cwds": "/tmp",
        ]
        let job = try CodexImporter.toHeartbeatJob(from: toml)
        #expect(job.isEnabled == false)
    }

    @Test("Missing required fields throw")
    func missingFieldsThrow() {
        let toml: [String: String] = ["name": "Incomplete"]
        #expect(throws: ImportError.self) {
            try CodexImporter.toHeartbeatJob(from: toml)
        }
    }
}

@Suite("ClaudeImporter")
struct ClaudeImporterTests {

    @Test("Converts Claude scheduled task JSON to HeartbeatJob")
    func convertToJob() throws {
        let json: [String: Any] = [
            "cron": "*/30 * * * *",
            "prompt": "Check deployment status",
            "recurring": true,
            "durable": true,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let job = try ClaudeImporter.toHeartbeatJob(from: data)
        #expect(job.name == "Check deployment status")
        #expect(job.schedule == "*/30 * * * *")
        #expect(job.agentId == "claude")
        #expect(job.prompt == "Check deployment status")
        #expect(job.isEnabled == true)
    }

    @Test("Uses truncated prompt as name")
    func truncatedName() throws {
        let longPrompt = String(repeating: "x", count: 100)
        let json: [String: Any] = [
            "cron": "0 9 * * *",
            "prompt": longPrompt,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let job = try ClaudeImporter.toHeartbeatJob(from: data)
        #expect(job.name.count <= 53) // 50 + "..."
    }

    @Test("Parses array of scheduled tasks")
    func parseArray() throws {
        let tasks: [[String: Any]] = [
            ["cron": "*/5 * * * *", "prompt": "Task 1"],
            ["cron": "0 9 * * *", "prompt": "Task 2"],
        ]
        let data = try JSONSerialization.data(withJSONObject: tasks)
        let jobs = try ClaudeImporter.parseScheduledTasks(from: data)
        #expect(jobs.count == 2)
        #expect(jobs[0].schedule == "*/5 * * * *")
        #expect(jobs[1].schedule == "0 9 * * *")
    }
}
