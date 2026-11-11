import Foundation
import SwiftUI
import NaturalLanguage
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Official IELTS Writing Band Descriptors Engine (Updated May 2023)
// Grounded in official IELTS Writing Band Descriptors:
// - Task 1 & Task 2 Official PDF: https://ielts.org/cdn/Guides/ielts-writing-band-descriptors.pdf
// - British Council Official PDF: https://takeielts.britishcouncil.org/sites/default/files/%5Bdownloads%5D/ielts_writing_band_descriptors.pdf

public enum IELTSWritingTaskMode: String, Codable, Equatable, Sendable {
    case academicTask1 = "Task 1 小作文 (Academic Report)"
    case writingTask2 = "Task 2 大作文 (Essay)"
    case fullMockExam = "Task 1 + Task 2 完整模考"

    public var firstCriterionCode: String {
        switch self {
        case .academicTask1: return "TA"
        case .writingTask2: return "TR"
        case .fullMockExam: return "TA/TR"
        }
    }

    public var firstCriterionFullTitle: String {
        switch self {
        case .academicTask1: return "Task Achievement (TA · 小作文任务完成度)"
        case .writingTask2: return "Task Response (TR · 大作文任务回应度)"
        case .fullMockExam: return "Task Achievement & Task Response (TA/TR · 大小作文任务回应)"
        }
    }

    public var officialMinimumWords: Int {
        switch self {
        case .academicTask1: return 150
        case .writingTask2: return 250
        case .fullMockExam: return 400
        }
    }
}

public struct Task1KeyPointCheckItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String { title }
    public let title: String
    public let detail: String
    public let passed: Bool
    public let officialRuleNote: String

    public init(title: String, detail: String, passed: Bool, officialRuleNote: String) {
        self.title = title
        self.detail = detail
        self.passed = passed
        self.officialRuleNote = officialRuleNote
    }
}

public struct IELTSRubricAuditReport: Codable, Equatable, Sendable {
    public let detectedTaskMode: IELTSWritingTaskMode
    public let rawWordCount: Int
    public let copiedPromptWordCount: Int
    public let effectiveWordCount: Int
    public let paragraphCount: Int
    public let sentenceCount: Int
    public let averageSentenceLength: Double
    public let complexSentenceCount: Int
    public let complexSentenceRatio: Double
    public let lexicalDiversityMATTR: Double
    public let spellingErrorWords: [String]
    public let mechanicalLinkerCount: Int
    public let hasClearOverview: Bool
    public let hasSupportingDataFigures: Bool
    public let containsInappropriatePersonalOpinion: Bool
    public let hasClearTask2Position: Bool
    public let task1Checklist: [Task1KeyPointCheckItem]
    public let hardBandCaps: [String: Double]
    public let capReasonsZH: [String]
    public let matchedOfficialDescriptors: [String: String]
    public let deterministicEstimate: IELTSFourCriteriaEstimate
}

public enum IELTSOfficialRubricEngine {

    // MARK: - 1. Automatic Task 1 (小作文) vs Task 2 (大作文) Detection

    public static func detectTaskMode(for record: WritingSubmissionRecord) -> IELTSWritingTaskMode {
        let p1 = record.part1EssayText.trimmingCharacters(in: .whitespacesAndNewlines)
        let p2 = record.part2EssayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p1.isEmpty && p2.isEmpty {
            return .academicTask1
        } else if p1.isEmpty && !p2.isEmpty {
            return .writingTask2
        } else if !p1.isEmpty && !p2.isEmpty {
            return .fullMockExam
        }
        if record.examTitle.localizedCaseInsensitiveContains("Task 2") || record.examTitle.hasPrefix("T2") {
            return .writingTask2
        }
        return .academicTask1
    }

    // MARK: - 2. Official IELTS Band Rounding (May 2023 Official Specification)

    /// Official IELTS Overall Writing Band rounding:
    /// Average of 4 criteria rounded to nearest 0.5:
    /// .25 -> .5, .75 -> next whole band, .125 -> .0, .625 -> .5
    public static func roundToOfficialIELTSBand(_ value: Double) -> Double {
        let clamped = min(9.0, max(0.0, value))
        let fractional = clamped - floor(clamped)
        let base = floor(clamped)
        if fractional < 0.25 {
            return base
        } else if fractional < 0.75 {
            return base + 0.5
        } else {
            return min(9.0, base + 1.0)
        }
    }

    public static func roundCriterionBand(_ value: Double) -> Double {
        let clamped = min(9.0, max(0.0, value))
        return (clamped * 2.0).rounded() / 2.0
    }

    // MARK: - 3. Official Band Descriptors Lookup (Updated May 2023)

    public static func officialTask1TADescriptor(forBand band: Int) -> String {
        switch max(0, min(9, band)) {
        case 9:
            return "Band 9 (TA): All the requirements of the task are fully and appropriately satisfied. There may be extremely rare lapses in content."
        case 8:
            return "Band 8 (TA): The response Relevantly and sufficiently covers all the requirements of the task. Key features are skilfully selected, and clearly presented, highlighted and illustrated."
        case 7:
            return "Band 7 (TA): The response covers the requirements of the task. It presents a clear overview, the data are appropriately categorised, and main trends or differences are identified. Key features are covered and clearly highlighted, but could be more fully or more accurately illustrated."
        case 6:
            return "Band 6 (TA): The response focuses on the requirements of the task and an appropriate format is used. A relevant overview is attempted. Information is appropriately selected and supported using figures/data. Some irrelevant, inappropriate or inaccurate information may occur, or some details may be missing or excessive."
        case 5:
            return "Band 5 (TA): The response generally addresses the requirements of the task; the format may be inappropriate in places. Key features which are selected are not adequately covered. The recounting of detail is mainly mechanical (no clear overview / tendency to focus on details without referring to the bigger picture). There may be no data to support the description."
        case 4:
            return "Band 4 (TA): The response is an attempt to address the task. Few key features have been selected. The format may be inappropriate. Key features that are presented may be irrelevant, repetitive, inaccurate or inappropriate."
        case 3:
            return "Band 3 (TA): The response does not address the requirements of the task (possibly because of misunderstanding of the data/diagram/situation). Key features which are presented may be largely irrelevant. Limited information is presented, and this may be used repetitively."
        case 2:
            return "Band 2 (TA): The content barely relates to the task."
        case 1:
            return "Band 1 (TA): Responses of 20 words or fewer are rated at Band 1. The content is wholly unrelated to the task. Any copied rubric must be discounted."
        default:
            return "Band 0 (TA): Should only be used where a candidate did not attend or attempt the question in any way."
        }
    }

    public static func officialTask2TRDescriptor(forBand band: Int) -> String {
        switch max(0, min(9, band)) {
        case 9:
            return "Band 9 (TR): The prompt is appropriately addressed and explored in depth. A clear and fully developed position is presented which directly answers the question/s. Ideas are relevant, fully extended and well supported."
        case 8:
            return "Band 8 (TR): The prompt is appropriately and sufficiently addressed. A clear and well-developed position is presented in response to the question/s. Ideas are relevant, well extended and supported."
        case 7:
            return "Band 7 (TR): The main parts of the prompt are appropriately addressed. A clear and developed position is presented. Main ideas are extended and supported, but there may be a tendency to over-generalise or there may be a lack of focus and precision in supporting ideas/material."
        case 6:
            return "Band 6 (TR): The main parts of the prompt are addressed (though some may be more fully covered than others). An appropriate format is used. A position is presented that is directly relevant to the prompt, although the conclusions drawn may be unclear, unjustified or repetitive. Main ideas are relevant, but some may be insufficiently developed or may lack clarity."
        case 5:
            return "Band 5 (TR): The main parts of the prompt are incompletely addressed. The format may be inappropriate in places. The writer expresses a position, but the development is not always clear. Some main ideas are put forward, but they are limited and are not sufficiently developed and/or there may be irrelevant detail."
        case 4:
            return "Band 4 (TR): The prompt is tackled in a minimal way, or the answer is tangential, possibly due to some misunderstanding of the prompt. A position is discernible, but the reader has to read carefully to find it. Main ideas are difficult to identify and may be repetitive, irrelevant or not well supported."
        case 3:
            return "Band 3 (TR): No part of the prompt is adequately addressed, or the prompt has been misunderstood. No relevant position can be identified, and/or there is little direct response to the question/s."
        case 2:
            return "Band 2 (TR): The content barely relates to the prompt. No position can be identified."
        case 1:
            return "Band 1 (TR): Responses of 20 words or fewer are rated at Band 1. The content is wholly unrelated to the prompt. Any copied rubric must be discounted."
        default:
            return "Band 0 (TR): Should only be used where a candidate did not attend or attempt the question in any way."
        }
    }

