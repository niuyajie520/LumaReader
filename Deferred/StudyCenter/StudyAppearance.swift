import SwiftUI

public struct StudyAppearance:Sendable {
    public var paper:Color
    public var ink:Color
    public var accent:Color
    public var surface:Color
    public init(paper:Color,ink:Color,accent:Color,surface:Color) {
        self.paper = paper; self.ink = ink; self.accent = accent; self.surface = surface
    }
    var line:Color { ink.opacity(0.14) }
    var selected:Color { accent.opacity(0.18) }
    var primaryGradient:LinearGradient { LinearGradient(colors:[accent.opacity(0.22),surface],startPoint:.topLeading,endPoint:.bottomTrailing) }
    var secondaryGradient:LinearGradient { LinearGradient(colors:[surface,paper],startPoint:.topLeading,endPoint:.bottomTrailing) }
}
private struct StudyAppearanceKey:EnvironmentKey {
    static let defaultValue = StudyAppearance(paper:Color(nsColor:.windowBackgroundColor),ink:.primary,accent:.accentColor,surface:Color.primary.opacity(0.06))
}
public extension EnvironmentValues {
    var studyAppearance:StudyAppearance {
        get { self[StudyAppearanceKey.self] }
        set { self[StudyAppearanceKey.self] = newValue }
    }
}
