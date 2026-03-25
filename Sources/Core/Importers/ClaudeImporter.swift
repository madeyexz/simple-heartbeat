import Foundation

/// Imports scheduled tasks from Claude Code (.claude/scheduled_tasks.json)
public enum ClaudeImporter {

    /// Common locations to search for Claude scheduled tasks.
    public static func scheduledTasksPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.claude/scheduled_tasks.json",
            ".claude/scheduled_tasks.json",
        ]
    }

    /// Discover Claude scheduled tasks from known paths.
    public static func discover() -> [HeartbeatJob] {
        for path in scheduledTasksPaths() {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                if let jobs = try? parseScheduledTasks(from: data) {
                    return jobs
                }
            }
        }
        return []
    }

    /// Parse an array of scheduled tasks from JSON data.
    public static func parseScheduledTasks(from data: Data) throws -> [HeartbeatJob] {
        // Try as array first
        if let tasks = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return tasks.compactMap { dict in
                let taskData = try? JSONSerialization.data(withJSONObject: dict)
                return taskData.flatMap { try? toHeartbeatJob(from: $0) }
            }
        }
        // Try as single object
        if let _ = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return [try toHeartbeatJob(from: data)]
        }
        throw ImportError.invalidData("Expected JSON array or object")
    }

    /// Convert a single Claude scheduled task JSON to HeartbeatJob.
    public static func toHeartbeatJob(from data: Data) throws -> HeartbeatJob {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidData("Invalid JSON")
        }

        guard let prompt = dict["prompt"] as? String, !prompt.isEmpty else {
            throw ImportError.missingField("prompt")
        }
        guard let cron = dict["cron"] as? String, !cron.isEmpty else {
            throw ImportError.missingField("cron")
        }

        let name = truncate(prompt, to: 50)

        return HeartbeatJob(
            name: name,
            schedule: cron,
            agentId: "claude",
            prompt: prompt,
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            isEnabled: true
        )
    }

    private static func truncate(_ s: String, to n: Int) -> String {
        s.count <= n ? s : String(s.prefix(n)) + "..."
    }
}
