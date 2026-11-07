import Testing
@testable import LumaReaderStudyKit

@Suite("Exam English input policy")
struct ExamEnglishInputPolicyTests {
    @Test func preservesMisspellingsAndAsciiPunctuation() {
        let policy = ExamEnglishInputPolicy()
        #expect(policy.validateReplacement("teh enviroment, don't fix it!") == .allowVerbatim)
        #expect(policy.validateReplacement("\\|{}") == .allowVerbatim)
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
        guard case .rejectEntirely(let reason, _) = policy.validateReplacement("Hello，world") else {
            Issue.record("Full-width punctuation should not enter exam answers")
            return
        }
        #expect(reason == .containsFullWidthPunctuation)
    }

    @Test func leavesOrdinaryBookAndChatInputUnrestricted() {
        #expect(!EditorInputScope.bookReaderAnnotation.requiresStrictExamEnglishMode)
        #expect(!EditorInputScope.aiCompanionChat.requiresStrictExamEnglishMode)
        #expect(EditorInputScope.ieltsWritingFullMockExam.requiresStrictExamEnglishMode)
    }
}
