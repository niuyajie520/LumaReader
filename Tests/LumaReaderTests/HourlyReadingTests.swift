import Foundation
import Testing
@testable import LumaReader
struct HourlyReadingTests {
    private var calendar:Calendar { var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(secondsFromGMT:0)!;return c }
    @Test func hourlySplitKeepsActualSession() {
        let c=calendar, start=c.date(from:DateComponents(year:2026,month:11,day:5,hour:10,minute:50))!
        var ledger=ReadingLedger();ledger.record(start:start,seconds:1800,calendar:c)
        let hours=ledger.hours(on:start,calendar:c)
        #expect(hours[10].seconds == 600);#expect(hours[11].seconds == 1200)
        #expect(ledger.sessions(on:start,calendar:c).count == 1)
    }
    @Test func resetAndUndoSurviveMergeWithoutDeletingHistory() {
        let c=calendar,start=c.date(from:DateComponents(year:2026,month:11,day:5,hour:10))!
        let key=ReadingLedger.key(start,calendar:c)
        var original=ReadingLedger();original.record(start:start,seconds:600,calendar:c)
        var reset=original;reset.resetDays=[key:start.addingTimeInterval(1000)]
        #expect(reset.hours(on:start,calendar:c).allSatisfy { $0.seconds == 0 })
        #expect(reset.sessions?.count == 1)
        var restored=reset;restored.restoredDays=[key:start.addingTimeInterval(1001)]
        let merged=CloudSyncEngine.mergeLedger(local:restored,remote:reset)
        #expect(merged.hours(on:start,calendar:c).reduce(0){$0+$1.seconds} == 600)
    }
    @Test func historicalRecordsDoNotInventSessions() throws {
        let legacy=try JSONDecoder().decode(ReadingLedger.self,from:Data("{\"dailySeconds\":{\"2026-11-05\":900}}".utf8))
        #expect(legacy.sessions == nil);#expect(legacy.dailySeconds["2026-11-05"] == 900)
    }
}
