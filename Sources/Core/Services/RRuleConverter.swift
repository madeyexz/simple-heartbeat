import Foundation

public enum RRuleError: Error, CustomStringConvertible {
    case empty
    case missingFrequency
    case unsupportedFrequency(String)
    case invalidComponent(String)

    public var description: String {
        switch self {
        case .empty: "RRULE string is empty"
        case .missingFrequency: "RRULE missing FREQ component"
        case .unsupportedFrequency(let f): "Unsupported RRULE frequency: \(f)"
        case .invalidComponent(let c): "Invalid RRULE component: \(c)"
        }
    }
}

/// Converts iCalendar RRULE strings (RFC 5545) to 5-field cron expressions.
public enum RRuleConverter {

    private static let dayMap: [String: Int] = [
        "SU": 0, "MO": 1, "TU": 2, "WE": 3, "TH": 4, "FR": 5, "SA": 6,
    ]

    public static func toCron(_ rrule: String) throws -> String {
        let trimmed = rrule.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw RRuleError.empty }

        var parts: [String: String] = [:]
        for component in trimmed.split(separator: ";") {
            let kv = component.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { throw RRuleError.invalidComponent(String(component)) }
            parts[String(kv[0])] = String(kv[1])
        }

        guard let freq = parts["FREQ"] else { throw RRuleError.missingFrequency }

        let interval = Int(parts["INTERVAL"] ?? "1") ?? 1
        let byMinute = parts["BYMINUTE"]
        let byHour = parts["BYHOUR"]
        let byDay = parts["BYDAY"]

        switch freq {
        case "MINUTELY":
            let min = interval == 1 ? "*" : "*/\(interval)"
            return "\(min) * * * *"

        case "HOURLY":
            let minute = byMinute ?? "0"
            let hour = interval == 1 ? "*" : "*/\(interval)"
            return "\(minute) \(hour) * * *"

        case "DAILY":
            let minute = byMinute ?? "0"
            let hour = byHour ?? "0"
            return "\(minute) \(hour) * * *"

        case "WEEKLY":
            let minute = byMinute ?? "0"
            let hour = byHour ?? "0"

            guard let dayStr = byDay else {
                // No BYDAY = every day of the week
                return "\(minute) \(hour) * * *"
            }

            let days = dayStr.split(separator: ",").compactMap { dayMap[String($0)] }.sorted()

            // All 7 days = every day
            if days.count == 7 {
                return "\(minute) \(hour) * * *"
            }

            let dowField = days.map(String.init).joined(separator: ",")
            return "\(minute) \(hour) * * \(dowField)"

        default:
            throw RRuleError.unsupportedFrequency(freq)
        }
    }
}
