import Foundation

struct ReadingBucket: Identifiable, Equatable {
    var id: Date { start }
    var start: Date
    var end: Date
    var label: String
    var seconds: Double
}

enum ReadingPeriod: String, CaseIterable, Identifiable {
    case day = "每天", week = "每周", month = "每月"
    var id: String { rawValue }
    var component: Calendar.Component {
        switch self { case .day: return .day; case .week: return .weekOfYear; case .month: return .month }
    }
    var count: Int { switch self { case .day: return 7; case .week: return 8; case .month: return 12 } }
}

struct ReadingSession: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var start: Date
    var end: Date
}

struct ReadingLedger: Codable, Equatable, Sendable {
    var dailySeconds: [String: Double] = [:]
    var components: [String: [String: Double]]? = nil
    var sessions: [String: ReadingSession]? = nil
    // Reset cutoffs suppress pre-reset records when another device syncs later.
    var resetDays: [String: Date]? = nil
    var restoredDays: [String: Date]? = nil



    func sessions(on date:Date,calendar:Calendar = .current)->[ReadingSession] {
        guard let day = calendar.dateInterval(of:.day,for:date) else { return [] }
        let key = Self.key(date,calendar:calendar)
        let reset = resetDays?[key] ?? .distantPast
        let cutoff = reset > (restoredDays?[key] ?? .distantPast) ? reset:.distantPast
        return (sessions ?? [:]).values.compactMap { session in
            let start = max(max(session.start,day.start),cutoff), end = min(session.end,day.end)
            guard end > start else { return nil }
            return ReadingSession(id:session.id,start:start,end:end)
        }.sorted { $0.start < $1.start }
    }
    func hours(on date:Date,calendar:Calendar = .current)->[ReadingBucket] {
        guard let day = calendar.dateInterval(of:.day,for:date) else { return [] }
        let records = sessions(on:date,calendar:calendar)
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "HH:mm"
        var result:[ReadingBucket] = [], cursor = day.start
        while cursor < day.end {
            guard let hour = calendar.dateInterval(of:.hour,for:cursor),hour.end > cursor else { break }
            let end = min(hour.end,day.end)
            let total = records.reduce(0.0) { $0 + max(0,min($1.end,end).timeIntervalSince(max($1.start,cursor))) }
            result.append(ReadingBucket(start:cursor,end:end,label:formatter.string(from:cursor),seconds:total)); cursor = end
        }
        return result
    }

    static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year,.month,.day],from:date)
        return String(format:"%04d-%02d-%02d",c.year ?? 0,c.month ?? 0,c.day ?? 0)
    }

    // Split sessions at local calendar midnights (including DST-length days).
    mutating func record(start: Date, seconds: Double, calendar: Calendar = .current) {
        guard seconds.isFinite, seconds > 0 else { return }
        let session = ReadingSession(id:UUID().uuidString,start:start,end:start.addingTimeInterval(seconds))
        if sessions == nil { sessions = [:] }; sessions?[session.id] = session
        if components == nil { components = ["legacy": dailySeconds] }
        var cursor = start
        let finish = start.addingTimeInterval(seconds)
        while cursor < finish {
            let dayStart = calendar.startOfDay(for:cursor)
            guard let nextDay = calendar.date(byAdding:.day,value:1,to:dayStart),nextDay>cursor else { return }
            let end = min(finish,nextDay)
            let key = Self.key(cursor,calendar:calendar)
            let elapsed = end.timeIntervalSince(cursor)
            components![ReadingDevice.id, default: [:]][key, default: 0] += elapsed
            dailySeconds[key, default: 0] += elapsed
            cursor = end
        }
    }

    func seconds(in interval: DateInterval, calendar: Calendar = .current) -> Double {
        var total = 0.0
        var day = calendar.startOfDay(for:interval.start)
        while day < interval.end {
            let key = Self.key(day,calendar:calendar)
            if let reset = resetDays?[key],reset > (restoredDays?[key] ?? .distantPast) {
                total += sessions(on:day,calendar:calendar).reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
            } else { total += dailySeconds[key,default:0] }
            guard let next = calendar.date(byAdding:.day,value:1,to:day),next>day else { break }
            day = next
        }
        return total
    }

    // Openreads-style calendar-year view, including an all-years month aggregation.
    func months(year: Int?, calendar: Calendar = .current) -> [ReadingBucket] {
        let displayYear = year ?? calendar.component(.year,from:Date())
        return (1...12).compactMap { month in
            guard let start = calendar.date(from:DateComponents(year:displayYear,month:month,day:1)),
                  let interval = calendar.dateInterval(of:.month,for:start) else { return nil }
            let total: Double
            if year != nil { total = seconds(in:interval,calendar:calendar) }
            else {
                total = dailySeconds.reduce(0) { sum,item in
                    let parts = item.key.split(separator:"-")
                    guard parts.count == 3,Int(parts[1]) == month,
                          let year = Int(parts[0]),let day = Int(parts[2]),
                          let date = calendar.date(from:DateComponents(year:year,month:month,day:day)),
                          let interval = calendar.dateInterval(of:.day,for:date) else { return sum }
                    return sum + seconds(in:interval,calendar:calendar)
                }
            }
            return ReadingBucket(start:interval.start,end:interval.end,label:"\(month)月",seconds:total)
        }
    }

    func buckets(period: ReadingPeriod, through date: Date, calendar: Calendar = .current) -> [ReadingBucket] {
        guard let containing = calendar.dateInterval(of:period.component,for:date) else { return [] }
        let formatter = DateFormatter();formatter.calendar = calendar;formatter.timeZone = calendar.timeZone
        formatter.dateFormat = period == .month ? "yy/M" : "M/d"
        return (0..<period.count).compactMap { index in
            guard let start = calendar.date(byAdding:period.component,value:index-period.count+1,to:containing.start),
                  let interval = calendar.dateInterval(of:period.component,for:start) else { return nil }
            return ReadingBucket(start:interval.start,end:interval.end,label:formatter.string(from:interval.start),seconds:seconds(in:interval,calendar:calendar))
        }
    }
}

func readingDuration(_ seconds: Double) -> String {
    let minutes = max(0,Int(seconds / 60))
    if seconds > 0 && minutes == 0 { return "不足 1 分钟" }
    if minutes < 60 { return "\(minutes) 分钟" }
    return "\(minutes / 60) 小时 \(minutes % 60) 分钟"
}
