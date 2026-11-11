import SwiftUI
import LumaReaderStudyKit

// Scoped to reader/library/settings subtrees. AI keeps its existing environment and timing.
private struct SurfacePolishKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var lumaSurfacePolish: Bool {
        get { self[SurfacePolishKey.self] }
        set { self[SurfacePolishKey.self] = newValue }
    }
}
// Values live in LumaDesignTokens.swift (LumaReaderStudyKit); numbers are unchanged.
enum MotionTokens {
    static let aiOpening = LumaMotionToken.aiOpening
    static let aiClosing = LumaMotionToken.aiClosing
    static let settingsOpening = LumaMotionToken.settingsOpening
    static let settingsClosing = LumaMotionToken.settingsClosing
    static let micro = LumaMotionToken.micro
    static let floating = LumaMotionToken.floating
    static let navigation = LumaMotionToken.navigation
}
enum SurfaceMotion {
    static let press = MotionTokens.micro
    static let interactive = MotionTokens.floating
    static let popover = MotionTokens.floating
    static let spatial = MotionTokens.navigation
    static func resolved(_ animation:Animation,level:VisualMotionLevel,reduceMotion:Bool)->Animation? {
        LumaMotion.adjusted(animation,level:level,reduceMotion:reduceMotion)
    }
}