    public static func officialCCDescriptor(forBand band: Int) -> String {
        switch max(0, min(9, band)) {
        case 9:
            return "Band 9 (CC): The message can be followed effortlessly. Cohesion is used in such a way that it very rarely attracts attention. Any minimal lapses in coherence or cohesion are unintentional. Paragraphing is skilfully managed."
        case 8:
            return "Band 8 (CC): The message can be followed with ease. Information and ideas are logically sequenced, and cohesion is well managed. Occasional lapses in coherence and cohesion may occur. Paragraphing is used sufficiently and appropriately."
        case 7:
            return "Band 7 (CC): Information and ideas are logically organised, and there is a clear progression throughout the response. A range of cohesive devices including reference and substitution is used flexibly but with some inaccuracies or some over/under use. Paragraphing is generally used effectively to support overall coherence."
        case 6:
            return "Band 6 (CC): Information and ideas are generally arranged coherently and there is a clear overall progression. Cohesive devices are used to some good effect but cohesion within and/or between sentences may be faulty or mechanical due to misuse, overuse or omission. Paragraphing may not always be logical."
        case 5:
            return "Band 5 (CC): Organisation is evident but is not wholly logical and there may be a lack of overall progression. The relationship of ideas can be followed but the sentences are not fluently linked to each other. There may be limited/overuse of cohesive devices with some inaccuracy. Paragraphing may be inadequate or missing."
        case 4:
            return "Band 4 (CC): Information and ideas are evident, but not arranged coherently and there is no clear progression within the response. Relationships between ideas can be unclear and/or inadequately marked. There is some use of basic cohesive devices, which may be inaccurate or repetitive. There is inaccurate use or a lack of substitution or referencing. There may be no paragraphing and/or no clear main topic within paragraphs."
        default:
            return "Band ≤3 (CC): There is no apparent logical organisation. Ideas are discernible but difficult to relate to each other."
        }
    }

    public static func officialLRDescriptor(forBand band: Int) -> String {
        switch max(0, min(9, band)) {
        case 9:
            return "Band 9 (LR): Full flexibility and precise use are widely evident. A wide range of vocabulary is used accurately and appropriately with very natural and sophisticated control of lexical features. Minor errors in spelling and word formation are extremely rare."
        case 8:
            return "Band 8 (LR): A wide resource is fluently and flexibly used to convey precise meanings. There is skilful use of uncommon and/or idiomatic items when appropriate, despite occasional inaccuracies in word choice and collocation. Occasional errors in spelling and/or word formation may occur, but have minimal impact on communication."
        case 7:
            return "Band 7 (LR): The resource is sufficient to allow some flexibility and precision. There is some ability to use less common and/or idiomatic items. An awareness of style and collocation is evident, though inappropriacies occur. There are only a few errors in spelling and/or word formation and they do not detract from overall clarity."
        case 6:
            return "Band 6 (LR): The resource is generally adequate and appropriate for the task. The meaning is generally clear in spite of a rather restricted range or a lack of precision in word choice. The writer has some control of word formation and/or spelling, and errors do not impede communication."
        case 5:
            return "Band 5 (LR): The resource is limited but minimally adequate for the task. Simple vocabulary may be used accurately but the range does not permit much variation in expression. There may be frequent lapses in the appropriacy of word choice and a lack of flexibility is apparent in frequent simplifications and/or repetitions. Errors in spelling and/or word formation may be noticeable and may cause some difficulty for the reader."
        case 4:
            return "Band 4 (LR): The resource is limited and inadequate for or unrelated to the task. Vocabulary is basic and may be used repetitively. Control of word formation and/or spelling is weak, and errors may impede meaning."
        default:
            return "Band ≤3 (LR): The resource is inadequate with possible over-dependence on input material or memorised language."
        }
    }

    public static func officialGRADescriptor(forBand band: Int) -> String {
        switch max(0, min(9, band)) {
        case 9:
            return "Band 9 (GRA): A wide range of structures is used with full flexibility and control. Punctuation and grammar are used appropriately throughout. Minor errors are extremely rare and have minimal impact on communication."
        case 8:
            return "Band 8 (GRA): A wide range of structures is flexibly and accurately used. The majority of sentences are error-free, and punctuation is well managed. Occasional, non-systematic errors and inappropriacies occur, but have minimal impact on communication."
        case 7:
            return "Band 7 (GRA): A variety of complex structures is used with some flexibility and accuracy. Grammar and punctuation are generally well controlled, and error-free sentences are frequent. A few errors in grammar may persist, but these do not impede communication."
        case 6:
            return "Band 6 (GRA): A mix of simple and complex sentence forms is used but flexibility is limited. Examples of more complex structures are not marked by the same level of accuracy as in simple structures. Errors in grammar and punctuation occur, but rarely impede communication."
        case 5:
            return "Band 5 (GRA): The range of structures is limited and rather repetitive. Although complex sentences are attempted, they tend to be faulty, and the greatest accuracy is achieved on simple sentences. Grammatical errors may be frequent and cause some difficulty for the reader. Punctuation may be faulty."
        case 4:
            return "Band 4 (GRA): A very limited range of structures is used. Subordinate clauses are rare and simple sentences predominate. Some structures are produced accurately but grammatical errors are frequent and may impede meaning."
        default:
            return "Band ≤3 (GRA): Sentence forms are attempted, but errors in grammar and punctuation predominate and distort the meaning."
        }
    }

    // MARK: - 4. Full Audit & Deterministic Official Rubric Evaluation

