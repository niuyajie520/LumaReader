import Testing
@testable import LumaReaderStudyKit

struct SpeechVoiceSelectionTests {
    @Test func selectionNeverSilentlyChangesRequestedAccentOrGender() {
        let us=TTSVoiceDescriptor(id:"us-female",displayName:"US",localeIdentifier:"en-US",isFemale:true,tier:.applePremiumOrEnhanced)
        let uk=TTSVoiceDescriptor(id:"uk-male",displayName:"UK",localeIdentifier:"en-GB",isFemale:false,tier:.applePremiumOrEnhanced)
        #expect(MacOSSpeechSynthesisManager.preferredFemaleVoice(in:[us,uk],preferredVoiceID:us.id,accent:.british)==nil)
        #expect(MacOSSpeechSynthesisManager.preferredFemaleVoice(in:[us,uk],preferredVoiceID:nil,accent:.american)?.id==us.id)
    }
    @Test func allVoiceTiersHonorSpeedWithoutExceedingEngineRange() {
        let engine=MacOSSpeechSynthesisManager()
        let standard=TTSVoiceDescriptor(id:"standard",displayName:"Fixture",localeIdentifier:"en-US",isFemale:true,tier:.appleStandardMechanicalFallback)
        let enhanced=TTSVoiceDescriptor(id:"enhanced",displayName:"Fixture",localeIdentifier:"en-US",isFemale:true,tier:.applePremiumOrEnhanced)
        #expect(engine.effectivePlaybackRate(for:standard,userMultiplier:1.8)>engine.effectivePlaybackRate(for:standard,userMultiplier:1.0))
        #expect(abs(engine.effectivePlaybackRate(for:enhanced,userMultiplier:1.8)-0.716)<0.001)
    }
}

