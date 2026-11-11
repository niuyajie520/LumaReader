import Foundation
import Testing
@testable import LumaReaderStudyKit

@MainActor
@Suite("IELTS Official May 2023 Rubric Engine, Reaction Latency, Swift Charts Stats & Built-in Dictionary Tests")
struct IELTSOfficialRubricAndEmbeddedSpeechTests {

    @Test("1. Submitting Task 1 (小作文) automatically selects Academic Task 1 TA rubric and checks Overview & Chart Data")
    func testTask1AutomaticDetectionAndOfficialRubric() {
        let question = LumaStudyCenterHostView.builtInPracticeQuestions[0]
        let weakTask1 = WritingSubmissionRecord(
            id: UUID(),
            draftSessionID: UUID(),
            questionID: question.id,
            examTitle: question.shortTitle,
            part1EssayText: "The chart shows changes in energy consumption in different sectors. Some sectors went up and some sectors went down over the years.",
            part2EssayText: "",
            part1WordCount: 23,
            part2WordCount: 0,
            durationSeconds: 900,
            submittedAt: Date(),
            dateString: "2026-11-08",
            aiEvaluation: nil
        )
        let weakAudit = IELTSOfficialRubricEngine.audit(record: weakTask1, question: question)
        #expect(weakAudit.detectedTaskMode == .academicTask1)
        #expect(weakAudit.detectedTaskMode.firstCriterionCode == "TA")
        #expect(weakAudit.hasClearOverview == false)
        #expect(weakAudit.deterministicEstimate.taskAchievementOrResponse <= 5.5)

        let strongEssay = """
        The line graph illustrates the changes in urban electricity consumption across three metropolitan regions between 2010 and 2022, measured in gigawatt-hours (GWh).

        Overall, it is clear that while renewable energy usage experienced a substantial upward trajectory over the twelve-year period, reliance on conventional thermal power declined steadily across all surveyed cities.

        Specifically, in 2010, Metropolis A consumed 450 GWh of electricity, whereas Metropolis B stood at 320 GWh. By 2018, the figure for Metropolis A surged to 610 GWh, representing the highest point on the chart. Compared with Metropolis B, which witnessed a moderate rise to 410 GWh in 2022, Metropolis C maintained a relatively stable demand of approximately 280 GWh throughout the entire period. Furthermore, the proportion of clean electricity expanded from 18% to 54%, which highlights a pronounced structural transition.
        """
        let strongTask1 = WritingSubmissionRecord(
            id: UUID(),
            draftSessionID: UUID(),
            questionID: question.id,
            examTitle: question.shortTitle,
            part1EssayText: strongEssay,
            part2EssayText: "",
            part1WordCount: 142,
            part2WordCount: 0,
            durationSeconds: 1150,
            submittedAt: Date(),
            dateString: "2026-11-08",
            aiEvaluation: nil
        )
        let strongAudit = IELTSOfficialRubricEngine.audit(record: strongTask1, question: question)
        #expect(strongAudit.detectedTaskMode == .academicTask1)
        #expect(strongAudit.hasClearOverview == true)
        #expect(strongAudit.hasSupportingDataFigures == true)
        #expect(strongAudit.containsInappropriatePersonalOpinion == false)
        #expect(!strongAudit.task1Checklist.isEmpty)

        let enriched = IELTSOfficialRubricEngine.enrichQuestionWithOfficialRubric(question, for: strongTask1, audit: strongAudit)
        #expect(enriched.companionTask2Prompt == nil)
        #expect(enriched.promptText.contains("Task Achievement (TA"))
    }

    @Test("2. Submitting Task 2 (大作文) automatically selects Task 2 TR rubric")
    func testTask2AutomaticDetectionAndTRRubric() {
        let question = LumaStudyCenterHostView.builtInPracticeQuestions[0]
        let task2Record = WritingSubmissionRecord(
            id: UUID(),
            draftSessionID: UUID(),
            questionID: question.id,
            examTitle: "T2 · " + question.shortTitle,
            part1EssayText: "",
            part2EssayText: """
            In contemporary society, there is an ongoing debate regarding whether governments should prioritize public transit investment over highway expansion. This essay will argue that funding rail and bus infrastructure yields far greater long-term economic and environmental benefits.

            On the one hand, expanding road networks can temporarily alleviate traffic bottlenecks in suburban areas. However, empirical evidence suggests that additional lanes frequently induce further private vehicle demand, resulting in recurring congestion within a few years.

            On the other hand, high-capacity public transport significantly reduces carbon emissions per passenger and enhances urban mobility for lower-income residents who do not own cars.

            In conclusion, I firmly believe that municipal authorities ought to allocate the majority of transport budgets to sustainable public transit systems rather than road widening projects.
            """,
            part1WordCount: 0,
            part2WordCount: 132,
            durationSeconds: 2100,
            submittedAt: Date(),
            dateString: "2026-11-08",
            aiEvaluation: nil
        )
        let audit = IELTSOfficialRubricEngine.audit(record: task2Record, question: question)
        #expect(audit.detectedTaskMode == .writingTask2)
        #expect(audit.detectedTaskMode.firstCriterionCode == "TR")
        #expect(audit.hasClearTask2Position == true)
        #expect(audit.paragraphCount == 4)
    }

