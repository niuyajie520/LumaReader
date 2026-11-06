import SwiftUI

enum AIPanelMotion {
    static let opening = MotionTokens.aiOpening
    static let closing = MotionTokens.aiClosing
}
struct ReadingViewportWidthPreference: PreferenceKey {
    static let defaultValue:CGFloat = 0
    static func reduce(value:inout CGFloat,nextValue:()->CGFloat) { value = nextValue() }
}
struct ReadingLayoutSlot: AnimatableModifier {
    var width:CGFloat
    var height:CGFloat
    var animatableData:CGFloat { get { width } set { width = newValue } }
    func body(content:Content)->some View {
        content.frame(width:max(0,width),height:max(0,height)).clipped()
            .background(GeometryReader { proxy in Color.clear.preference(key:ReadingViewportWidthPreference.self,value:proxy.size.width) })
    }
}
