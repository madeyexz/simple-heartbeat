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
        // Fire every 60s, aligned to the top of the minute
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

    public func runJob(_ job: HeartbeatJob) {
        guard let store, !runningJobs.contains(job.id) else { return }
        guard let agent = AgentRegistry.shared.agent(for: job.agentId) else { return }

        let command = agent.buildCommand(
            prompt: job.prompt,
            options: job.options,
            workingDirectory: job.workingDirectory
        )

        var run = JobRun(
            jobId: job.id,
            startedAt: Date(),
            output: "",
            error: "",
            status: .running
        )
        store.addRun(run)
        runningJobs.insert(job.id)

        Task {
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
            store.updateRun(run)
            runningJobs.remove(job.id)
        }
    }
}
