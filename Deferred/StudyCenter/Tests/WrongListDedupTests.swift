import Foundation
import Testing
@testable import LumaReaderStudyKit

/// 「本轮错题」按词归并：同一个词错多次只占一行，旁边标次数。
struct WrongListDedupTests {
    private func log(_ wordID: String, _ text: String, typed: String,
                     at seconds: TimeInterval) -> DictationAttemptLog {
        DictationAttemptLog(
            id: UUID(), sessionID: UUID(), mode: .newTask, wordID: wordID,
            word: text, deckID: "unit-a", userTyped: typed,
            isCorrect: false, isFirstAttemptInSession: true,
            sessionErrorCountForWord: 1,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000 + seconds),
            dateString: "2023-11-14", durationSeconds: 2.5
        )
    }

    @Test func sameWordCollapsesIntoOneRowWithCount() {
        // 新的在前：double-grill 错 3 次，poultry 错 1 次。
        let logs = [
            log("w1", "double-grill", typed: "k", at: 300),
            log("w2", "poultry", typed: "pultry", at: 200),
            log("w1", "double-grill", typed: "double grills", at: 100),
            log("w1", "double-grill", typed: "duble-grill", at: 50),
        ]
        let groups = DictationWrongLogGrouping.groups(logs)
        #expect(groups.map(\.wordID) == ["w1", "w2"])
        #expect(groups.map(\.count) == [3, 1])
        // 行上显示的是最近一次输入。
        #expect(groups.first?.latest.userTyped == "k")
        #expect(groups.first?.logs.map(\.userTyped) == ["k", "double grills", "duble-grill"])
    }

    @Test func tenMistakesStillOneRow() {
        let logs = (0..<10).map { log("w9", "serendipity", typed: "serendipiti\($0)", at: Double(100 - $0)) }
        let groups = DictationWrongLogGrouping.groups(logs)
        #expect(groups.count == 1)
        #expect(groups.first?.count == 10)
        #expect(groups.first?.wordID == "w9")
    }

    @Test func emptyInputStaysEmpty() {
        #expect(DictationWrongLogGrouping.groups([]).isEmpty)
    }
}
