import Testing
@testable import LumaReader

struct ReaderMotionPolicyTests {
    @Test func disablingMotionAccessibilityAndLowPowerSkipPageRotation() {
        #expect(ReaderMotionPolicy.pageTurnDuration(enabled:false,reduceMotion:false,systemLowPower:false,energySaving:false) == 0)
        #expect(ReaderMotionPolicy.pageTurnDuration(enabled:true,reduceMotion:true,systemLowPower:false,energySaving:false) == 0)
    }
    @Test func readingStillHasOptionalBriefPageFeedback() {
        let regular = ReaderMotionPolicy.pageTurnDuration(enabled:true,reduceMotion:false,systemLowPower:false,energySaving:false)
        let saving = ReaderMotionPolicy.pageTurnDuration(enabled:true,reduceMotion:false,systemLowPower:false,energySaving:true)
        #expect(saving > 0)
        #expect(regular > saving)
        #expect(regular <= 0.3)
    }
    @Test func dragCanCommitOrReverseWithoutChangingReadingPositionOnCancel() {
        #expect(!ReaderMotionPolicy.commitsDrag(progress:0.15,velocity:0))
        #expect(ReaderMotionPolicy.commitsDrag(progress:0.45,velocity:0))
        #expect(ReaderMotionPolicy.commitsDrag(progress:0.10,velocity:650))
        #expect(!ReaderMotionPolicy.commitsDrag(progress:0.75,velocity:-450))
        // Readest #5288 combined distance + velocity flick commit:
        #expect(ReaderMotionPolicy.commitsDrag(progress:0.18,velocity:300))
    }
    @Test func fiveModesAndThreeSpeedsScaleDurationsCorrectly() {
        let base = 0.30
        for style in PageTurnStyle.animationCases {
            let slow = ReaderMotionPolicy.styleDuration(base: base, style: style, speedScale: PageTurnSpeed.slow.scale, motionLevel: .enhanced)
            let normal = ReaderMotionPolicy.styleDuration(base: base, style: style, speedScale: PageTurnSpeed.normal.scale, motionLevel: .enhanced)
            let fast = ReaderMotionPolicy.styleDuration(base: base, style: style, speedScale: PageTurnSpeed.fast.scale, motionLevel: .enhanced)
            let chained = ReaderMotionPolicy.styleDuration(base: base, style: style, speedScale: PageTurnSpeed.normal.scale, motionLevel: .enhanced, isChainedRapidTurn: true)
            #expect(slow > normal)
            #expect(normal > fast)
            #expect(fast > 0)
            #expect(chained <= 0.18)
        }
    }
    @Test func interactiveSettleDurationScalesByRemainingDistanceAndVelocity() {
        let slowRelease = ReaderMotionPolicy.interactiveSettleDuration(baseDuration: 0.30, currentProgress: 0.35, velocity: 80, commit: true)
        let fastFlick = ReaderMotionPolicy.interactiveSettleDuration(baseDuration: 0.30, currentProgress: 0.35, velocity: 1200, commit: true)
        #expect(fastFlick < slowRelease)
        #expect(fastFlick >= 0.10)
    }
}
