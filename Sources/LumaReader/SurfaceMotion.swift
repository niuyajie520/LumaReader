import SwiftUI

// Scoped to reader/library/settings subtrees. AI keeps its existing environment and timing.
private struct SurfacePolishKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var lumaSurfacePolish: Bool {
        get { self[SurfacePolishKey.self] }
        set { self[SurfacePolishKey.self] = newValue }
    }
}
enum MotionTokens {
    static let aiOpening = Animation.spring(response:0.36,dampingFraction:0.96)
    static let aiClosing = Animation.spring(response:0.48,dampingFraction:0.96)
    static let settingsOpening = Animation.spring(response:0.38,dampingFraction:0.90)
    static let settingsClosing = Animation.spring(response:0.46,dampingFraction:0.90)
    static let micro = Animation.spring(response:0.22,dampingFraction:0.82)
    static let floating = Animation.spring(response:0.32,dampingFraction:0.86)
    static let navigation = Animation.spring(response:0.42,dampingFraction:0.88)
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
