import Foundation

/// Transparent fixed intervals, not an unvalidated FSRS implementation.
public struct WordReviewProgress:Codable,Equatable,Sendable {
    public var stage:Int=0
    public var dueAt:Date
    public var lastReviewedAt:Date?
    public init(dueAt:Date){self.dueAt=dueAt}
    public mutating func record(cleanRecall:Bool,at date:Date,calendar:Calendar = .current) {
        let intervals=[1,3,7,14,30]
        stage=cleanRecall ? min(max(0,stage),intervals.count-1)+1:0
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
    public var suggestedPart1:String? = nil
    public var suggestedPart2:String? = nil
    public var updatedAt:Date
    public init(id:UUID=UUID(),submissionID:UUID,part1:String="",part2:String="",updatedAt:Date=Date()) {
        self.id=id;self.submissionID=submissionID;self.part1=part1;self.part2=part2;self.updatedAt=updatedAt
    }
}

nonisolated enum WritingSuggestedDraft {
    /// Only merge uniquely located, non-overlapping quoted suggestions.
    /// Ambiguous quotations stay in the sentence feedback for manual review.
    static func applying(_ corrections:[IELTSFourCriteriaEstimate.SentenceCorrectionItem],to original:String)->String {
        let source=original as NSString
        var replacements:[(NSRange,String)]=[]
        for item in corrections where !item.originalSentence.isEmpty {
            let range=source.range(of:item.originalSentence)
            guard range.location != NSNotFound else{continue}
            let after=range.location+range.length
            let repeated=source.range(of:item.originalSentence,options:[],range:NSRange(location:after,length:source.length-after))
            guard repeated.location==NSNotFound,!replacements.contains(where:{NSIntersectionRange($0.0,range).length>0}) else{continue}
            replacements.append((range,item.correctedSentence))
        }
        let result=NSMutableString(string:original)
        for (range,text) in replacements.sorted(by:{$0.0.location>$1.0.location}){result.replaceCharacters(in:range,with:text)}
        return result as String
    }
}
public extension WritingRevision {
    init(original:WritingSubmissionRecord) {
        self.init(submissionID:original.id)
        if let corrections=original.aiEvaluation?.sentenceCorrections {
            suggestedPart1=WritingSuggestedDraft.applying(corrections,to:original.part1EssayText)
            suggestedPart2=WritingSuggestedDraft.applying(corrections,to:original.part2EssayText)
        }
    }
}
