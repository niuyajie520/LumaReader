import Testing
#if canImport(AppKit)
import AppKit
@testable import LumaReaderStudyKit

@MainActor
@Suite("Dictation presentation metrics — requires macOS")
struct DictationAnswerMetricsTests {
    @Test func shortWordUsesLargeType() {
        #expect(DictationAnswerMetrics.fittedSize(text: "apple", availableWidth: 800) == 140)
    }

    @Test func fittingUsesActualRoundedFontWidth() {
        for text in ["accommodation", "pneumonoultramicroscopicsilicovolcanoconiosis", String(repeating: "W", count: 31)] {
            for available in [CGFloat(400), 640, 1000] {
                let size = DictationAnswerMetrics.fittedSize(text: text, availableWidth: available)
                #expect(size >= 36 && size <= 140)
                if size > 36 {
                    #expect(DictationAnswerMetrics.width(text, size: size) <= available - 24)
                }
            }
        }
    }

    @Test func overflowKeepsReadableMinimumAndRequestsWrapping() {
        let text = String(repeating: "W", count: 100)
        #expect(DictationAnswerMetrics.fittedSize(text: text, availableWidth: 400) == 36)
        let headroom = 400 - DictationAnswerMetrics.width(text, size: 36)
        #expect(DictationAnswerMetrics.shouldWrap(headroom: headroom, wasWrapped: false))
    }

    @Test func deadBandsPreventSizeAndWrapOscillation() {
        #expect(DictationAnswerMetrics.settledSize(current: 80, target: 82) == 80)
        #expect(DictationAnswerMetrics.settledSize(current: 80, target: 83) == 83)
        #expect(DictationAnswerMetrics.settledSize(current: 80, target: 79.5) == 79.5)
        #expect(!DictationAnswerMetrics.shouldWrap(headroom: 30, wasWrapped: false))
        #expect(DictationAnswerMetrics.shouldWrap(headroom: 30, wasWrapped: true))
        #expect(!DictationAnswerMetrics.shouldWrap(headroom: 49, wasWrapped: true))
    }
}
#endif
