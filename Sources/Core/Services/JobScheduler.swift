import Foundation
import Combine

@MainActor
public final class JobScheduler: ObservableObject {
    @Published public var runningJobs: Set<UUID> = []

    private var timer: Timer?
    private weak var store: JobStore?

    public init() {}

    public func start(store: JobStore) {
        self.store = store
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let store else { return }
        let now = Date()
        for job in store.jobs where job.isEnabled && !runningJobs.contains(job.id) {
            if let cron = CronExpression(from: job.schedule), cron.matches(date: now) {
                runJob(job)
            }
        }
    }

    /// Run a job — spawns in a background tmux/cmux session when available,
    /// falls back to direct process execution.
    public func runJob(_ job: HeartbeatJob) {
        guard let store, !runningJobs.contains(job.id) else { return }
        guard let agent = AgentRegistry.shared.agent(for: job.agentId) else { return }

        var run = JobRun(
            jobId: job.id,
            startedAt: Date(),
            output: "",
            error: "",
            status: .running
        )
        store.addRun(run)
        runningJobs.insert(job.id)

        let runner = TerminalLauncher.bestBackgroundRunner

        Task {
            if runner == .tmux || runner == .cmux {
                // Run inside a background terminal session
                do {
                    try await TerminalLauncher.runInBackground(job: job, agent: agent)
                    run.output = "Running in \(runner.displayName) session: \(TerminalLauncher.sessionName(for: job))"
                    run.status = .running

                    // Poll tmux session status until it exits
                    if runner == .tmux {
                        await pollTmuxSession(job: job, run: &run, store: store)
                    } else {
                        // cmux: we can't easily poll, mark as success after launch
                        run.finishedAt = Date()
                        run.status = .success
                    }
                } catch {
                    run.finishedAt = Date()
                    run.error = error.localizedDescription
                    run.status = .failure
                    run.exitCode = -1
                }
            } else {
                // Fallback: direct process execution (no session to attach to)
                let command = agent.buildCommand(
                    prompt: job.prompt, options: job.options, workingDirectory: job.workingDirectory
                )
                do {
                    let result = try await ProcessRunner.run(
                        executable: command.executable,
                        arguments: command.arguments,
                        workingDirectory: job.workingDirectory
                    )
                    run.finishedAt = Date()
                    run.output = result.stdout
                    run.error = result.stderr
                    run.exitCode = result.exitCode
                    run.status = result.exitCode == 0 ? .success : .failure
                } catch {
                    run.finishedAt = Date()
                    run.error = error.localizedDescription
                    run.status = .failure
                    run.exitCode = -1
                }
            }

            store.updateRun(run)
            runningJobs.remove(job.id)
        }
    }

    /// Poll a tmux session every 5s until it exits.
    private func pollTmuxSession(job: HeartbeatJob, run: inout JobRun, store: JobStore) async {
        let session = TerminalLauncher.sessionName(for: job)

        while true {
            try? await Task.sleep(for: .seconds(5))
            if !TerminalLauncher.hasSession(for: job) {
                // Session ended — capture any remaining output
                run.finishedAt = Date()
                run.status = .success
                run.output = "Session '\(session)' completed"
                break
            }
        }
    }
}
