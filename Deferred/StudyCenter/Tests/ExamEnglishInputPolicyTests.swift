import Testing
@testable import LumaReaderStudyKit

@Suite("Exam English input policy")
struct ExamEnglishInputPolicyTests {
    @Test func preservesMisspellingsAndAsciiPunctuation() {
        let policy = ExamEnglishInputPolicy()
        #expect(policy.validateReplacement("teh enviroment, don't fix it!") == .allowVerbatim)
        #expect(policy.validateReplacement(#"\|{}"#) == .allowVerbatim)
        #expect(policy.validateReplacement("Paragraph 1.\n\nParagraph 2.") == .allowVerbatim)
        #expect(policy.validateReplacement("") == .allowVerbatim)
    }

    @Test func rejectsCJKWithoutChangingTheAnswer() {
        let policy = ExamEnglishInputPolicy()
        guard case .rejectEntirely(let reason, _) = policy.validateReplacement("hello中文") else {
            Issue.record("Mixed-script replacement must be rejected atomically")
            return
        }
        #expect(reason == .containsCJKCharacters)
    }

    @Test func rejectsFullWidthPunctuation() {
        let policy = ExamEnglishInputPolicy()
        for sample in ["Hello，world", "“quoted”", "don’t"] {
            guard case .rejectEntirely(let reason, _) = policy.validateReplacement(sample) else {
                Issue.record("Full-width punctuation should not enter exam answers")
                return
            }
            #expect(reason == .containsFullWidthPunctuation)
        }
    }

    @Test func leavesOrdinaryBookAndChatInputUnrestricted() {
        #expect(!EditorInputScope.bookReaderAnnotation.requiresStrictExamEnglishMode)
        #expect(!EditorInputScope.aiCompanionChat.requiresStrictExamEnglishMode)
        #expect(EditorInputScope.ieltsWritingFullMockExam.requiresStrictExamEnglishMode)
    }
}
