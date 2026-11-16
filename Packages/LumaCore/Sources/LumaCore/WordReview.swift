import Foundation

/// 融合艾宾浩斯遗忘曲线 (Ebbinghaus Forgetting Curve) 与 GitHub 开源 FSRS (Free Spaced Repetition Scheduler) DSR 记忆模型：
/// - D (Difficulty): 记忆难度 [1.0, 10.0]，根据拼写正误与反应时长 (>5.0s 慢反应 / <=2.0s 秒答) 自动动态更新
/// - S (Stability): 记忆稳定性（天），即记忆保持率从 100% 衰减至 90% 所需的天数
/// - R (Retrievability): 实时艾宾浩斯记忆保持率 R(t, S) = (1 + 19/81 * t / S)^(-0.5)
public struct WordReviewProgress: Codable, Equatable, Sendable {
    public static let ebbinghausBaseIntervals: [Int] = [1, 3, 5, 7, 10, 14]
    public var stage: Int
    public var dueAt: Date
    public var lastReviewedAt: Date?
    public var stability: Double
    public var difficulty: Double
    public var lapses: Int

    public init(
        stage: Int = 0,
        dueAt: Date = .distantPast,
        lastReviewedAt: Date? = nil,
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        lapses: Int = 0
    ) {
        self.stage = stage
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.stability = stability
        self.difficulty = difficulty
        self.lapses = lapses
    }

    private enum CodingKeys: String, CodingKey {
        case stage, dueAt, lastReviewedAt, stability, difficulty, lapses
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stage = try c.decodeIfPresent(Int.self, forKey: .stage) ?? 0
        dueAt = try c.decodeIfPresent(Date.self, forKey: .dueAt) ?? .distantPast
        lastReviewedAt = try c.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        stability = try c.decodeIfPresent(Double.self, forKey: .stability) ?? 0.0
        difficulty = try c.decodeIfPresent(Double.self, forKey: .difficulty) ?? 5.0
        lapses = try c.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
    }

    /// 实时计算当前时刻的艾宾浩斯记忆保持率 R(t) ∈ [0.0, 1.0]
    public func ebbinghausRetrievability(at now: Date = Date()) -> Double {
        guard let last = lastReviewedAt else {
            return stage > 0 ? 0.90 : 0.0
        }
        let elapsedDays = max(0.0, now.timeIntervalSince(last) / 86400.0)
        let effS = max(0.5, stability > 0 ? stability : Double(Self.ebbinghausBaseIntervals[min(max(0, stage - 1), Self.ebbinghausBaseIntervals.count - 1)]))
        return pow(1.0 + (19.0 / 81.0) * (elapsedDays / effS), -0.5)
    }

    /// 上一次接触是不是就在今天。同一天里再见到同一个词（包括看答案后当场改对）
    /// 只算「当堂练对」，不算掌握：跨天间隔必须由隔天（或到期后）的无提示回忆推动。
    public func lastReviewedOnSameDay(as now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let last = lastReviewedAt else { return false }
        return calendar.isDate(last, inSameDayAs: now)
    }

    /// 次日零点：当天练过的词统一在明天第一次打开时再考一次无提示回忆。
    public static func nextDayStart(after now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86400)
    }

    public mutating func record(
        cleanRecall: Bool,
        reactionSeconds: Double? = nil,
        at now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let intervals = Self.ebbinghausBaseIntervals
        let r = ebbinghausRetrievability(at: now)
        let sameDayRecall = lastReviewedOnSameDay(as: now, calendar: calendar)
        lastReviewedAt = now

        if cleanRecall {
            if sameDayRecall {
                // 当天再对一次：档位原地不动、不拉长稳定性，也不把已经排好的跨天复习提前或推后，
                // 最迟安排到明天再考一次。当场订正后的「拼对」也走这一支，
                // 所以看答案改对不会被当成跨天掌握。
                difficulty = max(1.0, difficulty - 0.15)
                stability = max(stability, 1.0)
                dueAt = max(dueAt, Self.nextDayStart(after: now, calendar: calendar))
                return
            }
            let days = intervals[min(stage, intervals.count - 1)]
            stage = min(stage + 1, intervals.count)
            // FSRS difficulty & stability update modulated by reaction latency
            let isSlow = (reactionSeconds ?? 2.5) > 5.0
            let isFast = (reactionSeconds ?? 2.5) <= 1.8
            let gradeDelta: Double = isSlow ? 0.45 : (isFast ? -0.35 : -0.10)
            difficulty = min(10.0, max(1.0, difficulty + gradeDelta))
            let prevS = max(1.0, stability > 0 ? stability : Double(days))
            let growth = 1.0 + exp(0.75) * (11.0 - difficulty) * pow(prevS, -0.18) * (exp((1.0 - r) * 0.25) - 1.0 + (isFast ? 0.65 : (isSlow ? 0.22 : 0.45)))
            stability = max(Double(days), min(14.0, prevS * max(1.15, growth)))
            dueAt = calendar.date(byAdding: .day, value: days, to: now) ?? now
        } else {
            stage = 0
            lapses += 1
            difficulty = min(10.0, max(1.0, difficulty + 0.85))
            stability = max(0.5, (stability > 0 ? stability : 1.0) * 0.35)
            dueAt = now
        }
    }
}

/// 学新词时的取词顺序：昨天学过、今天到期的词先做一次隔天无提示回忆，再按词表顺序进新词。
public enum WordReviewOrdering {
    public static func isDueForNextDayRecall(
        _ progress: WordReviewProgress?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let progress, let last = progress.lastReviewedAt else { return false }
        return progress.dueAt <= now && !calendar.isDate(last, inSameDayAs: now)
    }

    /// 稳定分区：到期的词保持原词表顺序提到最前，其余词的相对顺序不变。
    public static func dueFirst(
        _ words: [VocabularyWord],
        schedule: [String: WordReviewProgress]?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [VocabularyWord] {
        guard let schedule, !schedule.isEmpty, !words.isEmpty else { return words }
        var due: [VocabularyWord] = []
        var rest: [VocabularyWord] = []
        due.reserveCapacity(words.count)
        rest.reserveCapacity(words.count)
        for word in words {
            if isDueForNextDayRecall(schedule[word.id], now: now, calendar: calendar) {
                due.append(word)
            } else {
                rest.append(word)
            }
        }
        return due.isEmpty ? words : due + rest
    }
}
