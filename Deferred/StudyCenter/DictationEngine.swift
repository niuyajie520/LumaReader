import Foundation
import SwiftUI
import AppKit

public struct DictationSessionReport: Equatable, Sendable {
    public struct Row: Identifiable, Equatable, Sendable {
        public var id: String { wordID }
        public let wordID: String
        public let word: String
        public let errors: Int
        public let status: String
        public let maxReactionSeconds: Double
        public var isSlowReaction: Bool { maxReactionSeconds > SlowReactionWordRecord.slowThresholdSeconds }

        public init(wordID: String, word: String, errors: Int, status: String, maxReactionSeconds: Double = 0.0) {
            self.wordID = wordID
            self.word = word
            self.errors = errors
            self.status = status
            self.maxReactionSeconds = maxReactionSeconds
        }
    }
    public let totalWords: Int
    public let completedWords: Int
    public let firstTryCorrect: Int
    public let stubbornCount: Int
    public let slowReactionCount: Int
    public let rows: [Row]

    public init(session: DictationSessionStateMachine) {
        var words: [String: String] = [:]
        var maxLatencies: [String: Double] = [:]
        for item in session.pendingQueue { words[item.id] = item.word }
        for log in session.attemptLogs {
            words[log.wordID] = log.word
            if log.isCorrect {
                maxLatencies[log.wordID] = max(maxLatencies[log.wordID, default: 0.0], log.durationSeconds)
            }
        }
        for rec in session.stubbornWordsMap.values { words[rec.wordID] = rec.word }
        totalWords = words.count
        completedWords = session.completedWordIDs.count
        firstTryCorrect = Set(session.attemptLogs.filter { $0.isFirstAttemptInSession && $0.isCorrect }.map(\.wordID)).count
        stubbornCount = session.stubbornWordsMap.count
        slowReactionCount = words.keys.filter { maxLatencies[$0, default: 0.0] > SlowReactionWordRecord.slowThresholdSeconds }.count
        rows = words.map { id, word in
            let errors = max(session.sessionErrorCounts[id, default: 0], session.stubbornWordsMap[id]?.errorCount ?? 0)
            let maxLat = maxLatencies[id, default: 0.0]
            let status: String
            if session.stubbornWordsMap[id] != nil {
                status = "顽固单词"
            } else if errors > 0 {
                status = "四轮循环通过"
            } else if maxLat > SlowReactionWordRecord.slowThresholdSeconds {
                status = "慢反应词 (>5s)"
            } else {
                status = "一次通过"
            }
            return Row(wordID: id, word: word, errors: errors, status: status, maxReactionSeconds: maxLat)
        }.sorted { $0.errors != $1.errors ? $0.errors > $1.errors : $0.word < $1.word }
    }

    public var csv: String {
        let body = (["word,errors,status,max_reaction_seconds"] + rows.map {
            "\"\(Self.escape($0.word))\",\"\($0.errors)\",\"\(Self.escape($0.status))\",\"\(String(format: "%.2f", $0.maxReactionSeconds))\""
        }).joined(separator: "\n")
        return "\u{FEFF}" + body
    }

    private static func escape(_ text: String) -> String { text.replacingOccurrences(of: "\"", with: "\"\"") }
}

public struct DictationReportView: View {
    @Environment(\.studyAppearance) private var appearance
    public let report: DictationSessionReport
    public init(session: DictationSessionStateMachine) { self.report = DictationSessionReport(session: session) }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本轮听写报告").font(.headline)
                Spacer()
                Button("导出 CSV") {
                    let panel = NSSavePanel(); panel.nameFieldStringValue = "dictation-report.csv"
                    if panel.runModal() == .OK, let url = panel.url { try? report.csv.data(using: .utf8)?.write(to: url, options: .atomic) }
                }
            }
            Text("完成 \(report.completedWords)/\(report.totalWords) · 首次正确 \(report.firstTryCorrect) · 慢反应词 (>5s) \(report.slowReactionCount) · 顽固单词 \(report.stubbornCount)").font(.caption)
            ForEach(report.rows) { row in
                HStack {
                    Text(row.word).font(.body.weight(.semibold))
                    if row.maxReactionSeconds > 0 {
                        Text(String(format: "反应 %.1fs", row.maxReactionSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(row.isSlowReaction ? appearance.accent : appearance.ink.opacity(0.62))
                    }
                    Spacer()
                    Text("错误 \(row.errors) 次")
                    Text(row.status)
                        .foregroundStyle(appearance.accent)
                }.font(.caption)
            }
        }
    }
}

// MARK: - 本轮口径（v4 硬约束 2.4）

/// 「本轮」的唯一口径：词本集合 + 轮次 ID。
/// 所有「本轮错题 / 本轮已听 / 错题徽章」都必须经过这里过滤，禁止用时间戳、只用词本或只用日期判断本轮。
public struct RoundScope: Equatable, Hashable, Sendable {
    public let deckIDs: Set<String>
    public let roundID: UUID

    public init(deckIDs: Set<String>, roundID: UUID) {
        self.deckIDs = deckIDs
        self.roundID = roundID
    }

    public init<S: Sequence>(deckIDs: S, roundID: UUID) where S.Element == String {
        self.init(deckIDs: Set(deckIDs), roundID: roundID)
    }

    /// 同时满足轮次与词本才算本轮。
    public func contains(_ log: DictationAttemptLog) -> Bool {
        log.sessionID == roundID && deckIDs.contains(log.deckID)
    }

    public func logs(_ logs: [DictationAttemptLog]) -> [DictationAttemptLog] {
        logs.filter { self.contains($0) }
    }

    /// 本轮已听：只算每个词在本轮里的首次尝试（订正不算）。
    public func firstAttemptCount(in logs: [DictationAttemptLog]) -> Int {
        var seen = Set<String>()
        for log in logs where contains(log) && log.isFirstAttemptInSession {
            seen.insert(log.wordID)
        }
        return seen.count
    }

    /// 本轮里出现过的词。
    public func wordIDs(in logs: [DictationAttemptLog]) -> Set<String> {
        Set(logs.lazy.filter { self.contains($0) }.map(\.wordID))
    }

    /// 本轮标记「意思不清」的词（按轮次 ID 存储）。
    public func meaningWordIDs(in snapshot: StudyStoreSnapshot) -> Set<String> {
        Set(snapshot.roundMeaningWordIDs?[roundID.uuidString] ?? [])
    }
}
