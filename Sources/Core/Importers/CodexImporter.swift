import Foundation

/// Imports automations from Codex CLI (~/.codex/automations/*/automation.toml)
public enum CodexImporter {

    public static let automationsDir: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.codex/automations"
    }()

    /// Discover all Codex automations on disk.
    public static func discover() -> [HeartbeatJob] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: automationsDir) else {
            return []
        }

        return entries.compactMap { entry in
            let tomlPath = "\(automationsDir)/\(entry)/automation.toml"
            guard let content = try? String(contentsOfFile: tomlPath, encoding: .utf8) else {
                return nil
            }
            let parsed = SimpleTOML.parse(content)
            return try? toHeartbeatJob(from: parsed)
        }
    }

    /// Convert a parsed TOML dictionary to a HeartbeatJob.
    public static func toHeartbeatJob(from toml: [String: String]) throws -> HeartbeatJob {
        guard let prompt = toml["prompt"], !prompt.isEmpty else {
            throw ImportError.missingField("prompt")
        }
        guard let rrule = toml["rrule"], !rrule.isEmpty else {
            throw ImportError.missingField("rrule")
        }

        let name = toml["name"] ?? toml["id"] ?? truncate(prompt, to: 50)
        let cron = try RRuleConverter.toCron(rrule)
        let workingDir = toml["cwds"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        let isActive = toml["status"]?.uppercased() != "PAUSED"

        var options: [String: String] = [:]
        if let model = toml["model"], !model.isEmpty {
            options["model"] = model
        }
        if let effort = toml["reasoning_effort"], !effort.isEmpty {
            options["reasoning_effort"] = effort
        }

        return HeartbeatJob(
            name: name,
            schedule: cron,
            agentId: "codex",
            prompt: prompt,
            workingDirectory: workingDir,
            options: options,
            isEnabled: isActive
        )
    }

    private static func truncate(_ s: String, to n: Int) -> String {
        s.count <= n ? s : String(s.prefix(n)) + "..."
    }
}
