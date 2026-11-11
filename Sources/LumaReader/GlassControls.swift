import SwiftUI

/// One optical container per control cluster. The fallback keeps the same shape and hit targets.
struct LumaGlassCluster<Content:View>: View {
    @Environment(\.lumaVisualThemeSystem) private var themeSystem
    var enabled: Bool
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content
    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0,*), enabled, themeSystem == .monet {
            GlassEffectContainer(spacing:spacing) { content() }
        } else { content() }
        #else
        content()
        #endif
    }
}

struct LumaGlassIdentity: ViewModifier {
    @Environment(\.lumaVisualThemeSystem) private var themeSystem
    var id: String
    var namespace: Namespace.ID
    var enabled: Bool
    func body(content:Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0,*), enabled, themeSystem == .monet {
            content.glassEffectID(id,in:namespace)
        } else { content }
        #else
        content
        #endif
    }
}

struct SearchAnchorPreference: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value:inout Anchor<CGRect>?,nextValue:()->Anchor<CGRect>?) { value = nextValue() ?? value }
}

struct InteractiveToolbarButtonStyle: ButtonStyle {
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var level
    func makeBody(configuration:Configuration)->some View {
        let scale = reduceMotion || level == .off ? 1.0:(configuration.isPressed ? 0.90:hovered ? 1.12:1.0)
        configuration.label
            .background(.white.opacity(hovered ? 0.12:0),in:RoundedRectangle(cornerRadius:10))
            .scaleEffect(scale)
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
            .animation(reduceMotion || level == .off ? nil:.spring(response:0.26,dampingFraction:0.68),value:hovered)
            .animation(reduceMotion || level == .off ? nil:MotionTokens.micro,value:configuration.isPressed)
    }
}
struct AnimatedSettingsGlyph: View {
    var active:Bool
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var level
    var body:some View {
        Image(systemName:"gearshape")
            .rotationEffect(.degrees(reduceMotion || level == .off ? 0:(active ? 180:0)+(hovered ? 35:0)))
            .contentShape(Rectangle())
            .phaseAnimator([1.0,1.18,1.0],trigger:active) { icon,scale in
                icon.scaleEffect(reduceMotion || level == .off ? 1:scale)
            } animation: { _ in MotionTokens.micro }
            .onHover { hovered = $0 }
            .animation(reduceMotion || level == .off ? nil:.interpolatingSpring(stiffness:220,damping:16),value:active)
            .animation(reduceMotion || level == .off ? nil:MotionTokens.micro,value:hovered)
    }
}
