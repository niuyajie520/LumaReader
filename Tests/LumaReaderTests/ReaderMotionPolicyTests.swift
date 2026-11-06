import Testing
@testable import LumaReader

struct ReaderMotionPolicyTests {
    @Test func disablingMotionAccessibilityAndLowPowerSkipPageRotation() {
        #expect(ReaderMotionPolicy.pageTurnDuration(enabled:false,reduceMotion:false,systemLowPower:false,energySaving:false) == 0)
        #expect(ReaderMotionPolicy.pageTurnDuration(enabled:true,reduceMotion:true,systemLowPower:false,energySaving:false) == 0)
        #expect(ReaderMotionPolicy.pageTurnDuration(enabled:true,reduceMotion:false,systemLowPower:true,energySaving:false) == 0)
    }
    @Test func readingStillHasOptionalBriefPageFeedback() {
        let regular = ReaderMotionPolicy.pageTurnDuration(enabled:true,reduceMotion:false,systemLowPower:false,energySaving:false)
        let saving = ReaderMotionPolicy.pageTurnDuration(enabled:true,reduceMotion:false,systemLowPower:false,energySaving:true)
        #expect(saving == 0)
        #expect(regular > saving)
        #expect(regular <= 0.3)
    }
    @Test func dragCanCommitOrReverseWithoutChangingReadingPositionOnCancel() {
        #expect(!ReaderMotionPolicy.commitsDrag(progress:0.15,velocity:0))
        #expect(ReaderMotionPolicy.commitsDrag(progress:0.45,velocity:0))
        #expect(ReaderMotionPolicy.commitsDrag(progress:0.10,velocity:650))
        #expect(!ReaderMotionPolicy.commitsDrag(progress:0.75,velocity:-450))
    }
}