    @Test("3. Official IELTS Band Rounding and Inline Diff & Error Letter Analyzer")
    func testOfficialBandRoundingAndDiffAnalyzers() {
        #expect(IELTSOfficialRubricEngine.roundToOfficialIELTSBand(6.25) == 6.5)
        #expect(IELTSOfficialRubricEngine.roundToOfficialIELTSBand(6.75) == 7.0)
        #expect(IELTSOfficialRubricEngine.roundToOfficialIELTSBand(6.125) == 6.0)
        #expect(IELTSOfficialRubricEngine.roundToOfficialIELTSBand(6.625) == 6.5)

        let diff = WritingInlineDiffView.computeWordDiff(
            original: "The figure increase rapidly in 2020.",
            revised: "The figure increased rapidly in 2020."
        )
        #expect(diff.contains(.deleted("increase")))
        #expect(diff.contains(.inserted("increased")))

        let missed = WordErrorLetterAnalyzer.errorProneIndices(
            targetWord: "accommodation",
            typedAttempts: ["acomodation"]
        )
        #expect(!missed.isEmpty)
    }

    @Test("4. Cloud Drive sync losslessly merges custom vocabulary, stubborn words, slow reaction words, and writing submissions")
    func testStudyCloudSyncLosslessMerge() throws {
        var macA = StudyStoreSnapshot()
        macA.importedWords = [
            VocabularyWord(id: "w1", word: "resilient", definitionZH: "有韧性的", deckID: "custom", deckTitle: "自建词库")
        ]
        macA.stubbornWords = [
            StubbornWordRecord(wordID: "w1", word: "resilient", sourceDeckID: "custom", sourceDeckTitle: "自建词库", dateString: "2026-11-08", errorCount: 6, triggeringSessionID: UUID())
        ]
        macA.slowReactionWords = [
            SlowReactionWordRecord(wordID: "w1", word: "resilient", definitionZH: "有韧性的", sourceDeckID: "custom", sourceDeckTitle: "自建词库", lastReactionSeconds: 6.2, slowCount: 1, dateString: "2026-11-08")
        ]

        var macB = StudyStoreSnapshot()
        macB.importedWords = [
            VocabularyWord(id: "w2", word: "ubiquitous", definitionZH: "无处不在的", deckID: "custom", deckTitle: "自建词库")
        ]
        macB.stubbornWords = [
            StubbornWordRecord(wordID: "w1", word: "resilient", sourceDeckID: "custom", sourceDeckTitle: "自建词库", dateString: "2026-11-08", errorCount: 9, triggeringSessionID: UUID())
        ]
        macB.slowReactionWords = [
            SlowReactionWordRecord(wordID: "w1", word: "resilient", definitionZH: "有韧性的", sourceDeckID: "custom", sourceDeckTitle: "自建词库", lastReactionSeconds: 7.5, slowCount: 3, dateString: "2026-11-08")
        ]

        let merged = StudyCloudSyncManager.merge(local: macA, remote: macB)
        #expect(merged.importedWords?.count == 2)
        #expect(merged.stubbornWords.first?.errorCount == 9)
        #expect(merged.slowReactionWords?.first?.slowCount == 3)
        #expect(merged.slowReactionWords?.first?.maxReactionSeconds == 7.5)

        let tempCloud = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_" + UUID().uuidString, isDirectory: true)
        let tempLocal = FileManager.default.temporaryDirectory.appendingPathComponent("local_" + UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempCloud)
            try? FileManager.default.removeItem(at: tempLocal)
        }
        let localMgr = try StudyPersistenceManager(storageDirectory: tempLocal)
        let syncResult = StudyCloudSyncManager.sync(localSnapshot: merged, localPersistence: localMgr, cloudRoots: [tempCloud])
        #expect(syncResult.syncedDirectories.count == 1)
        let cloudStorePath = tempCloud.appendingPathComponent("StudyCenter/luma_study_store.json")
        #expect(FileManager.default.fileExists(atPath: cloudStorePath.path))
    }

    @Test("5. Reaction Latency Tracking flags correct answers taking > 5.0 seconds as Slow Reaction Words")
    func testReactionLatencyTrackingAndSlowReactionWords() {
        let words = [
            VocabularyWord(id: "lat-1", word: "alleviate", definitionZH: "v. 缓解", deckID: "d1", deckTitle: "核心词"),
            VocabularyWord(id: "lat-2", word: "curriculum", definitionZH: "n. 课程", deckID: "d1", deckTitle: "核心词")
        ]
        var machine = DictationSessionStateMachine(dateString: "2026-11-08", initialWords: words)
        // Word 1: spelled right, but hesitated for 6.4 seconds (> 5.0s threshold)
        _ = machine.submitAnswer("alleviate", durationSeconds: 6.4)
        #expect(machine.slowReactionWordIDs.contains("lat-1"))
        #expect(machine.attemptLogs.last?.isSlowReaction == true)

        // Word 2: spelled right in 2.1 seconds (<= 5.0s threshold)
        _ = machine.submitAnswer("curriculum", durationSeconds: 2.1)
        #expect(!machine.slowReactionWordIDs.contains("lat-2"))
        #expect(machine.attemptLogs.last?.isSlowReaction == false)

        let report = DictationSessionReport(session: machine)
        #expect(report.slowReactionCount == 1)
        #expect(report.rows.first(where: { $0.wordID == "lat-1" })?.status == "慢反应词 (>5s)")
    }

    @Test("6. Built-in IELTS Dictionaries & Upload Translation Strategy (Defaults to File Built-in Translation, Optional Dictionary Auto-Fill)")
    func testBuiltInDictionaryAndUploadTranslationStrategy() throws {
        #expect(BuiltInIELTSDictionaryEngine.allDictionaries.count == 4)
        #expect(BuiltInIELTSDictionaryEngine.core300Dictionary.words.count == 300)
        #expect(BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: "alleviated") != nil)
        #expect(BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: "governments") != nil)

        let sampleTXT = """
        abandon 自己的自定义翻译
        alleviate
        """
        var draft = try VocabularyImportDraft(data: Data(sampleTXT.utf8), filename: "test_dict.txt")
        // By default, uses built-in file translation and does not overwrite with dictionary
        #expect(draft.useBuiltInDictionaryMode == false)
        #expect(draft.rows[0].meaning == "自己的自定义翻译")
        #expect(draft.rows[1].meaning == "")
        #expect(draft.rows[1].dictionaryMeaning != nil)

        // Switching to smart dictionary fill populates pure-English rows while keeping built-in file translations
        draft.applyTranslationSource(useDictionary: true, overwriteBuiltIn: false)
        #expect(draft.rows[0].meaning == "自己的自定义翻译")
        #expect(!draft.rows[1].meaning.isEmpty)
        #expect(draft.rows[1].needsConfirmation == false)
    }

    @Test("7. Annual Study Heatmap & 4D Writing Competency Line Charts + Bottleneck Diagnosis")
    func testAnnualHeatmapAndWritingCompetencyDiagnostics() {
        let heatmap = StudyStatisticsCalculator.computeAnnualHeatmap(
            readingByDate: ["2026-11-08": 1800],
            dictationLogs: [
                DictationAttemptLog(id: UUID(), sessionID: UUID(), mode: .newTask, wordID: "w1", word: "test", deckID: "d", userTyped: "test", isCorrect: true, isFirstAttemptInSession: true, sessionErrorCountForWord: 0, timestamp: Date(), dateString: "2026-11-08", durationSeconds: 600)
            ],
            writingSubmissions: []
        )
        #expect(heatmap.weekCount == 52)
        #expect(heatmap.totalReadingSeconds == 1800)
        #expect(heatmap.totalListeningSeconds == 600)
        #expect(heatmap.activeDaysCount >= 1)

        let sub1 = WritingSubmissionRecord(
            id: UUID(),
            draftSessionID: UUID(),
            questionID: "ORIG-001",
            examTitle: "Task 1 & 2 Test",
            part1EssayText: "Overall, the chart shows significant changes from 10% to 50%.",
            part2EssayText: "In conclusion, I agree that governments should invest in education.",
            part1WordCount: 155,
            part2WordCount: 260,
            durationSeconds: 3200,
            submittedAt: Date(),
            dateString: "2026-11-08",
            aiEvaluation: IELTSFourCriteriaEstimate(
                taskAchievementOrResponse: 7.0,
                coherenceAndCohesion: 6.5,
                lexicalResource: 5.5,
                grammaticalRangeAndAccuracy: 6.5,
                overallEstimatedBand: 6.5,
                officialDisclaimer: "",
                sentenceCorrections: [
                    .init(originalSentence: "good thing", correctedSentence: "beneficial measure", explanationZH: "高分替换", upgradedExpression: "beneficial measure")
                ]
            )
        )
        let diag = StudyStatisticsCalculator.computeWritingCompetencyDiagnostics(
            submissions: [sub1],
            questions: LumaStudyCenterHostView.builtInPracticeQuestions
        )
        #expect(diag.task1.submissionCount == 1)
        #expect(diag.task2.submissionCount == 1)
        #expect(diag.task1.points.count == 4) // TA, CC, LR, GRA
        #expect(diag.task2.points.count == 4) // TR, CC, LR, GRA
        #expect(diag.task2.bottleneckCriterionCode == "LR")

        let extractedVocab = WritingReviewPanel.extractVocabularyWords(from: sub1.aiEvaluation!.sentenceCorrections, examTitle: sub1.examTitle)
        #expect(extractedVocab.count == 1)
        #expect(extractedVocab.first?.deckID == "vocab_writing_accumulations")
    }
}
