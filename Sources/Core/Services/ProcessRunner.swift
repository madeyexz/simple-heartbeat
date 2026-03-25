import Foundation

public struct ProcessResult {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public enum ProcessRunner {
    public static func findExecutable(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (path?.isEmpty == false) ? path : nil
    }

    /// Resolve the user's full login shell PATH so we can find CLI tools like `claude` and `codex`.
    /// Cached after first resolution since PATH doesn't change during the app's lifetime.
    private static let resolvedShellPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let userPaths = "\(home)/.local/bin:\(home)/.cargo/bin"
        let fallback = "\(userPaths):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shell)
        proc.arguments = ["-l", "-c", "echo $PATH"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let resolved = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !resolved.isEmpty
            {
                // Prepend user paths in case they're missing from shell config
                return "\(userPaths):\(resolved)"
            }
        } catch {}
        return fallback
    }()

    public static func run(
        executable: String,
        arguments: [String],
        workingDirectory: String
    ) async throws -> ProcessResult {
        try await Task.detached {
            guard let execPath = findExecutable(executable) ?? {
                // Fallback: try resolving via login shell PATH
                let shellPath = resolvedShellPath
                for dir in shellPath.split(separator: ":") {
                    let candidate = "\(dir)/\(executable)"
                    if FileManager.default.isExecutableFile(atPath: candidate) {
                        return candidate
                    }
                }
                return nil
            }() else {
                return ProcessResult(
                    stdout: "",
                    stderr: "Executable '\(executable)' not found in PATH",
                    exitCode: -1
                )
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

            // Inherit environment with augmented PATH
            var env = ProcessInfo.processInfo.environment
            let shellPath = resolvedShellPath
            env["PATH"] = shellPath
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try process.run()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return ProcessResult(
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                exitCode: process.terminationStatus
            )
        }.value
    }
}