    public static func audit(record: WritingSubmissionRecord, question: Task1QuestionItem) -> IELTSRubricAuditReport {
        let mode = detectTaskMode(for: record)
        let activeText: String
        let promptReference: String
        switch mode {
        case .academicTask1:
            activeText = record.part1EssayText.trimmingCharacters(in: .whitespacesAndNewlines)
            promptReference = question.promptText
        case .writingTask2:
            activeText = record.part2EssayText.trimmingCharacters(in: .whitespacesAndNewlines)
            promptReference = question.companionTask2Prompt ?? question.promptText
        case .fullMockExam:
            activeText = (record.part1EssayText + "\n\n" + record.part2EssayText).trimmingCharacters(in: .whitespacesAndNewlines)
            promptReference = question.promptText + " " + (question.companionTask2Prompt ?? "")
        }

        let words = extractWords(from: activeText)
        let rawWordCount = words.count
        let copiedWordCount = countCopiedRubricWords(essayWords: words, promptText: promptReference)
        let effectiveWordCount = max(0, rawWordCount - copiedWordCount)

        let paragraphs = activeText
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let paragraphCount = paragraphs.count

        let sentences = splitSentences(from: activeText)
        let sentenceCount = max(1, sentences.count)
        let avgSentenceLen = Double(rawWordCount) / Double(sentenceCount)

        let complexCount = sentences.filter { isComplexSentence($0) }.count
        let complexRatio = Double(complexCount) / Double(sentenceCount)
        let mattr = computeMATTR(words: words.map { $0.lowercased() })
        let misspelled = findSpellingErrors(in: activeText)
        let mechanicalLinkers = countMechanicalLinkers(in: sentences)

        // Task 1 specific checks
        let p1Text = (mode == .writingTask2) ? activeText : record.part1EssayText
        let hasOverview = detectTask1Overview(in: p1Text)
        let hasDataFigures = detectDataFigures(in: p1Text, category: question.category)
        let hasPersonalOpinion = detectPersonalOpinionInTask1(in: p1Text)
        let checklist = (mode == .writingTask2) ? [] : buildTask1KeyPointChecklist(essay: p1Text, question: question, hasOverview: hasOverview, hasDataFigures: hasDataFigures, hasPersonalOpinion: hasPersonalOpinion)

        // Task 2 specific checks
        let p2Text = (mode == .academicTask1) ? activeText : record.part2EssayText
        let hasClearPosition = detectTask2ClearPosition(in: p2Text)

        // Official Negative-Feature Hard Band Caps (May 2023 Rubric)
        var hardCaps: [String: Double] = [:]
        var capReasons: [String] = []

        if effectiveWordCount <= 20 {
            hardCaps["TA_TR"] = 1.0
            hardCaps["CC"] = 1.0
            hardCaps["LR"] = 1.0
            hardCaps["GRA"] = 1.0
            capReasons.append("官方规则 (Band 1 限制)：去除照搬题干后有效词数 ≤ 20 词，四项均封顶 Band 1.0。")
        } else {
            if copiedWordCount >= 12 {
                capReasons.append("官方规则 (Discount Copied Rubric)：检测到连续照搬题干 \(copiedWordCount) 词，已从有效字数中扣除（有效词数 \(effectiveWordCount) 词）。")
            }

            if mode == .academicTask1 || mode == .fullMockExam {
                let p1Effective = mode == .academicTask1 ? effectiveWordCount : max(0, record.part1WordCount - countCopiedRubricWords(essayWords: extractWords(from: record.part1EssayText), promptText: question.promptText))
                if !hasOverview {
                    hardCaps["TA_TR"] = min(hardCaps["TA_TR"] ?? 9.0, 5.5)
                    capReasons.append("Task 1 官方评分限制 (Band 5 Negative Feature)：未检测到清晰的总体趋势/阶段概述 (Overview)，根据官方评分标准 TA 无法达到 Band 6–7（封顶 5.5）。")
                }
                if !hasDataFigures && (question.category == .lineGraph || question.category == .barChart || question.category == .pieChart || question.category == .table) {
                    hardCaps["TA_TR"] = min(hardCaps["TA_TR"] ?? 9.0, 5.0)
                    capReasons.append("Task 1 官方评分限制 (Band 5 Negative Feature)：数据类图表缺乏具体数字/百分比支撑（\"There may be no data to support the description\"），TA 封顶 Band 5.0。")
                }
                if hasPersonalOpinion && mode == .academicTask1 {
                    hardCaps["TA_TR"] = min(hardCaps["TA_TR"] ?? 9.0, 6.0)
                    capReasons.append("Task 1 学术规范提醒：小作文为客观信息传递报告，不应包含个人主观议论（如 I think / in my opinion / should），已限制 TA 评分。")
                }
                if p1Effective < 100 {
                    hardCaps["TA_TR"] = min(hardCaps["TA_TR"] ?? 9.0, 5.0)
                    capReasons.append("Task 1 字数严重不足：有效词数 \(p1Effective) 词（远低于建议 150 词），关键特征未能充分涵盖，TA 封顶 Band 5.0。")
                } else if p1Effective < 145 {
                    hardCaps["TA_TR"] = min(hardCaps["TA_TR"] ?? 9.0, 6.0)
                    capReasons.append("Task 1 字数未达 150 词基准（当前有效词数 \(p1Effective) 词），影响关键特征展开充分度，TA 封顶 Band 6.0。")
                }
            }

            if mode == .writingTask2 || mode == .fullMockExam {
                let p2Effective = mode == .writingTask2 ? effectiveWordCount : max(0, record.part2WordCount - countCopiedRubricWords(essayWords: extractWords(from: record.part2EssayText), promptText: question.companionTask2Prompt ?? ""))
                if !hasClearPosition {
                    hardCaps["TA_TR"] = min(hardCaps["TA_TR"] ?? 9.0, 5.5)
                    capReasons.append("Task 2 官方评分限制 (Band 5/6 TR)：未检测到明确且贯穿全文的立场或结论回应，TR 封顶 Band 5.5。")
                }
                if p2Effective < 160 {
                    hardCaps["TA_TR"] = min(hardCaps["TA_TR"] ?? 9.0, 5.0)
                    capReasons.append("Task 2 字数严重不足：有效词数 \(p2Effective) 词（远低于建议 250 词），论点展开受限，TR 封顶 Band 5.0。")
                } else if p2Effective < 240 {
                    hardCaps["TA_TR"] = min(hardCaps["TA_TR"] ?? 9.0, 6.0)
                    capReasons.append("Task 2 字数未达 250 词基准（当前有效词数 \(p2Effective) 词），TR 封顶 Band 6.0。")
                }
            }

            if paragraphCount <= 1 {
                hardCaps["CC"] = min(hardCaps["CC"] ?? 9.0, 5.0)
                capReasons.append("CC 官方评分限制 (Band 5 Negative Feature)：全文未分段（\"Paragraphing may be inadequate or missing\"），CC 封顶 Band 5.0。")
            } else if paragraphCount == 2 {
                hardCaps["CC"] = min(hardCaps["CC"] ?? 9.0, 6.0)
                capReasons.append("CC 分段结构不充分：全文仅 2 段，建议 Task 1 采用 3–4 段、Task 2 采用 4–5 段结构，CC 封顶 Band 6.0。")
            }

            let spellingErrorRatePer100 = Double(misspelled.count) / Double(max(1, rawWordCount)) * 100.0
            if spellingErrorRatePer100 > 6.0 {
                hardCaps["LR"] = min(hardCaps["LR"] ?? 9.0, 5.0)
                capReasons.append("LR 拼写准确度限制：每百词拼写错误达 \(String(format: "%.1f", spellingErrorRatePer100)) 处，影响阅读理解，LR 封顶 Band 5.0。")
            } else if spellingErrorRatePer100 > 3.5 {
                hardCaps["LR"] = min(hardCaps["LR"] ?? 9.0, 6.0)
                capReasons.append("LR 拼写错误提醒：检测到 \(misspelled.count) 处拼写疑问词（\(misspelled.prefix(5).joined(separator: ", "))），LR 封顶 Band 6.0。")
            }

            if complexRatio < 0.22 {
                hardCaps["GRA"] = min(hardCaps["GRA"] ?? 9.0, 5.0)
                capReasons.append("GRA 句式多样性限制：复合句占比仅 \(Int(complexRatio * 100))%，以简单句为主（Band 4/5 特征），GRA 封顶 Band 5.0。")
            }
        }

        // Compute base criterion scores before hard caps
        var taTrScore: Double = 6.5
        if mode == .academicTask1 {
            let passedRatio = checklist.isEmpty ? 0.7 : Double(checklist.filter(\.passed).count) / Double(checklist.count)
            taTrScore = 5.0 + passedRatio * 2.5
            if hasOverview && hasDataFigures && effectiveWordCount >= 165 {
                taTrScore += 0.5
            }
        } else if mode == .writingTask2 {
            taTrScore = 5.5 + (hasClearPosition ? 1.0 : 0.0) + (effectiveWordCount >= 265 ? 0.5 : 0.0) + (paragraphCount >= 4 ? 0.5 : 0.0)
        } else {
            let passedRatio = checklist.isEmpty ? 0.7 : Double(checklist.filter(\.passed).count) / Double(checklist.count)
            let t1 = 5.0 + passedRatio * 2.5
            let t2 = 5.5 + (hasClearPosition ? 1.0 : 0.0) + (record.part2WordCount >= 250 ? 0.5 : 0.0)
            taTrScore = (t1 + t2 * 2.0) / 3.0
        }

        var ccScore: Double = 6.0
        if paragraphCount >= 3 && paragraphCount <= 5 { ccScore += 1.0 }
        if Double(mechanicalLinkers) / Double(sentenceCount) > 0.45 {
            ccScore -= 0.5
            capReasons.append("CC 衔接自然度提醒：句首机械连接词（如 Firstly/Moreover/Furthermore）密度偏高，建议结合代词指代 (this/these/such) 与同义替换衔接。")
        } else if avgSentenceLen >= 14 && avgSentenceLen <= 26 {
            ccScore += 0.5
        }

        var lrScore: Double = 5.5 + min(2.0, max(0.0, (mattr - 0.58) * 9.0))
        if misspelled.isEmpty && rawWordCount >= 150 { lrScore += 0.5 }
        else if misspelled.count >= 3 { lrScore -= 0.5 }

        var graScore: Double = 5.0 + min(2.5, complexRatio * 3.8)
        if avgSentenceLen >= 15 && misspelled.count <= 2 { graScore += 0.5 }

        // Apply official hard caps
        if let cap = hardCaps["TA_TR"] { taTrScore = min(taTrScore, cap) }
        if let cap = hardCaps["CC"] { ccScore = min(ccScore, cap) }
        if let cap = hardCaps["LR"] { lrScore = min(lrScore, cap) }
        if let cap = hardCaps["GRA"] { graScore = min(graScore, cap) }

        let finalTATr = roundCriterionBand(taTrScore)
        let finalCC = roundCriterionBand(ccScore)
        let finalLR = roundCriterionBand(lrScore)
        let finalGRA = roundCriterionBand(graScore)
        let overall = roundToOfficialIELTSBand((finalTATr + finalCC + finalLR + finalGRA) / 4.0)

        let matchedDescriptors: [String: String] = [
            mode.firstCriterionCode: mode == .writingTask2
                ? officialTask2TRDescriptor(forBand: Int(finalTATr.rounded()))
                : officialTask1TADescriptor(forBand: Int(finalTATr.rounded())),
            "CC": officialCCDescriptor(forBand: Int(finalCC.rounded())),
            "LR": officialLRDescriptor(forBand: Int(finalLR.rounded())),
            "GRA": officialGRADescriptor(forBand: Int(finalGRA.rounded()))
        ]

        let corrections = buildDeterministicCorrections(
            sentences: sentences,
            mode: mode,
            question: question,
            misspelled: misspelled,
            hasOverview: hasOverview,
            hasDataFigures: hasDataFigures,
            hasPersonalOpinion: hasPersonalOpinion,
            hasClearPosition: hasClearPosition
        )

        let disclaimer = "【\(mode.rawValue) · 雅思官方 May 2023 评分标准引擎】已自动识别体裁并按 \(mode.firstCriterionCode) / CC / LR / GRA 四维核验（有效词数 \(effectiveWordCount) 词，段落 \(paragraphCount) 段，复合句率 \(Int(complexRatio * 100))%）。"

        let estimate = IELTSFourCriteriaEstimate(
            taskAchievementOrResponse: finalTATr,
            coherenceAndCohesion: finalCC,
            lexicalResource: finalLR,
            grammaticalRangeAndAccuracy: finalGRA,
            overallEstimatedBand: overall,
            officialDisclaimer: disclaimer,
            sentenceCorrections: corrections
        )

        return IELTSRubricAuditReport(
            detectedTaskMode: mode,
            rawWordCount: rawWordCount,
            copiedPromptWordCount: copiedWordCount,
            effectiveWordCount: effectiveWordCount,
            paragraphCount: paragraphCount,
            sentenceCount: sentenceCount,
            averageSentenceLength: avgSentenceLen,
            complexSentenceCount: complexCount,
            complexSentenceRatio: complexRatio,
            lexicalDiversityMATTR: mattr,
            spellingErrorWords: misspelled,
            mechanicalLinkerCount: mechanicalLinkers,
            hasClearOverview: hasOverview,
            hasSupportingDataFigures: hasDataFigures,
            containsInappropriatePersonalOpinion: hasPersonalOpinion,
            hasClearTask2Position: hasClearPosition,
            task1Checklist: checklist,
            hardBandCaps: hardCaps,
            capReasonsZH: capReasons,
            matchedOfficialDescriptors: matchedDescriptors,
            deterministicEstimate: estimate
        )
    }

