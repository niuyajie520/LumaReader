import Foundation
import Testing
@testable import LumaReaderStudyKit

@Suite("Speech Synthesis Playback Speed Multiplier & Female Voice Fallback Tests")
struct SmartUpgradeSpeechVoiceSelectionTests {

    @Test("Playback speed multiplier scales rate across 0.85x, 1.0x, 1.15x, 1.5x, and 1.8x for all voice tiers")
    func testPlaybackSpeedMultiplierScaling() {
        let manager = MacOSSpeechSynthesisManager()
        for descriptor in MacOSSpeechSynthesisManager.defaultVoiceCatalog {
            let rate085 = manager.effectivePlaybackRate(for: descriptor, userMultiplier: 0.85)
            let rate100 = manager.effectivePlaybackRate(for: descriptor, userMultiplier: 1.0)
            let rate115 = manager.effectivePlaybackRate(for: descriptor, userMultiplier: 1.15)
            let rate150 = manager.effectivePlaybackRate(for: descriptor, userMultiplier: 1.5)
            let rate180 = manager.effectivePlaybackRate(for: descriptor, userMultiplier: 1.8)

            #expect(rate085 < rate100)
            #expect(rate100 == 0.5)
            #expect(rate115 > rate100)
            #expect(rate150 > rate115)
            #expect(rate180 > rate150)
        }
    }

    @Test("Selection uses installed female voices")
    func testFemaleVoiceSelectionFallback() {
        let manager = MacOSSpeechSynthesisManager()
        for accent in [TTSVoiceAccent.british, .american] {
            let voices = manager.availableVoices(for: accent)
            #expect(voices.allSatisfy { $0.isFemale })
            if !voices.isEmpty {
                #expect(voices.contains { $0.id == manager.selectBestFemaleVoice(preferredVoiceID: nil, accent: accent).id })
            }
        }
    }
}
