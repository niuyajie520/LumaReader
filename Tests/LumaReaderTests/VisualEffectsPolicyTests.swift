import Testing
@testable import LumaReader

struct VisualEffectsPolicyTests {
    @Test func visualModesCanBeSelectedIndependently() {
        #expect(VisualEffectsPolicy.effectiveMotion(requested:.enhanced,energySaving:false,systemLowPower:false,reduceMotion:false) == .enhanced)
        #expect(VisualEffectsPolicy.effectiveMotion(requested:.balanced,energySaving:false,systemLowPower:false,reduceMotion:false) == .balanced)
        #expect(VisualEffectsPolicy.effectiveMotion(requested:.off,energySaving:false,systemLowPower:false,reduceMotion:false) == .off)
    }
    @Test func manualAndSystemPowerSavingOverrideMotion() {
        #expect(VisualEffectsPolicy.effectiveMotion(requested:.enhanced,energySaving:true,systemLowPower:false,reduceMotion:false) == .off)
        #expect(VisualEffectsPolicy.effectiveMotion(requested:.enhanced,energySaving:false,systemLowPower:true,reduceMotion:false) == .off)
        #expect(VisualEffectsPolicy.effectiveMotion(requested:.enhanced,energySaving:false,systemLowPower:false,reduceMotion:true) == .off)
    }
    @Test func glassIsDisabledByPowerSavingAndAccessibility() {
        #expect(VisualEffectsPolicy.glassEnabled(requested:true,energySaving:false,systemLowPower:false,reduceTransparency:false))
        #expect(!VisualEffectsPolicy.glassEnabled(requested:false,energySaving:false,systemLowPower:false,reduceTransparency:false))
        #expect(!VisualEffectsPolicy.glassEnabled(requested:true,energySaving:true,systemLowPower:false,reduceTransparency:false))
        #expect(!VisualEffectsPolicy.glassEnabled(requested:true,energySaving:false,systemLowPower:true,reduceTransparency:false))
        #expect(!VisualEffectsPolicy.glassEnabled(requested:true,energySaving:false,systemLowPower:false,reduceTransparency:true))
    }
}
