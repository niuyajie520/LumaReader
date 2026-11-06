import SwiftUI

private struct GlassOpacityKey: EnvironmentKey { static let defaultValue = 0.32 }
extension EnvironmentValues { var lumaGlassOpacity:Double { get { self[GlassOpacityKey.self] } set { self[GlassOpacityKey.self] = newValue } } }
private struct MonetAccentKey: EnvironmentKey { static let defaultValue = Color.accentColor }
extension EnvironmentValues {
    var lumaAccent:Color { get { self[MonetAccentKey.self] } set { self[MonetAccentKey.self] = newValue } }
}
struct MonetLiquidGlass: ViewModifier {
    let tint:Color
    let radius:CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lumaGlass) private var enabled
    @Environment(\.lumaSurface) private var paper
    @Environment(\.lumaGlassOpacity) private var opacity
    @ViewBuilder func body(content:Content)->some View {
        if reduceTransparency || !enabled || contrast == .increased {
            content.background(paper,in:RoundedRectangle(cornerRadius:radius))
                .overlay(RoundedRectangle(cornerRadius:radius).strokeBorder(tint.opacity(0.45),lineWidth:contrast == .increased ? 1.2:0.5))
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0,*) {
                content.glassEffect(.regular.tint(tint.opacity(opacity*0.65)),in:.rect(cornerRadius:radius))
            } else { fallback(content) }
            #else
            fallback(content)
            #endif
        }
    }
    private func fallback(_ content:Content)->some View {
        content.background {
            let shape = RoundedRectangle(cornerRadius:radius,style:.continuous)
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(LinearGradient(colors:[tint.opacity(opacity),tint.opacity(opacity*0.35)],startPoint:.topLeading,endPoint:.bottomTrailing)))
                .overlay(shape.fill(LinearGradient(colors:[.white.opacity(0.18*(1-opacity*0.5)),.white.opacity(0.02),.clear],startPoint:.topLeading,endPoint:.bottomTrailing)))
                .overlay(shape.strokeBorder(LinearGradient(colors:[.white.opacity(0.42),tint.opacity(0.25),.white.opacity(0.06)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.7))
        }
    }
}
struct ReaderGlassSurface: ViewModifier {
    let radius:CGFloat
    let enabled:Bool
    let backing:Color
    @Environment(\.lumaAccent) private var accent
    @Environment(\.lumaGlassOpacity) private var opacity
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content:Content)->some View {
        if enabled && !reduceTransparency {
            content.background(backing.opacity(opacity),in:RoundedRectangle(cornerRadius:radius))
                .monetLiquidGlass(tint:accent,cornerRadius:radius)
        } else { content.background(backing,in:RoundedRectangle(cornerRadius:radius)) }
    }
}
extension View {
    func monetLiquidGlass(tint:Color,cornerRadius:CGFloat = 16)->some View {
        modifier(MonetLiquidGlass(tint:tint,radius:cornerRadius))
    }
}
