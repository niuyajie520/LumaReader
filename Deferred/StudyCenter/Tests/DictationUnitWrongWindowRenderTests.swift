import AppKit
import Foundation
import SwiftUI
import Testing
@testable import LumaReaderStudyKit

/// 渲染回归：确认「本轮错题」独立窗口在**有内容时**能把每一行、类型、批量按钮画出来。
/// 只读快照，不碰磁盘上的真实学习数据。
@MainActor
struct DictationUnitWrongWindowRenderTests {
    private func word(_ id: String, _ text: String, _ meaning: String) -> VocabularyWord {
        VocabularyWord(id: id, word: text, definitionZH: meaning,
                       deckID: "unit-a", deckTitle: "测试词本")
    }

    private func log(_ id: String, _ text: String, typed: String,
                     at seconds: TimeInterval,
                     session: UUID = UUID()) -> DictationAttemptLog {
        DictationAttemptLog(
            id: UUID(), sessionID: session, mode: .newTask, wordID: id,
            word: text, deckID: "unit-a", userTyped: typed,
            isCorrect: false, isFirstAttemptInSession: true,
            sessionErrorCountForWord: 1,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000 + seconds),
            dateString: "2023-11-14", durationSeconds: 2.5
        )
    }

    @Test func rendersRowsForAttemptsAndMeaningOnlyWords() throws {
        let words = [
            word("w1", "branch off from", "从…分岔"),
            word("w2", "poultry", "家禽"),
            word("w3", "side entrance", "侧门"),
        ]
        let session = UUID()
        var snapshot = StudyStoreSnapshot(dictationLogs: [
            log("w1", "branch off from", typed: "branck o", at: 0, session: session),
            log("w3", "side entrance", typed: "side enter", at: 60, session: session),
        ])
        snapshot.roundMeaningWordIDs = [session.uuidString: ["w2"]]
        let suppressed = Set(snapshot.suppressedWrongLogIDs ?? [])
        #expect(suppressed.isEmpty)
        #expect(snapshot.effectiveWrongLogs.count == 2)

        let binding = Binding<StudyStoreSnapshot>(get: { snapshot }, set: { snapshot = $0 })
        let view = DictationUnitWrongWindowView(
            snapshot: binding, words: words, deckIDs: ["unit-a"],
            deckTitle: "测试词本",
            roundID: session, roundWordIDs: ["w1", "w2", "w3"],
            onChange: { _ in }
        )
        .frame(width: 940, height: 570)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 940, height: 570)
        host.layoutSubtreeIfNeeded()
        // 给 SwiftUI 一帧时间完成首屏布局
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            Issue.record("无法创建位图")
            return
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("无法编码 PNG")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation-unit-wrong-window.png")
        try png.write(to: url)

        // 断言：画面不是纯色（说明标题、列表行、底部按钮真的画出来了）
        var distinct = Set<UInt32>()
        let step = max(1, rep.pixelsWide / 120)
        for x in stride(from: 0, to: rep.pixelsWide, by: step) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: step) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let r = UInt32(color.redComponent * 255) << 16
                let g = UInt32(color.greenComponent * 255) << 8
                let b = UInt32(color.blueComponent * 255)
                distinct.insert(r | g | b)
                if distinct.count > 40 { break }
            }
            if distinct.count > 40 { break }
        }
        print("rendered: \(url.path) distinctColors=\(distinct.count)")
        #expect(distinct.count > 40, "窗口画面近似纯色，列表可能没有渲染：\(url.path)")
    }
}
