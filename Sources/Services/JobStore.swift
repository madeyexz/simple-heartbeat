import Foundation
import SwiftUI

@MainActor
final class JobStore: ObservableObject {
    @Published var jobs: [HeartbeatJob] = []
    @Published var runs: [JobRun] = []

    private let jobsURL: URL
    private let runsURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("SimpleHeartbeat")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        jobsURL = dir.appendingPathComponent("jobs.json")
        runsURL = dir.appendingPathComponent("runs.json")
        load()
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: jobsURL),
           let decoded = try? decoder.decode([HeartbeatJob].self, from: data)
        {
            jobs = decoded
        }
        if let data = try? Data(contentsOf: runsURL),
           let decoded = try? decoder.decode([JobRun].self, from: data)
        {
            runs = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(jobs) {
            try? data.write(to: jobsURL, options: .atomic)
        }
        if let data = try? encoder.encode(runs) {
            try? data.write(to: runsURL, options: .atomic)
        }
    }

    func add(_ job: HeartbeatJob) {
        jobs.append(job)
        save()
    }

    func update(_ job: HeartbeatJob) {
        if let i = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[i] = job
            save()
        }
    }

    func delete(_ job: HeartbeatJob) {
        jobs.removeAll { $0.id == job.id }
        runs.removeAll { $0.jobId == job.id }
        save()
    }

    func toggleEnabled(_ job: HeartbeatJob) {
        if let i = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[i].isEnabled.toggle()
            save()
        }
    }

    func addRun(_ run: JobRun) {
        runs.append(run)
        if runs.count > 100 { runs = Array(runs.suffix(100)) }
        save()
    }

    func updateRun(_ run: JobRun) {
        if let i = runs.firstIndex(where: { $0.id == run.id }) {
            runs[i] = run
            save()
        }
    }

    func runsForJob(_ jobId: UUID) -> [JobRun] {
        runs.filter { $0.jobId == jobId }.sorted { $0.startedAt > $1.startedAt }
    }
}
