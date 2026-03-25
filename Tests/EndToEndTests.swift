import Testing
import Foundation
@testable import HeartbeatCore

/// End-to-end tests that exercise the full pipeline:
/// job creation → storage → command building → tmux session → completion.
/// These tests spawn real tmux sessions with simple commands.
@Suite("End-to-end", .serialized)
struct EndToEndTests {

    // MARK: - Full lifecycle: create → store → run → complete

    @Test("Job round-trips through store and persists to disk")
    func jobPersistence() async throws {
        let store = await JobStore(directory: tempDir())
        let job = HeartbeatJob(
            name: "E2E Persist",
            schedule: "*/5 * * * *",
            agentId: "claude",
            prompt: "test prompt",
            workingDirectory: "/tmp",
            options: ["model": "sonnet"]
        )

        await store.add(job)
        #expect(await store.jobs.count == 1)

        // Reload from disk
        let store2 = await JobStore(directory: await store.directory)
        #expect(await store2.jobs.count == 1)
        let loaded = await store2.jobs[0]
        #expect(loaded.name == "E2E Persist")
        #expect(loaded.agentId == "claude")
        #expect(loaded.options["model"] == "sonnet")
        #expect(loaded.schedule == "*/5 * * * *")
    }

    @Test("Cron match triggers job selection")
    func cronMatchTriggersJob() throws {
        // Build a cron that matches right now
        let now = Date()
        let cal = Calendar.current
        let min = cal.component(.minute, from: now)
        let hr = cal.component(.hour, from: now)
        let cron = CronExpression(from: "\(min) \(hr) * * *")!
        #expect(cron.matches(date: now))

        // A minute ago should NOT match (different minute)
        let past = cal.date(byAdding: .minute, value: -1, to: now)!
        // Only fails if we crossed a minute boundary
        if cal.component(.minute, from: past) != min {
            #expect(!cron.matches(date: past))
        }
    }

    @Test("Agent command builds correct CLI string for Claude")
    func claudeCommandBuild() {
        let job = HeartbeatJob(
            name: "E2E Claude",
            schedule: "0 9 * * *",
            agentId: "claude",
            prompt: "review all open PRs",
            workingDirectory: "/tmp/project",
            options: ["model": "opus", "effort": "max", "max-budget-usd": "5"]
        )
        let agent = ClaudeAgent()
        let cmd = agent.buildCommand(
            prompt: job.prompt, options: job.options, workingDirectory: job.workingDirectory
        )

        #expect(cmd.executable == "claude")
        #expect(cmd.arguments.contains("--print"))
        #expect(cmd.arguments.contains("--model"))
        #expect(cmd.arguments.contains("opus"))
        #expect(cmd.arguments.contains("--effort"))
        #expect(cmd.arguments.contains("max"))
        #expect(cmd.arguments.contains("--max-budget-usd"))
        #expect(cmd.arguments.contains("5"))
        #expect(cmd.arguments.last == "review all open PRs")

        // Shell string should be well-formed
        let shell = TerminalLauncher.shellString(from: cmd)
        #expect(shell.hasPrefix("claude"))
        #expect(shell.contains("'review all open PRs'"))
    }

    @Test("Agent command builds correct CLI string for Codex")
    func codexCommandBuild() {
        let job = HeartbeatJob(
            name: "E2E Codex",
            schedule: "0 9 * * *",
            agentId: "codex",
            prompt: "fix all lint errors",
            workingDirectory: "/tmp/project",
            options: ["model": "o3", "reasoning-effort": "high", "approval": "never", "sandbox": "workspace-write"]
        )
        let agent = CodexAgent()
        let cmd = agent.buildCommand(
            prompt: job.prompt, options: job.options, workingDirectory: job.workingDirectory
        )

        #expect(cmd.executable == "codex")
        #expect(cmd.arguments.first == "exec")
        #expect(cmd.arguments.contains("-m"))
        #expect(cmd.arguments.contains("o3"))
        #expect(cmd.arguments.contains("-c"))
        #expect(cmd.arguments.contains("-a"))
        #expect(cmd.arguments.contains("never"))
        #expect(cmd.arguments.contains("-s"))
        #expect(cmd.arguments.contains("workspace-write"))
        #expect(cmd.arguments.last == "fix all lint errors")
    }

    // MARK: - tmux session lifecycle

    @Test("Spawns a tmux session, verifies it exists, waits for exit")
    func tmuxSessionLifecycle() async throws {
        try skipIfNoTmux()

        let job = HeartbeatJob(
            name: "E2E tmux test",
            schedule: "* * * * *",
            agentId: "claude",
            prompt: "test",
            workingDirectory: "/tmp"
        )
        let session = TerminalLauncher.sessionName(for: job)

        // Clean up any stale session
        killTmuxSession(session)

        // Spawn a short-lived command in a tmux session
        let result = try await ProcessRunner.run(
            executable: "tmux",
            arguments: [
                "new-session", "-d",
                "-s", session,
                "-c", "/tmp",
                "echo 'heartbeat e2e' && sleep 2",
            ],
            workingDirectory: "/tmp"
        )
        #expect(result.exitCode == 0)

        // Session should exist now
        #expect(tmuxSessionExists(session))
        #expect(TerminalLauncher.hasSession(for: job))

        // Wait for the command to finish (sleep 2 + buffer)
        try await Task.sleep(for: .seconds(5))

        // Session should be gone after the command exited
        // (if remain-on-exit is set in user's tmux.conf, force kill)
        if tmuxSessionExists(session) {
            killTmuxSession(session)
        }
        #expect(!tmuxSessionExists(session))
    }

