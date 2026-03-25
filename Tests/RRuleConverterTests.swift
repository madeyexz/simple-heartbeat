import Testing
import Foundation
@testable import HeartbeatCore

@Suite("RRuleConverter")
struct RRuleConverterTests {

    // MARK: - Basic frequency conversions

    @Test("Daily at specific time")
    func dailyAt() throws {
        // FREQ=DAILY with BYHOUR and BYMINUTE
        let cron = try RRuleConverter.toCron("FREQ=DAILY;BYHOUR=9;BYMINUTE=0")
        #expect(cron == "0 9 * * *")
    }

    @Test("Weekly all days = daily")
    func weeklyAllDays() throws {
        // BYDAY with all 7 days is effectively daily
        let cron = try RRuleConverter.toCron(
            "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU;BYHOUR=9;BYMINUTE=0"
        )
        #expect(cron == "0 9 * * *")
    }

    @Test("Weekly specific days")
    func weeklySpecificDays() throws {
        let cron = try RRuleConverter.toCron(
            "FREQ=WEEKLY;BYDAY=MO,WE,FR;BYHOUR=14;BYMINUTE=30"
        )
        #expect(cron == "30 14 * * 1,3,5")
    }

    @Test("Weekdays only (Mon-Fri)")
    func weekdays() throws {
        let cron = try RRuleConverter.toCron(
            "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=8;BYMINUTE=0"
        )
        #expect(cron == "0 8 * * 1,2,3,4,5")
    }

    @Test("Weekly single day")
    func weeklySingleDay() throws {
        let cron = try RRuleConverter.toCron(
            "FREQ=WEEKLY;BYDAY=MO;BYHOUR=9;BYMINUTE=0"
        )
        #expect(cron == "0 9 * * 1")
    }

    @Test("Hourly with interval")
    func hourlyInterval() throws {
        let cron = try RRuleConverter.toCron("FREQ=HOURLY;INTERVAL=2;BYMINUTE=0")
        #expect(cron == "0 */2 * * *")
    }

    @Test("Hourly default (every hour)")
    func hourlyDefault() throws {
        let cron = try RRuleConverter.toCron("FREQ=HOURLY;BYMINUTE=0")
        #expect(cron == "0 * * * *")
    }

    @Test("Minutely with interval")
    func minutelyInterval() throws {
        let cron = try RRuleConverter.toCron("FREQ=MINUTELY;INTERVAL=30")
        #expect(cron == "*/30 * * * *")
    }

    @Test("Minutely default (every minute)")
    func minutelyDefault() throws {
        let cron = try RRuleConverter.toCron("FREQ=MINUTELY")
        #expect(cron == "* * * * *")
    }

    // MARK: - Day name mapping

    @Test("Sunday maps to cron 0")
    func sundayMapping() throws {
        let cron = try RRuleConverter.toCron(
            "FREQ=WEEKLY;BYDAY=SU;BYHOUR=10;BYMINUTE=0"
        )
        #expect(cron == "0 10 * * 0")
    }

    @Test("Saturday maps to cron 6")
    func saturdayMapping() throws {
        let cron = try RRuleConverter.toCron(
            "FREQ=WEEKLY;BYDAY=SA;BYHOUR=10;BYMINUTE=0"
        )
        #expect(cron == "0 10 * * 6")
    }

    // MARK: - Real-world Codex RRULE

    @Test("Real Codex automation RRULE")
    func realCodexRrule() throws {
        // From the user's actual tiktok-growth-loop automation
        let cron = try RRuleConverter.toCron(
            "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU;BYHOUR=9;BYMINUTE=0"
        )
        #expect(cron == "0 9 * * *")
        // Verify it parses as a valid CronExpression
        #expect(CronExpression(from: cron) != nil)
    }

    // MARK: - Error cases

    @Test("Empty string throws")
    func emptyThrows() {
        #expect(throws: RRuleError.self) {
            try RRuleConverter.toCron("")
        }
    }

    @Test("Missing FREQ throws")
    func missingFreqThrows() {
        #expect(throws: RRuleError.self) {
            try RRuleConverter.toCron("BYHOUR=9;BYMINUTE=0")
        }
    }

    @Test("Unsupported FREQ throws")
    func unsupportedFreqThrows() {
        #expect(throws: RRuleError.self) {
            try RRuleConverter.toCron("FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1")
        }
    }
}
