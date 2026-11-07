import Foundation
import Testing
@testable import LumaReaderStudyKit

struct StudyLearningRulesTests {
    private func word(_ id:String,_ text:String)->VocabularyWord {
        VocabularyWord(id:id,word:text,phoneticUK:"",phoneticUS:"",partOfSpeech:"",definitionZH:"释义",exampleSentence:"",deckID:"fixture",deckTitle:"Fixture")
    }
    @Test func wrongAnswersBlockAndCorrectionSchedulesDelayedCleanRecall()throws {
        let words=(0..<8).map{word(String($0),"word\($0)")}
        var session=DictationSessionStateMachine(dateString:"2026-11-07",initialWords:words)
        session.submitAnswer("wrong")
        #expect(session.pendingQueue==words)
        #expect(session.completedWordIDs.isEmpty)
        session=try JSONDecoder().decode(DictationSessionStateMachine.self,from:JSONEncoder().encode(session))
        session.submitAnswer("WORD0!!!",retryOffset:3)
        #expect(session.currentWord?.id=="1")
        #expect(session.pendingQueue[3].id=="0")
        #expect(!session.completedWordIDs.contains("0"))
        for _ in 0..<3 {session.submitAnswer(session.currentWord!.word)}
        #expect(session.currentWord?.id=="0")
        session.submitAnswer("wrong again")
        #expect(session.currentWord?.id=="0")
        session.submitAnswer("word0",retryOffset:2)
        #expect(!session.completedWordIDs.contains("0"))
        for _ in 0..<30 {
            guard let current=session.currentWord else{break}
            session.submitAnswer(current.word)
        }
        #expect(session.isSessionFinished)
        #expect(session.completedWordIDs.count==8)
    }
    @Test func sixthErrorQuarantinesWithoutSkippingCurrentCorrection() {
        var session=DictationSessionStateMachine(dateString:"2026-11-07",initialWords:[word("a","accommodation"),word("b","necessary")])
        for _ in 0..<5{session.submitAnswer("wrong")}
        #expect(session.stubbornWordsMap.isEmpty)
        session.submitAnswer("wrong")
        #expect(session.stubbornWordsMap["a"]?.errorCount==6)
        #expect(session.currentWord?.id=="a")
        session.submitAnswer("AcCommodation.")
        #expect(session.pendingQueue.map(\.id)==["b"])
        session.submitAnswer("necessary")
        #expect(session.isSessionFinished)
        #expect(!session.completedWordIDs.contains("a"))
        let report=DictationSessionReport(session:session)
        #expect(report.rows[0].errors==6)
        #expect(report.rows[0].status=="顽固单词")
        #expect(report.csv.hasPrefix("\u{FEFF}"))
        #expect(report.csv.contains("\"accommodation\",\"6\""))
    }
    @Test func normalizationIgnoresCasePunctuationButNotWrongLettersOrNonEnglish() {
        #expect(DictationAnswerPolicy.normalized("“DON’T!” ")==DictationAnswerPolicy.normalized("don't"))
        #expect(DictationAnswerPolicy.normalized("well - known")==DictationAnswerPolicy.normalized("Well-known"))
        #expect(DictationAnswerPolicy.normalized("accomodation") != DictationAnswerPolicy.normalized("accommodation"))
        #expect(DictationAnswerPolicy.normalized("hello中文") != DictationAnswerPolicy.normalized("hello"))
    }
    @Test func automaticRetryUsesBoundedLaterPositions() {
        let words=(0..<12).map{word(String($0),"word\($0)")}
        for _ in 0..<40 {
            var session=DictationSessionStateMachine(dateString:"2026-11-07",initialWords:words)
            session.submitAnswer("wrong");session.submitAnswer("word0")
            let offset=session.pendingQueue.firstIndex{$0.id=="0"}!
            #expect((2...5).contains(offset))
        }
    }
    @Test func reportOrdersErrorsAndEscapesCSV() {
        var session=DictationSessionStateMachine(dateString:"2026-11-07",initialWords:[word("a","hello"),word("b","a,b\"c")])
        session.submitAnswer("hello")
        session.submitAnswer("wrong");session.submitAnswer("wrong");session.submitAnswer("a,b\"c")
        session.submitAnswer("a,b\"c")
        let report=DictationSessionReport(session:session)
        #expect(report.rows.map(\.errors)==[2,0])
        #expect(report.firstTryCorrect==1)
        #expect(report.csv.contains("\"a,b\"\"c\""))
    }
    @Test func importPreviewCanRepairRowsAndNeverOverwritesExistingWords()throws {
        var preview=try VocabularyImportDraft(data:Data("word\tmeaning\nhello\t你好\n中文\t错误\nhello\t重复".utf8),filename:"fixture.tsv")
        #expect(preview.rows[1].issue != nil)
        #expect(throws:(any Error).self){try preview.confirmedWords(existing:[])}
        preview.rows[1].word="world"
        let imported=try preview.confirmedWords(existing:[])
        #expect(imported.count==2)
        #expect(imported[0].definitionZH=="你好")
        #expect(try preview.confirmedWords(existing:imported).isEmpty)
        var later=try VocabularyImportDraft(data:Data("hello\t改动的释义\nnew\t新词".utf8),filename:"fixture.tsv")
        later.rows[1].included=false
        #expect(try later.confirmedWords(existing:imported).isEmpty)
        #expect(imported[0].definitionZH=="你好")
    }
    @Test func reviewScheduleAndMultipleRewritesSurviveDiskReload()throws {
        let date=Date(timeIntervalSince1970:1700000000)
        var progress=WordReviewProgress(dueAt:date)
        let calendar=Calendar(identifier:.gregorian)
        progress.record(cleanRecall:true,at:date,calendar:calendar)
        #expect(calendar.dateComponents([.day],from:date,to:progress.dueAt).day==1)
        progress.record(cleanRecall:true,at:date,calendar:calendar)
        #expect(calendar.dateComponents([.day],from:date,to:progress.dueAt).day==3)
        progress.record(cleanRecall:false,at:date,calendar:calendar)
        #expect(progress.stage==0)
        let originalID=UUID()
        let first=WritingRevision(submissionID:originalID,part1:"teh first draft",updatedAt:date)
        let second=WritingRevision(submissionID:originalID,part2:"Another independent version.",updatedAt:date)
        var snapshot=StudyStoreSnapshot();snapshot.reviewSchedule=["a":progress];snapshot.writingRevisions=[first,second]
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        try StudyPersistenceManager(storageDirectory:dir).save(snapshot)
        let restored=try StudyPersistenceManager(storageDirectory:dir).loadAndMigrateIfNeeded()
        #expect(restored.reviewSchedule==snapshot.reviewSchedule)
        #expect(restored.writingRevisions==[first,second])
    }
    @Test func olderSnapshotsAndSessionsKeepWorkingWithoutNewFields()throws {
        let session=DictationSessionStateMachine(dateString:"2026-11-07",initialWords:[word("a","hello")])
        var json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(session)) as! [String:Any]
        json.removeValue(forKey:"correctionPendingIDs")
        #expect(try JSONDecoder().decode(DictationSessionStateMachine.self,from:JSONSerialization.data(withJSONObject:json)).currentWord?.id=="a")
        var state=try JSONSerialization.jsonObject(with:JSONEncoder().encode(StudyStoreSnapshot())) as! [String:Any]
        state.removeValue(forKey:"reviewSchedule");state.removeValue(forKey:"writingRevisions")
        #expect(try JSONDecoder().decode(StudyStoreSnapshot.self,from:JSONSerialization.data(withJSONObject:state)).writingRevisions==nil)
    }
}
