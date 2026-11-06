import Foundation
import Testing
@testable import LumaReader

struct ReadingStatisticsTests {
    private var calendar: Calendar {
        var c = Calendar(identifier:.gregorian)
        c.timeZone = TimeZone(identifier:"America/Vancouver")!
        c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4
        return c
    }
    private func date(_ y: Int,_ m: Int,_ d: Int,_ h: Int = 0,_ min: Int = 0) -> Date {
        calendar.date(from:DateComponents(year:y,month:m,day:d,hour:h,minute:min))!
    }
    @Test func sessionIsSplitAcrossLocalMidnight() {
        var ledger = ReadingLedger()
        ledger.record(start:date(2026,11,4,23,50),seconds:20*60,calendar:calendar)
        #expect(ledger.dailySeconds["2026-11-04"] == 600)
        #expect(ledger.dailySeconds["2026-11-05"] == 600)
    }
    @Test func repeatedSessionsAccumulateWithoutFakeHistory() {
        var ledger = ReadingLedger()
        #expect(ledger.dailySeconds.isEmpty)
        ledger.record(start:date(2026,11,4,9),seconds:120,calendar:calendar)
        ledger.record(start:date(2026,11,4,18),seconds:180,calendar:calendar)
        #expect(ledger.dailySeconds["2026-11-04"] == 300)
    }
    @Test func springDSTDayHasTwentyThreeHours() {
        var ledger = ReadingLedger()
        ledger.record(start:date(2025,3,9),seconds:24*3600,calendar:calendar)
        #expect(abs((ledger.dailySeconds["2025-03-09"] ?? -1) - 82800.0) < 0.001)
        #expect(abs((ledger.dailySeconds["2025-03-10"] ?? -1) - 3600.0) < 0.001)
    }
    @Test func fallDSTDayHasTwentyFiveHours() {
        var ledger = ReadingLedger()
        ledger.record(start:date(2025,11,2),seconds:26*3600,calendar:calendar)
        #expect(abs((ledger.dailySeconds["2025-11-02"] ?? -1) - 90000.0) < 0.001)
        #expect(abs((ledger.dailySeconds["2025-11-03"] ?? -1) - 3600.0) < 0.001)
    }
    @Test func bucketsKeepMissingDatesAtZeroAndAggregateWeeks() {
        var ledger = ReadingLedger()
        ledger.record(start:date(2026,11,2,10),seconds:600,calendar:calendar)
        ledger.record(start:date(2026,11,4,10),seconds:900,calendar:calendar)
        let days = ledger.buckets(period:.day,through:date(2026,11,4),calendar:calendar)
        #expect(days.count == 7)
        #expect(days.last?.seconds == 900)
        #expect(days[5].seconds == 0)
        let weeks = ledger.buckets(period:.week,through:date(2026,11,4),calendar:calendar)
        #expect(weeks.count == 8)
        #expect(weeks.last?.seconds == 1500)
        let months = ledger.buckets(period:.month,through:date(2026,11,4),calendar:calendar)
        #expect(months.count == 12)
        #expect(months.last?.seconds == 1500)
    }
    @Test func changingYearDoesNotMergeSameNamedMonths() {
        var ledger = ReadingLedger()
        ledger.record(start:date(2025,12,31,23,55),seconds:600,calendar:calendar)
        let months = ledger.buckets(period:.month,through:date(2026,1,2),calendar:calendar)
        #expect(months[10].seconds == 300)
        #expect(months[11].seconds == 300)
        #expect(Set(months.map(\.label)).count == 12)
    }
    @Test func calendarYearViewAndAllYearsAggregation() {
        var ledger = ReadingLedger()
        ledger.record(start:date(2025,1,4),seconds:120,calendar:calendar)
        ledger.record(start:date(2026,1,4),seconds:180,calendar:calendar)
        ledger.record(start:date(2026,12,4),seconds:60,calendar:calendar)
        let year = ledger.months(year:2026,calendar:calendar)
        #expect(year.count == 12)
        #expect(year[0].seconds == 180)
        #expect(year[1].seconds == 0)
        #expect(year[11].seconds == 60)
        #expect(ledger.months(year:nil,calendar:calendar)[0].seconds == 300)
    }

}
