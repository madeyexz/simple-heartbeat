import Testing
import Foundation
@testable import HeartbeatCore

@Suite("CronExpression")
struct CronExpressionTests {

    // MARK: - Parsing

    @Test("Parses valid 5-field expression")
    func parseValid() {
        let cron = CronExpression(from: "*/5 * * * *")
        #expect(cron != nil)
    }

    @Test("Rejects invalid expressions", arguments: [
        "", "* *", "* * * *", "* * * * * *", "abc * * * *", "60 * * * *",
    ])
    func parseInvalid(expr: String) {
        #expect(CronExpression(from: expr) == nil)
    }

    @Test("Handles whitespace trimming")
    func parseWhitespace() {
        #expect(CronExpression(from: "  */10  *  *  *  *  ") != nil)
    }

    // MARK: - Matching

    @Test("Every-minute matches any time")
    func everyMinute() {
        let cron = CronExpression(from: "* * * * *")!
        // Should match any date
        #expect(cron.matches(date: Date()))
        #expect(cron.matches(date: makeDate(2026, 3, 25, 14, 30)))
    }

    @Test("Specific minute matches correctly")
    func specificMinute() {
        let cron = CronExpression(from: "30 * * * *")!
        #expect(cron.matches(date: makeDate(2026, 3, 25, 14, 30)))
        #expect(!cron.matches(date: makeDate(2026, 3, 25, 14, 29)))
    }

    @Test("Step expression */5 matches multiples of 5")
    func stepExpression() {
        let cron = CronExpression(from: "*/5 * * * *")!
        #expect(cron.matches(date: makeDate(2026, 3, 25, 14, 0)))
        #expect(cron.matches(date: makeDate(2026, 3, 25, 14, 15)))
        #expect(cron.matches(date: makeDate(2026, 3, 25, 14, 55)))
        #expect(!cron.matches(date: makeDate(2026, 3, 25, 14, 3)))
    }

    @Test("Daily at specific time")
    func dailyAt() {
        let cron = CronExpression(from: "0 9 * * *")!
        #expect(cron.matches(date: makeDate(2026, 3, 25, 9, 0)))
        #expect(!cron.matches(date: makeDate(2026, 3, 25, 9, 1)))
        #expect(!cron.matches(date: makeDate(2026, 3, 25, 10, 0)))
    }

    @Test("Range expression 1-5 matches correctly")
    func rangeExpression() {
        let cron = CronExpression(from: "* 9-17 * * *")!
        #expect(cron.matches(date: makeDate(2026, 3, 25, 9, 0)))
        #expect(cron.matches(date: makeDate(2026, 3, 25, 17, 30)))
        #expect(!cron.matches(date: makeDate(2026, 3, 25, 8, 59)))
        #expect(!cron.matches(date: makeDate(2026, 3, 25, 18, 0)))
    }

    @Test("List expression 1,15,30 matches correctly")
    func listExpression() {
        let cron = CronExpression(from: "1,15,30 * * * *")!
        #expect(cron.matches(date: makeDate(2026, 3, 25, 14, 1)))
        #expect(cron.matches(date: makeDate(2026, 3, 25, 14, 15)))
        #expect(cron.matches(date: makeDate(2026, 3, 25, 14, 30)))
        #expect(!cron.matches(date: makeDate(2026, 3, 25, 14, 2)))
    }

    @Test("Weekday matching (Monday=1)")
    func weekday() {
        // 2026-03-25 is a Wednesday (weekday=3 in cron, 4 in Calendar)
        let wed = CronExpression(from: "0 9 * * 3")!
        #expect(wed.matches(date: makeDate(2026, 3, 25, 9, 0)))
        // Thursday should not match
        #expect(!wed.matches(date: makeDate(2026, 3, 26, 9, 0)))
    }

    @Test("Sunday is weekday 0")
    func sunday() {
        // 2026-03-29 is a Sunday
        let sun = CronExpression(from: "0 0 * * 0")!
        #expect(sun.matches(date: makeDate(2026, 3, 29, 0, 0)))
        #expect(!sun.matches(date: makeDate(2026, 3, 28, 0, 0))) // Saturday
    }

    // MARK: - Human readable

    @Test("Human readable descriptions", arguments: [
        ("* * * * *", "Every minute"),
        ("*/5 * * * *", "Every 5 min"),
        ("*/30 * * * *", "Every 30 min"),
        ("0 * * * *", "Hourly at :00"),
        ("30 * * * *", "Hourly at :30"),
        ("0 9 * * *", "Daily at 09:00"),
        ("30 14 * * *", "Daily at 14:30"),
        ("0 9 * * 1", "Mon at 09:00"),
    ])
    func humanReadable(expr: String, expected: String) {
        let cron = CronExpression(from: expr)!
        #expect(cron.humanReadable == expected)
    }

    // MARK: - Helpers

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        c.timeZone = TimeZone.current
        return Calendar.current.date(from: c)!
    }
}
