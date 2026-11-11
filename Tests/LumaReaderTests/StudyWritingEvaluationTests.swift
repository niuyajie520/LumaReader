import Foundation
import Testing
import LumaReaderStudyKit
@testable import LumaReader

struct StudyWritingEvaluationTests {
    private func record()throws->WritingSubmissionRecord {
        let json=#"{"id":"00000000-0000-0000-0000-000000000001","draftSessionID":"00000000-0000-0000-0000-000000000002","questionID":"fixture","examTitle":"Fixture","part1EssayText":"The graph shows a rise.","part2EssayText":"","part1WordCount":6,"part2WordCount":0,"durationSeconds":20,"submittedAt":0,"dateString":"2026-11-07"}"#
        return try JSONDecoder().decode(WritingSubmissionRecord.self,from:Data(json.utf8))
    }
    private func estimate(band:Double,original:String,kind:String?=nil)throws->IELTSFourCriteriaEstimate {
        var value:[String:Any] = ["taskAchievementOrResponse":band,"coherenceAndCohesion":band,"lexicalResource":band,"grammaticalRangeAndAccuracy":band,"overallEstimatedBand":band,"officialDisclaimer":"Fixture only","sentenceCorrections":[["originalSentence":original,"correctedSentence":"The graph illustrates an increase.","explanationZH":"synthetic fixture","upgradedExpression":"illustrates an increase"]]]
        if let kind {var items=value["sentenceCorrections"] as! [[String:Any]];items[0]["kind"]=kind;value["sentenceCorrections"]=items}
        return try JSONDecoder().decode(IELTSFourCriteriaEstimate.self,from:JSONSerialization.data(withJSONObject:value))
    }
    @MainActor @Test func acceptsOnlyValidBandsAndActualQuotedEssaySentences()throws {
        let original=try record()
        try StudyWritingEvaluation.validate(estimate(band:6.5,original:"The graph shows a rise."),record:original)
        #expect(throws:(any Error).self){try StudyWritingEvaluation.validate(estimate(band:14,original:"The graph shows a rise."),record:original)}
        #expect(throws:(any Error).self){try StudyWritingEvaluation.validate(estimate(band:6.3,original:"The graph shows a rise."),record:original)}
        #expect(throws:(any Error).self){try StudyWritingEvaluation.validate(estimate(band:6.5,original:"A sentence the user never wrote."),record:original)}
        try StudyWritingEvaluation.validate(estimate(band:6.5,original:"The graph shows a rise.",kind:"upgrade"),record:original)
        #expect(throws:(any Error).self){try StudyWritingEvaluation.validate(estimate(band:6.5,original:"The graph shows a rise.",kind:"invented"),record:original)}
        #expect(original.part1EssayText=="The graph shows a rise.")
    }
}
