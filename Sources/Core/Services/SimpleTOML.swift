import Foundation

/// Minimal TOML parser for flat key-value files (no nested tables).
/// Sufficient for parsing Codex automation.toml files.
public enum SimpleTOML {

    /// Parse a TOML string into a flat [String: String] dictionary.
    /// Arrays are flattened to their first element.
    public static func parse(_ content: String) -> [String: String] {
        var result: [String: String] = [:]

        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Split on first '='
            guard let eqIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[trimmed.startIndex..<eqIndex].trimmingCharacters(in: .whitespaces)
            let rawValue = trimmed[trimmed.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)

            guard !key.isEmpty else { continue }

            result[key] = parseValue(rawValue)
        }

        return result
    }

    private static func parseValue(_ raw: String) -> String {
        // Quoted string: "..."
        if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
            let inner = String(raw.dropFirst().dropLast())
            // Handle common escape sequences
            return inner
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }

        // Array: ["...", "..."]
        if raw.hasPrefix("[") && raw.hasSuffix("]") {
            let inner = String(raw.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            // Extract first quoted element
            let elements = inner.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if let first = elements.first {
                // Strip quotes from element
                if first.hasPrefix("\"") && first.hasSuffix("\"") && first.count >= 2 {
                    return String(first.dropFirst().dropLast())
                }
                return first
            }
            return ""
        }

        // Bare value (integer, boolean, etc.)
        return raw
    }
}
