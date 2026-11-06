import SwiftUI

private struct LumaInkKey: EnvironmentKey { static let defaultValue = Color.primary }
private struct LumaMutedKey: EnvironmentKey { static let defaultValue = Color.secondary }
private struct LumaSurfaceKey: EnvironmentKey { static let defaultValue = Color.clear }
private struct LumaGlassKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var lumaInk:Color { get { self[LumaInkKey.self] } set { self[LumaInkKey.self] = newValue } }
    var lumaMuted:Color { get { self[LumaMutedKey.self] } set { self[LumaMutedKey.self] = newValue } }
    var lumaSurface:Color { get { self[LumaSurfaceKey.self] } set { self[LumaSurfaceKey.self] = newValue } }
    var lumaGlass:Bool { get { self[LumaGlassKey.self] } set { self[LumaGlassKey.self] = newValue } }
}
struct LumaThemeScope: ViewModifier {
    @Bindable var store:LibraryStore
    @Environment(\.colorScheme) private var colorScheme
    func body(content:Content) -> some View {
        let palette = store.readingPalette(dark:colorScheme == .dark)
        content.environment(\.lumaGlassOpacity,store.glassOpacity).environment(\.lumaAccent,palette.accent).environment(\.lumaInk,palette.ink).environment(\.lumaMuted,palette.muted)
            .environment(\.lumaSurface,palette.chrome).environment(\.lumaGlass,store.effectiveGlassEffectsEnabled)
            .environment(\.lumaMotionLevel,store.effectiveMotionLevel)
            .foregroundStyle(palette.ink).tint(palette.accent).accentColor(palette.accent)
            .toggleStyle(LumaThemeSwitchStyle(accent:palette.accent))
    }
}
private struct LumaSurfaceStyle: ViewModifier {
    var radius:CGFloat
    @Environment(\.lumaSurface) private var surface
    @Environment(\.lumaGlass) private var glass
    func body(content:Content) -> some View { content.readerGlass(radius:radius,enabled:glass,tint:surface) }
}
extension View {
    func lumaSurface(radius:CGFloat = 12) -> some View { modifier(LumaSurfaceStyle(radius:radius)) }
}

private struct LumaInputSurface:ViewModifier {
    @Environment(\.lumaSurface) private var surface
    @Environment(\.lumaInk) private var ink
    func body(content:Content) -> some View {
        content.textFieldStyle(.plain).padding(8)
            .background(surface.opacity(0.65),in:RoundedRectangle(cornerRadius:7))
            .overlay(RoundedRectangle(cornerRadius:7).strokeBorder(ink.opacity(0.15),lineWidth:0.7).allowsHitTesting(false))
    }
}
extension View { func lumaInputSurface() -> some View { modifier(LumaInputSurface()) } }
