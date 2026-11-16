import SwiftUI
import LumaReaderStudyKit

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
    // 工具栏图标：悬停只出现淡底（不再放大 1.12），按下 0.97。
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var level
    func makeBody(configuration: Configuration) -> some View {
        let still = reduceMotion || level == .off
        configuration.label
            .background(Color.primary.opacity(configuration.isPressed ? LumaButtonMetric.pressFill : (hovered ? LumaButtonMetric.hoverFill : 0)),
                        in: RoundedRectangle(cornerRadius: LumaButtonMetric.cornerRadius, style: .continuous))
            .scaleEffect(still || !configuration.isPressed ? 1.0 : LumaButtonMetric.pressScale)
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
            .animation(LumaButtonMetric.hoverAnimation(reduceMotion: still), value: hovered)
            .animation(LumaButtonMetric.pressAnimation(reduceMotion: still), value: configuration.isPressed)
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
            // DESIGN.md：点击图标不弹跳、不回弹；只保留旋转表示开合。
            .onHover { hovered = $0 }
            .animation(reduceMotion || level == .off ? nil:.smooth(duration:0.22),value:active)
            .animation(reduceMotion || level == .off ? nil:MotionTokens.micro,value:hovered)
    }
}