    // MARK: - 5. Calibrate AI Score with Official Hard Caps

    public static func calibrate(
        aiEstimate: IELTSFourCriteriaEstimate,
        with audit: IELTSRubricAuditReport
    ) -> IELTSFourCriteriaEstimate {
        var taTr = aiEstimate.taskAchievementOrResponse
        var cc = aiEstimate.coherenceAndCohesion
        var lr = aiEstimate.lexicalResource
        var gra = aiEstimate.grammaticalRangeAndAccuracy

        if let cap = audit.hardBandCaps["TA_TR"] { taTr = min(taTr, cap) }
        if let cap = audit.hardBandCaps["CC"] { cc = min(cc, cap) }
        if let cap = audit.hardBandCaps["LR"] { lr = min(lr, cap) }
        if let cap = audit.hardBandCaps["GRA"] { gra = min(gra, cap) }

        taTr = roundCriterionBand(taTr)
        cc = roundCriterionBand(cc)
        lr = roundCriterionBand(lr)
        gra = roundCriterionBand(gra)

        let overall = roundToOfficialIELTSBand((taTr + cc + lr + gra) / 4.0)
        var mergedCorrections = aiEstimate.sentenceCorrections
        for item in audit.deterministicEstimate.sentenceCorrections {
            if !mergedCorrections.contains(where: { $0.originalSentence == item.originalSentence }) {
                mergedCorrections.append(item)
            }
        }

        let capSummary = audit.capReasonsZH.isEmpty ? "" : "｜已执行官方负面特征限分：" + audit.capReasonsZH.joined(separator: " ")
        return IELTSFourCriteriaEstimate(
            taskAchievementOrResponse: taTr,
            coherenceAndCohesion: cc,
            lexicalResource: lr,
            grammaticalRangeAndAccuracy: gra,
            overallEstimatedBand: overall,
            officialDisclaimer: "【\(audit.detectedTaskMode.rawValue) · 官方标准 + AI 深度联评】\(aiEstimate.officialDisclaimer)\(capSummary)",
            sentenceCorrections: mergedCorrections
        )
    }

    // MARK: - 6. Task-Specific AI System & User Prompt Builder

