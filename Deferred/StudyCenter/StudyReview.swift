import Foundation

/// Transparent fixed intervals, not an unvalidated FSRS implementation.
public struct WordReviewProgress:Codable,Equatable,Sendable {
    public var stage:Int=0
    public var dueAt:Date
    public var lastReviewedAt:Date?
    public init(dueAt:Date){self.dueAt=dueAt}
    public mutating func record(cleanRecall:Bool,at date:Date,calendar:Calendar = .current) {
        let intervals=[1,3,7,14,30]
        stage=cleanRecall ? min(stage+1,intervals.count):0
        let days=cleanRecall ? intervals[max(0,stage-1)]:1
        lastReviewedAt=date
        dueAt=calendar.date(byAdding:.day,value:days,to:date) ?? date.addingTimeInterval(Double(days)*86400)
    }
}
public struct WritingRevision:Codable,Equatable,Identifiable,Sendable {
    public let id:UUID
    public let submissionID:UUID
    public var part1:String
    public var part2:String
    public var updatedAt:Date
    public init(id:UUID=UUID(),submissionID:UUID,part1:String="",part2:String="",updatedAt:Date=Date()) {
        self.id=id;self.submissionID=submissionID;self.part1=part1;self.part2=part2;self.updatedAt=updatedAt
    }
}
