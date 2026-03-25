import Foundation

struct CronExpression {
    let minute: CronField
    let hour: CronField
    let dayOfMonth: CronField
    let month: CronField
    let dayOfWeek: CronField

    init?(from string: String) {
        let parts = string.trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard parts.count == 5 else { return nil }

        guard let m = CronField(String(parts[0]), range: 0...59),
              let h = CronField(String(parts[1]), range: 0...23),
              let dom = CronField(String(parts[2]), range: 1...31),
              let mo = CronField(String(parts[3]), range: 1...12),
              let dow = CronField(String(parts[4]), range: 0...6)
        else { return nil }

        minute = m; hour = h; dayOfMonth = dom; month = mo; dayOfWeek = dow
    }

    func matches(date: Date) -> Bool {
        let cal = Calendar.current
        let c = cal.dateComponents([.minute, .hour, .day, .month, .weekday], from: date)
        guard let min = c.minute, let hr = c.hour,
              let day = c.day, let mon = c.month, let wd = c.weekday
        else { return false }
        // Calendar weekday: Sunday=1..Saturday=7 → cron: Sunday=0..Saturday=6
        let cronWeekday = wd - 1
        return minute.matches(min) && hour.matches(hr)
            && dayOfMonth.matches(day) && month.matches(mon)
            && dayOfWeek.matches(cronWeekday)
    }

    var humanReadable: String {
        let p = [minute.raw, hour.raw, dayOfMonth.raw, month.raw, dayOfWeek.raw]

        if p.allSatisfy({ $0 == "*" }) { return "Every minute" }

        if p[0].hasPrefix("*/"), p[1...4].allSatisfy({ $0 == "*" }),
           let n = Int(p[0].dropFirst(2))
        {
            return "Every \(n) min"
        }

        if p[1].hasPrefix("*/"), p[0] == "0", p[2...4].allSatisfy({ $0 == "*" }),
           let n = Int(p[1].dropFirst(2))
        {
            return "Every \(n) hours"
        }

        if p[1...4].allSatisfy({ $0 == "*" }), let m = Int(p[0]) {
            return "Hourly at :\(String(format: "%02d", m))"
        }

        if p[2...4].allSatisfy({ $0 == "*" }),
           let h = Int(p[1]), let m = Int(p[0])
        {
            return "Daily at \(String(format: "%02d:%02d", h, m))"
        }

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        if p[2] == "*", p[3] == "*", let dow = Int(p[4]), dow >= 0, dow <= 6,
           let h = Int(p[1]), let m = Int(p[0])
        {
            return "\(dayNames[dow]) at \(String(format: "%02d:%02d", h, m))"
        }

        return p.joined(separator: " ")
    }
}

struct CronField {
    let values: Set<Int>
    let raw: String

    init?(_ string: String, range: ClosedRange<Int>) {
        raw = string
        var result = Set<Int>()
        for part in string.split(separator: ",") {
            let s = String(part)
            if s == "*" {
                result.formUnion(range)
            } else if s.hasPrefix("*/") {
                guard let step = Int(s.dropFirst(2)), step > 0 else { return nil }
                for v in stride(from: range.lowerBound, through: range.upperBound, by: step) {
                    result.insert(v)
                }
            } else if s.contains("-") {
                let bounds = s.split(separator: "-")
                guard bounds.count == 2,
                      let lo = Int(bounds[0]), let hi = Int(bounds[1]),
                      lo <= hi
                else { return nil }
                result.formUnion(lo...hi)
            } else if let v = Int(s) {
                result.insert(v)
            } else {
                return nil
            }
        }
        values = result
    }

    func matches(_ value: Int) -> Bool {
        values.contains(value)
    }
}