    public static func buildTaskAwareAIPrompt(
        record: WritingSubmissionRecord,
        question: Task1QuestionItem,
        audit: IELTSRubricAuditReport
    ) -> (systemPrompt: String, userPrompt: String) {
        let mode = audit.detectedTaskMode
        let rubricBlock: String
        switch mode {
        case .academicTask1:
            rubricBlock = """
            【重要指令：当前考生提交的是 IELTS Academic Writing Task 1（雅思学术类小作文）】
            你必须严格且唯一引用《IELTS Official Academic Writing Task 1 Band Descriptors (Updated May 2023)》进行评分！
            第一项评分维度必须是 **Task Achievement (TA · 小作文任务完成度)**，绝不能套用大作文的议论文标准！
            小作文官方核心评分规则（May 2023 版）：
            - Band 8 TA: Key features are skilfully selected, and clearly presented, highlighted and illustrated.
            - Band 7 TA: Presents a clear overview, the data are appropriately categorised, and main trends or differences are identified. Key features are covered and clearly highlighted.
            - Band 6 TA: A relevant overview is attempted. Information is appropriately selected and supported using figures/data.
            - Band 5 TA (负面封顶项): The recounting of detail is mainly mechanical with no clear overview; OR there may be no data to support the description. (若缺失 Overview 或数据类图表未引用具体数字支撑，TA 不得高于 5.0–5.5)。
            - 语域要求：小作文为客观图表/地图/流程图报告，严禁加入个人主观观点（如 I think / in my opinion / we should），若出现须在 TA 中指出并扣分。
            """
        case .writingTask2:
            rubricBlock = """
            【重要指令：当前考生提交的是 IELTS Writing Task 2（雅思大作文议论文）】
            你必须严格且唯一引用《IELTS Official Writing Task 2 Band Descriptors (Updated May 2023)》进行评分！
            第一项评分维度必须是 **Task Response (TR · 大作文任务回应度)**。
            大作文官方核心评分规则（May 2023 版）：
            - Band 8 TR: The prompt is appropriately and sufficiently addressed. A clear and well-developed position is presented. Ideas are relevant, well extended and supported.
            - Band 7 TR: The main parts of the prompt are appropriately addressed. A clear and developed position is presented. Main ideas are extended and supported (may over-generalise or lack precision in supporting material).
            - Band 6 TR: Main parts addressed (some more fully than others). A directly relevant position is presented, although conclusions may be unclear, unjustified or repetitive.
            - Band 5 TR (负面封顶项): Main parts incompletely addressed; expresses a position but development is not always clear; ideas are limited and insufficiently developed.
            """
        case .fullMockExam:
            rubricBlock = """
            【重要指令：当前考生提交的是 IELTS Academic Task 1 + Task 2 完整机考双篇】
            请对 Part 1 严格适用 Academic Task 1 标准（Task Achievement, TA），对 Part 2 严格适用 Task 2 标准（Task Response, TR），并按官方权重（Task 1 占 1/3，Task 2 占 2/3）综合计算！
            """
        }

        let systemPrompt = """
        你是深谙剑桥雅思官方《IELTS Writing Band Descriptors (Updated May 2023)》的资深雅思考官。
        \(rubricBlock)

        通用官方四维规则：
        - Coherence & Cohesion (CC): 检查逻辑推进、段落划分（未分段封顶 5.0）、衔接手段是否自然（过多机械连接词如 Firstly/Moreover 封顶 6.0）。
        - Lexical Resource (LR): 检查同义替换、学术搭配准确度及拼写错误密度。
        - Grammatical Range & Accuracy (GRA): 检查复合句多样性与无错句比例（error-free sentences are frequent 为 Band 7 必要条件）。
        - 严禁虚高给分；必须输出严格合法的 JSON 对象，结构如下：
        {
          "taskAchievementOrResponse": 6.5,
          "coherenceAndCohesion": 6.5,
          "lexicalResource": 6.5,
          "grammaticalRangeAndAccuracy": 6.5,
          "overallEstimatedBand": 6.5,
          "officialDisclaimer": "针对本篇\(mode.rawValue)的四维官方标准总评（中文）",
          "sentenceCorrections": [
            {
              "originalSentence": "原句",
              "correctedSentence": "语法与学术表达修正句",
              "explanationZH": "结合官方评分维度（\(mode.firstCriterionCode)/CC/LR/GRA）的中文诊断说明",
              "upgradedExpression": "Band 7.5+ 高分考官改写示范",
              "kind": "\(mode.firstCriterionCode) / GRA / LR / CC"
            }
          ]
        }
        """

        var chartContext = ""
        if mode != .writingTask2, let ds = question.chartDataset {
            let xLabels = ds.xAxisLabels.joined(separator: ", ")
            let seriesSummary = ds.series.map { "\($0.name) (\($0.unit)): \($0.values.map { String(format: "%.1f", $0) }.joined(separator: ", "))" }.joined(separator: " | ")
            let checklistSummary = audit.task1Checklist.map { "[\($0.passed ? "✓已覆盖" : "✗缺失")] \($0.title): \($0.detail)" }.joined(separator: "\n")
            chartContext = """
            【小作文图表标准数据集 (Task1ChartDataset)】
            题型类别：\(question.category.rawValue)
            横轴/类别：\(xLabels)
            数据序列：\(seriesSummary)
            本地图表要点核对结果：
            \(checklistSummary)
            """
        }

        let userPrompt = """
        题目标题：\(question.id) · \(question.shortTitle)
        识别到的提交类型：\(mode.rawValue)
        Task 1 题目：\(question.promptText)
        Task 2 题目：\(question.companionTask2Prompt ?? "无")
        \(chartContext)

        【本地官方规则预审指标】
        - 原始词数：\(audit.rawWordCount) 词｜扣除照搬题干词数：\(audit.copiedPromptWordCount) 词｜有效词数：\(audit.effectiveWordCount) 词
        - 段落数：\(audit.paragraphCount) 段｜句子数：\(audit.sentenceCount) 句｜复合句占比：\(Int(audit.complexSentenceRatio * 100))%
        - 词汇丰富度 (MATTR)：\(String(format: "%.2f", audit.lexicalDiversityMATTR))
        - 拼写疑问词：\(audit.spellingErrorWords.isEmpty ? "无" : audit.spellingErrorWords.joined(separator: ", "))
        - 触发的官方限分项：\(audit.capReasonsZH.isEmpty ? "无" : audit.capReasonsZH.joined(separator: "；"))

        【考生作答正文】
        \(mode == .academicTask1 ? record.part1EssayText : (mode == .writingTask2 ? record.part2EssayText : "=== Task 1 ===\n\(record.part1EssayText)\n\n=== Task 2 ===\n\(record.part2EssayText)"))
        """

        return (systemPrompt, userPrompt)
    }