    @Test("Captures tmux session output via capture-pane")
    func tmuxCaptureOutput() async throws {
        try skipIfNoTmux()

        let session = "hb-e2e-capture-\(UUID().uuidString.prefix(6))"

        // Spawn a session that echoes something and stays alive briefly
        let _ = try await ProcessRunner.run(
            executable: "tmux",
            arguments: [
                "new-session", "-d",
                "-s", session,
                "echo 'HEARTBEAT_E2E_OUTPUT' && sleep 5",
            ],
            workingDirectory: "/tmp"
        )

        // Give it a moment to produce output
        try await Task.sleep(for: .seconds(1))

        // Capture the pane content
        let capture = try await ProcessRunner.run(
            executable: "tmux",
            arguments: ["capture-pane", "-t", session, "-p"],
            workingDirectory: "/tmp"
        )
        #expect(capture.stdout.contains("HEARTBEAT_E2E_OUTPUT"))

        // Cleanup
        killTmuxSession(session)
    }

    // MARK: - Import → Run pipeline

    @Test("Codex import pipeline: TOML → RRULE → cron → HeartbeatJob → command")
    func codexImportPipeline() throws {
        // Simulate a real Codex automation.toml
        let tomlContent = """
        version = 1
        id = "e2e-test-auto"
        name = "E2E Test Automation"
        prompt = "run the test suite and report failures"
        status = "ACTIVE"
        rrule = "FREQ=WEEKLY;BYDAY=MO,WE,FR;BYHOUR=10;BYMINUTE=30"
        model = "gpt-5.4"
        reasoning_effort = "high"
        cwds = ["/Users/test/project"]
        """

        // Step 1: Parse TOML
        let parsed = SimpleTOML.parse(tomlContent)
        #expect(parsed["name"] == "E2E Test Automation")
        #expect(parsed["rrule"] == "FREQ=WEEKLY;BYDAY=MO,WE,FR;BYHOUR=10;BYMINUTE=30")

        // Step 2: Convert to HeartbeatJob (includes RRULE→cron)
        let job = try CodexImporter.toHeartbeatJob(from: parsed)
        #expect(job.name == "E2E Test Automation")
        #expect(job.schedule == "30 10 * * 1,3,5")
        #expect(job.agentId == "codex")
        #expect(job.options["model"] == "gpt-5.4")
        #expect(job.isEnabled == true)

        // Step 3: Verify cron expression is valid and matches correct days
        // Cron: 30 10 * * 1,3,5 = Mon/Wed/Fri at 10:30
        let cron = CronExpression(from: job.schedule)!
        #expect(cron.matches(date: makeDate(2026, 3, 25, 10, 30))) // Wed at 10:30 — should match
        #expect(!cron.matches(date: makeDate(2026, 3, 24, 10, 30))) // Tue at 10:30 — should NOT match
        #expect(!cron.matches(date: makeDate(2026, 3, 25, 11, 30))) // Wed at 11:30 — wrong hour

        // Step 4: Build the CLI command
        let agent = CodexAgent()
        let cmd = agent.buildCommand(
            prompt: job.prompt, options: job.options, workingDirectory: job.workingDirectory
        )
        #expect(cmd.executable == "codex")
        #expect(cmd.arguments.contains("gpt-5.4"))

        // Step 5: Verify shell string is well-formed
        let shell = TerminalLauncher.shellString(from: cmd)
        #expect(shell.hasPrefix("codex exec"))
        #expect(shell.contains("gpt-5.4"))

        // Step 6: Verify tmux session name is valid
        let session = TerminalLauncher.sessionName(for: job)
        #expect(session.hasPrefix("hb-"))
        #expect(!session.contains(" "))
    }

    @Test("Run log records job execution")
    func runLogRecording() async throws {
        let store = await JobStore(directory: tempDir())
        let job = HeartbeatJob(
            name: "E2E RunLog",
            schedule: "* * * * *",
            agentId: "claude",
            prompt: "test",
            workingDirectory: "/tmp"
        )
        await store.add(job)

        // Simulate a run
        var run = JobRun(
            jobId: job.id,
            startedAt: Date(),
            output: "",
            error: "",
            status: .running
        )
        await store.addRun(run)
        #expect(await store.runs.count == 1)

        // Complete the run
        run.finishedAt = Date()
        run.output = "All tests passed"
        run.exitCode = 0
        run.status = .success
        await store.updateRun(run)

        let runs = await store.runsForJob(job.id)
        #expect(runs.count == 1)
        #expect(runs[0].status == .success)
        #expect(runs[0].output == "All tests passed")
        #expect(runs[0].exitCode == 0)
    }

    // MARK: - Helpers

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("heartbeat-e2e-\(UUID().uuidString.prefix(8))")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func skipIfNoTmux() throws {
        if ProcessRunner.findExecutable("tmux") == nil {
            throw SkipError()
        }
    }

    private func tmuxSessionExists(_ name: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ProcessRunner.findExecutable("tmux")!)
        proc.arguments = ["has-session", "-t", name]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }

    private func killTmuxSession(_ name: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ProcessRunner.findExecutable("tmux") ?? "/usr/bin/true")
        proc.arguments = ["kill-session", "-t", name]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
    }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        c.timeZone = TimeZone.current
        return Calendar.current.date(from: c)!
    }

    struct SkipError: Error {}
}