    /// Enriches `Task1QuestionItem` with the detected Task Mode (Academic Task 1 TA vs Task 2 TR)
    /// and Official May 2023 IELTS Band Descriptors so any upstream LLM evaluator automatically applies
    /// the exact Task 1 or Task 2 rubric.
    public static func enrichQuestionWithOfficialRubric(
        _ question: Task1QuestionItem,
        for record: WritingSubmissionRecord,
        audit: IELTSRubricAuditReport
    ) -> Task1QuestionItem {
        let prompts = buildTaskAwareAIPrompt(record: record, question: question, audit: audit)
        let combinedGuidance = prompts.systemPrompt + "\n\n" + prompts.userPrompt
        switch audit.detectedTaskMode {
        case .academicTask1:
            return Task1QuestionItem(
                id: question.id,
                shortTitle: question.shortTitle + " [Task 1 小作文 · TA 标准]",
                category: question.category,
                difficultyBand: question.difficultyBand,
                promptText: question.promptText + "\n\n" + combinedGuidance,
                minimumWords: 150,
                recommendedMinutes: 20,
                sourceName: question.sourceName,
                sourceURL: question.sourceURL,
                licenseStatus: question.licenseStatus,
                chartDataset: question.chartDataset,
                companionTask2ID: nil,
                companionTask2Prompt: nil,
                notes: combinedGuidance
            )
        case .writingTask2:
            return Task1QuestionItem(
                id: question.id,
                shortTitle: question.shortTitle + " [Task 2 大作文 · TR 标准]",
                category: question.category,
                difficultyBand: question.difficultyBand,
                promptText: question.promptText,
                minimumWords: 250,
                recommendedMinutes: 40,
                sourceName: question.sourceName,
                sourceURL: question.sourceURL,
                licenseStatus: question.licenseStatus,
                chartDataset: question.chartDataset,
                companionTask2ID: question.companionTask2ID ?? "T2",
                companionTask2Prompt: (question.companionTask2Prompt ?? "") + "\n\n" + combinedGuidance,
                notes: combinedGuidance
            )
        case .fullMockExam:
            return Task1QuestionItem(
                id: question.id,
                shortTitle: question.shortTitle + " [Task 1 + Task 2 完整模考]",
                category: question.category,
                difficultyBand: question.difficultyBand,
                promptText: question.promptText + "\n\n" + combinedGuidance,
                minimumWords: 400,
                recommendedMinutes: 60,
                sourceName: question.sourceName,
                sourceURL: question.sourceURL,
                licenseStatus: question.licenseStatus,
                chartDataset: question.chartDataset,
                companionTask2ID: question.companionTask2ID ?? "T2",
                companionTask2Prompt: (question.companionTask2Prompt ?? "") + "\n\n" + combinedGuidance,
                notes: combinedGuidance
            )
        }
    }

    // MARK: - 7. Task 1 Chart Key Data Point Checklist Builder

    public static func buildTask1KeyPointChecklist(
        essay: String,
        question: Task1QuestionItem,
        hasOverview: Bool,
        hasDataFigures: Bool,
        hasPersonalOpinion: Bool
    ) -> [Task1KeyPointCheckItem] {
        let lower = essay.lowercased()
        var items: [Task1KeyPointCheckItem] = []

        items.append(
            Task1KeyPointCheckItem(
                title: "总体趋势/阶段概述 (Clear Overview)",
                detail: hasOverview
                    ? "已检测到清晰的总体趋势或全局概括段 (Overall / In general / main trend)"
                    : "未检测到明显的 Overview 总体概述，官方标准 Band 5 将无 Overview 列为限制项",
                passed: hasOverview,
                officialRuleNote: "Band 7 TA: Presents a clear overview, main trends or differences are identified."
            )
        )

        if let ds = question.chartDataset {
            // Check time span / xAxisLabels
            if ds.xAxisLabels.count >= 2, let firstLabel = ds.xAxisLabels.first, let lastLabel = ds.xAxisLabels.last {
                let hasStart = lower.contains(firstLabel.lowercased())
                let hasEnd = lower.contains(lastLabel.lowercased())
                items.append(
                    Task1KeyPointCheckItem(
                        title: "关键横轴/时间节点 (\(firstLabel) – \(lastLabel))",
                        detail: (hasStart && hasEnd)
                            ? "已覆盖起止节点 \(firstLabel) 与 \(lastLabel)"
                            : "建议明确交代起止维度（\(firstLabel) 至 \(lastLabel)）以体现完整区间",
                        passed: hasStart || hasEnd,
                        officialRuleNote: "Band 7 TA: Key features are covered and clearly highlighted."
                    )
                )
            }

            // Check series coverage & extrema
            if !ds.series.isEmpty {
                let mentionedSeries = ds.series.filter { series in
                    let keywords = series.name.lowercased().split(separator: " ").map(String.init).filter { $0.count >= 3 }
                    return keywords.contains { lower.contains($0) }
                }
                let allValues = ds.series.flatMap(\.values)
                let maxVal = allValues.max()
                let minVal = allValues.min()
                let hasExtrema = [maxVal, minVal].compactMap { $0 }.contains { val in
                    let intStr = String(Int(val.rounded()))
                    let decStr = String(format: "%.1f", val)
                    return lower.contains(intStr) || lower.contains(decStr)
                }
                items.append(
                    Task1KeyPointCheckItem(
                        title: "核心数据序列与极值支撑 (Key Figures & Extrema)",
                        detail: hasDataFigures
                            ? "已引用图表数据/单位，覆盖 \(mentionedSeries.count)/\(ds.series.count) 个核心序列\(hasExtrema ? "及极值点" : "")"
                            : "缺少具体图表数字/单位支撑（Band 5 Negative Feature: No data to support description）",
                        passed: hasDataFigures && (!mentionedSeries.isEmpty || hasExtrema),
                        officialRuleNote: "Band 6+ TA: Information is appropriately selected and supported using figures/data."
                    )
                )
            }

            if let map = ds.mapComparison {
                let hasYears = lower.contains(map.beforeYearLabel.lowercased()) || lower.contains(map.afterYearLabel.lowercased())
                let spatialWords = ["north", "south", "east", "west", "center", "central", "located", "replaced", "expanded", "constructed", "demolished"]
                let hasSpatial = spatialWords.contains { lower.contains($0) }
                items.append(
                    Task1KeyPointCheckItem(
                        title: "地图题方位与前后变迁 (\(map.beforeYearLabel) vs \(map.afterYearLabel))",
                        detail: (hasYears && hasSpatial)
                            ? "已结合方位词描述 \(map.beforeYearLabel) 至 \(map.afterYearLabel) 的空间改造"
                            : "地图题需使用方位词 (north/south/west/east) 对比改造前后的新增、扩建与移除区域",
                        passed: hasYears && hasSpatial,
                        officialRuleNote: "Band 7 TA: Key spatial transformations are appropriately categorised and highlighted."
                    )
                )
            }

            if let steps = ds.processSteps, !steps.isEmpty {
                let seqWords = ["first", "initial", "subsequently", "next", "then", "followed by", "stage", "step", "finally", "eventually"]
                let seqHits = seqWords.filter { lower.contains($0) }.count
                items.append(
                    Task1KeyPointCheckItem(
                        title: "流程图阶段衔接与被动语态 (共 \(steps.count) 个阶段)",
                        detail: seqHits >= 2
                            ? "已使用阶段推进衔接词串联生产/自然流程"
                            : "流程图建议使用阶段过渡词 (Initially / Subsequently / Following this) 与被动语态完整涵盖 \(steps.count) 个步骤",
                        passed: seqHits >= 2,
                        officialRuleNote: "Band 7 TA/CC: Process stages are logically sequenced with clear progression."
                    )
                )
            }
        }

        items.append(
            Task1KeyPointCheckItem(
                title: "客观学术报告语域 (Objective Academic Register)",
                detail: hasPersonalOpinion
                    ? "检测到主观议论表达 (I think / in my opinion / should)，小作文应保持纯客观数据报告"
                    : "全文保持客观学术描述，未掺杂主观观点猜测",
                passed: !hasPersonalOpinion,
                officialRuleNote: "Academic Task 1: Factual reporting without personal opinion or speculation."
            )
        )

        return items
    }

    // MARK: - 8. Linguistic & Heuristic Helpers

    private static func extractWords(from text: String) -> [String] {
        let pattern = #"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    /// Discounts 4-gram+ sequences copied verbatim from the prompt rubric
    private static func countCopiedRubricWords(essayWords: [String], promptText: String) -> Int {
        let promptWords = extractWords(from: promptText).map { $0.lowercased() }
        let lowerEssay = essayWords.map { $0.lowercased() }
        guard lowerEssay.count >= 4, promptWords.count >= 4 else { return 0 }

        var promptFourGrams = Set<String>()
        for i in 0...(promptWords.count - 4) {
            promptFourGrams.insert(promptWords[i..<(i + 4)].joined(separator: " "))
        }

        var copiedIndices = Set<Int>()
        for i in 0...(lowerEssay.count - 4) {
            let gram = lowerEssay[i..<(i + 4)].joined(separator: " ")
            if promptFourGrams.contains(gram) {
                for k in i..<(i + 4) { copiedIndices.insert(k) }
            }
        }
        return copiedIndices.count
    }

    private static func splitSentences(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { result.append(s) }
            return true
        }
        return result
    }

    private static func isComplexSentence(_ sentence: String) -> Bool {
        let lower = " " + sentence.lowercased() + " "
        let markers = [
            " although ", " though ", " even though ", " whereas ", " while ", " whilst ",
            " because ", " since ", " unless ", " provided that ", " as long as ",
            " which ", " that ", " who ", " whose ", " where ", " whereby ",
            " if ", " whether ", " despite ", " in spite of ", " not only ",
            " compared with ", " compared to ", " in contrast to ", " resulting in "
        ]
        if markers.contains(where: { lower.contains($0) }) { return true }
        let commaCount = sentence.filter { $0 == "," || $0 == ";" }.count
        return commaCount >= 2 && sentence.split(separator: " ").count >= 16
    }

    private static func computeMATTR(words: [String], window: Int = 45) -> Double {
        guard !words.isEmpty else { return 0.0 }
        if words.count <= window {
            return Double(Set(words).count) / Double(words.count)
        }
        var ratios: [Double] = []
        for start in 0...(words.count - window) {
            let slice = words[start..<(start + window)]
            ratios.append(Double(Set(slice).count) / Double(window))
        }
        return ratios.reduce(0.0, +) / Double(ratios.count)
    }

    private static func findSpellingErrors(in text: String) -> [String] {
        #if canImport(AppKit)
        let checker = NSSpellChecker.shared
        var errors: [String] = []
        let words = extractWords(from: text)
        for w in words {
            if w.count <= 2 || w.allSatisfy({ $0.isNumber || $0.isUppercase }) || w.contains(where: \.isNumber) {
                continue
            }
            let range = checker.checkSpelling(of: w, startingAt: 0, language: "en_GB", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
            if range.location != NSNotFound {
                let usRange = checker.checkSpelling(of: w, startingAt: 0, language: "en_US", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
                if usRange.location != NSNotFound && !errors.contains(w) {
                    errors.append(w)
                }
            }
        }
        return errors
        #else
        return []
        #endif
    }

    private static func countMechanicalLinkers(in sentences: [String]) -> Int {
        let mechanicalStarts = [
            "firstly,", "secondly,", "thirdly,", "fourthly,", "lastly,", "last but not least",
            "moreover,", "furthermore,", "in addition,", "besides,", "on the one hand", "on the other hand",
            "in conclusion,", "to sum up,"
        ]
        return sentences.filter { s in
            let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return mechanicalStarts.contains { lower.hasPrefix($0) }
        }.count
    }

    private static func detectTask1Overview(in text: String) -> Bool {
        let lower = text.lowercased()
        let overviewSignals = [
            "overall", "in general", "generally speaking", "broadly speaking",
            "as can be seen", "as is clear", "it is clear that", "it is noticeable that",
            "the main trend", "main trends", "in summary", "to summarise", "to summarize",
            "at first glance", "the most striking feature"
        ]
        return overviewSignals.contains { lower.contains($0) }
    }

    private static func detectDataFigures(in text: String, category: Task1ChartCategory) -> Bool {
        if category == .map || category == .processDiagram {
            return true
        }
        let digitMatches = text.filter(\.isNumber).count
        let numberWords = ["percent", "percentage", "quarter", "half", "third", "double", "triple", "fold", "majority", "minority", "million", "billion"]
        let lower = text.lowercased()
        return digitMatches >= 3 || numberWords.filter { lower.contains($0) }.count >= 2
    }

    private static func detectPersonalOpinionInTask1(in text: String) -> Bool {
        let lower = " " + text.lowercased() + " "
        let opinionMarkers = [
            " i think ", " i believe ", " in my opinion", " from my perspective",
            " in my view", " i agree ", " i disagree ", " we should ", " governments should ",
            " people ought to ", " personally,"
        ]
        return opinionMarkers.contains { lower.contains($0) }
    }

    private static func detectTask2ClearPosition(in text: String) -> Bool {
        let lower = " " + text.lowercased() + " "
        let positionMarkers = [
            " i believe ", " i argue ", " in my view", " in my opinion", " this essay argues",
            " this essay will ", " i agree ", " i disagree ", " in conclusion", " to conclude",
            " overall, ", " therefore, ", " it seems to me ", " from my perspective"
        ]
        return positionMarkers.contains { lower.contains($0) }
    }

    private static func buildDeterministicCorrections(
        sentences: [String],
        mode: IELTSWritingTaskMode,
        question: Task1QuestionItem,
        misspelled: [String],
        hasOverview: Bool,
        hasDataFigures: Bool,
        hasPersonalOpinion: Bool,
        hasClearPosition: Bool
    ) -> [IELTSFourCriteriaEstimate.SentenceCorrectionItem] {
        var items: [IELTSFourCriteriaEstimate.SentenceCorrectionItem] = []

        if (mode == .academicTask1 || mode == .fullMockExam) && !hasOverview, let first = sentences.first {
            items.append(
                .init(
                    originalSentence: first,
                    correctedSentence: first + " Overall, it is clear that the most significant shift occurred across the primary categories over the period shown.",
                    explanationZH: "【Task 1 · TA 官方核心要求】小作文 Band 7 要求提供清晰的总体概述 (Clear Overview)。建议在首段改写题干后紧接一段以 Overall, it is clear that... 开头的总体趋势/全局特征段。",
                    upgradedExpression: "Overall, a clear upward/downward trajectory can be observed, with [Category A] witnessing the most pronounced change.",
                    kind: "TA (Overview)"
                )
            )
        }

        if (mode == .academicTask1 || mode == .fullMockExam) && !hasDataFigures, let target = sentences.dropFirst().first ?? sentences.first {
            items.append(
                .init(
                    originalSentence: target,
                    correctedSentence: target + " Specifically, the figure rose from [X] to [Y] over the period.",
                    explanationZH: "【Task 1 · TA 官方负面特征预警】小作文 Band 5 明确指出“There may be no data to support the description”。描述趋势时必须引用具体数值、百分比或年份支撑。",
                    upgradedExpression: "Specifically, this figure stood at [X] in the initial year before surging to a peak of [Y] by the end of the period.",
                    kind: "TA (Data Support)"
                )
            )
        }

        if mode == .academicTask1 && hasPersonalOpinion,
           let opinionSentence = sentences.first(where: { detectPersonalOpinionInTask1(in: $0) }) {
            let cleaned = opinionSentence
                .replacingOccurrences(of: "I think ", with: "The data indicate that ", options: .caseInsensitive)
                .replacingOccurrences(of: "In my opinion, ", with: "Notably, ", options: .caseInsensitive)
            items.append(
                .init(
                    originalSentence: opinionSentence,
                    correctedSentence: cleaned,
                    explanationZH: "【Task 1 · TA 语域规范】雅思学术类小作文属于客观图表信息报告，不应出现个人主观论断或建议（I think / in my opinion / should），应改为客观数据陈述。",
                    upgradedExpression: "The chart clearly illustrates that... / It is noteworthy from the figures that...",
                    kind: "TA (Register)"
                )
            )
        }

        if (mode == .writingTask2 || mode == .fullMockExam) && !hasClearPosition, let last = sentences.last {
            items.append(
                .init(
                    originalSentence: last,
                    correctedSentence: "In conclusion, I firmly believe that a balanced approach is essential, and the benefits of this policy far outweigh its drawbacks.",
                    explanationZH: "【Task 2 · TR 官方核心要求】大作文 Band 7 要求全文呈现清晰且充分展开的立场 (a clear and developed position)。建议在引言段结尾与结论段明确亮出核心观点。",
                    upgradedExpression: "In conclusion, while there are valid concerns regarding..., I contend that...",
                    kind: "TR (Position)"
                )
            )
        }

        for wrongWord in misspelled.prefix(3) {
            if let s = sentences.first(where: { $0.contains(wrongWord) }) {
                #if canImport(AppKit)
                let guesses = NSSpellChecker.shared.guesses(forWordRange: NSRange(location: 0, length: wrongWord.utf16.count), in: wrongWord, language: "en_GB", inSpellDocumentWithTag: 0) ?? []
                let replacement = guesses.first ?? wrongWord
                #else
                let replacement = wrongWord
                #endif
                let fixed = s.replacingOccurrences(of: wrongWord, with: replacement)
                items.append(
                    .init(
                        originalSentence: s,
                        correctedSentence: fixed,
                        explanationZH: "【LR · 词汇与拼写准确性】检测到拼写疑问词「\(wrongWord)」，建议核对为「\(replacement)」，减少因拼写失误导致的 LR 扣分。",
                        upgradedExpression: fixed,
                        kind: "LR (Spelling)"
                    )
                )
            }
        }

        if items.isEmpty, let longest = sentences.max(by: { $0.count < $1.count }) {
            items.append(
                .init(
                    originalSentence: longest,
                    correctedSentence: longest,
                    explanationZH: "【GRA & LR 进阶润色建议】当前句子结构完整。若冲刺 Band 7.5+，可进一步使用分词短语、定语从句或名词化结构提升学术紧凑度。",
                    upgradedExpression: longest,
                    kind: "GRA / LR"
                )
            )
        }

        return items
    }
}

// MARK: - Word-Level Red/Green Inline Diff View (Point 3 Deep Review)

public struct WritingInlineDiffView: View {
    public enum TokenOp: Equatable, Sendable {
        case unchanged(String)
        case deleted(String)
        case inserted(String)
    }

    public let originalText: String
    public let revisedText: String
    public let fontSize: CGFloat

    public init(originalText: String, revisedText: String, fontSize: CGFloat = 13.5) {
        self.originalText = originalText
        self.revisedText = revisedText
        self.fontSize = fontSize
    }

    public static func computeWordDiff(original: String, revised: String) -> [TokenOp] {
        let a = original.split(whereSeparator: \.isWhitespace).map(String.init)
        let b = revised.split(whereSeparator: \.isWhitespace).map(String.init)
        let n = a.count
        let m = b.count
        if n == 0 && m == 0 { return [] }
        if n == 0 { return b.map { .inserted($0) } }
        if m == 0 { return a.map { .deleted($0) } }

        // Guard large inputs to keep UI instant
        if n * m > 160_000 {
            if original == revised { return a.map { .unchanged($0) } }
            return a.map { .deleted($0) } + b.map { .inserted($0) }
        }

        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if a[i] == b[j] {
                    dp[i][j] = 1 + dp[i + 1][j + 1]
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        var ops: [TokenOp] = []
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] {
                ops.append(.unchanged(a[i]))
                i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                ops.append(.deleted(a[i]))
                i += 1
            } else {
                ops.append(.inserted(b[j]))
                j += 1
            }
        }
        while i < n { ops.append(.deleted(a[i])); i += 1 }
        while j < m { ops.append(.inserted(b[j])); j += 1 }
        return ops
    }

    public var body: some View {
        let ops = Self.computeWordDiff(original: originalText, revised: revisedText)
        let attributed: AttributedString = {
            var result = AttributedString()
            for (idx, op) in ops.enumerated() {
                let prefix = idx == 0 ? "" : " "
                switch op {
                case .unchanged(let w):
                    var part = AttributedString(prefix + w)
                    part.font = .system(size: fontSize, design: .serif)
                    result.append(part)
                case .deleted(let w):
                    var part = AttributedString(prefix + w)
                    part.font = .system(size: fontSize, design: .serif)
                    part.foregroundColor = .red
                    part.strikethroughStyle = .single
                    part.backgroundColor = Color.red.opacity(0.12)
                    result.append(part)
                case .inserted(let w):
                    var part = AttributedString(prefix + w)
                    part.font = .system(size: fontSize, weight: .semibold, design: .serif)
                    part.foregroundColor = .green
                    part.backgroundColor = Color.green.opacity(0.14)
                    result.append(part)
                }
            }
            return result
        }()

        Text(attributed)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Task 1 Key Point Checklist & Official Rubric Diagnostic Card View

public struct IELTSOfficialRubricDiagnosticCardView: View {
    @Environment(\.studyAppearance) private var appearance
    public let audit: IELTSRubricAuditReport

    public init(audit: IELTSRubricAuditReport) {
        self.audit = audit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(appearance.accent)
                Text("雅思官方评分标准自动核验 · \(audit.detectedTaskMode.rawValue)")
                    .lumaFont(size: 14, weight: .bold)
                    .foregroundStyle(appearance.ink)
                Spacer()
                Text("第一维度：\(audit.detectedTaskMode.firstCriterionFullTitle)")
                    .lumaFont(size: 12, weight: .semibold)
                    .foregroundStyle(appearance.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(appearance.selected))
            }

            HStack(spacing: 16) {
                metricPill("有效词数", "\(audit.effectiveWordCount) 词\(audit.copiedPromptWordCount > 0 ? " (-照搬\(audit.copiedPromptWordCount))" : "")")
                metricPill("段落结构", "\(audit.paragraphCount) 段 / \(audit.sentenceCount) 句")
                metricPill("复合句率", "\(Int(audit.complexSentenceRatio * 100))%")
                metricPill("词汇多样性", String(format: "MATTR %.2f", audit.lexicalDiversityMATTR))
                metricPill("拼写疑问", "\(audit.spellingErrorWords.count) 处")
            }

            if !audit.capReasonsZH.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(audit.capReasonsZH, id: \.self) { reason in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(reason)
                                .lumaFont(size: 12)
                                .foregroundStyle(appearance.ink.opacity(0.9))
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
            }

            if !audit.task1Checklist.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("小作文 (Task 1) 图表核心要点覆盖清单")
                        .lumaFont(size: 12.5, weight: .semibold)
                        .foregroundStyle(appearance.ink.opacity(0.85))
                    ForEach(audit.task1Checklist) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: item.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(item.passed ? .green : .red)
                                .lumaFont(size: 13)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .lumaFont(size: 12.5, weight: .semibold)
                                    .foregroundStyle(appearance.ink)
                                Text(item.detail)
                                    .lumaFont(size: 11.5)
                                    .foregroundStyle(appearance.ink.opacity(0.75))
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(appearance.paper.opacity(0.55)))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("匹配的剑桥雅思官方 Band Descriptors (May 2023)：")
                    .lumaFont(size: 11.5, weight: .semibold)
                    .foregroundStyle(appearance.ink.opacity(0.75))
                ForEach([audit.detectedTaskMode.firstCriterionCode, "CC", "LR", "GRA"], id: \.self) { key in
                    if let desc = audit.matchedOfficialDescriptors[key] {
                        Text("• " + desc)
                            .lumaFont(size: 11, design: .serif)
                            .foregroundStyle(appearance.ink.opacity(0.72))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(appearance.paper.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(appearance.line, lineWidth: 1))
        )
    }

    private func metricPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).lumaFont(size: 10.5).foregroundStyle(appearance.ink.opacity(0.6))
            Text(value).lumaFont(size: 12, weight: .semibold).foregroundStyle(appearance.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(appearance.surface))
    }
}
