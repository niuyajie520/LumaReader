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
        let dark = store.isDarkAppearance || ((store.visualThemeSystem == .monet || store.visualThemeSystem.isAnimeFreshSeries) && colorScheme == .dark && store.appearance == .system)
        let palette = store.readingPalette(dark:dark)
        let glassEnabled: Bool = {
            switch store.visualThemeSystem {
            case .monet, .space: return store.effectiveGlassEffectsEnabled
            case .manga: return false
            default: return store.animeBlendLiquidGlass && store.effectiveGlassEffectsEnabled
            }
        }()
        content
            .environment(\.lumaVisualThemeSystem,store.visualThemeSystem)
            .environment(\.lumaSpaceGlassOpacity,store.spaceGlassOpacity)
            .environment(\.lumaSpaceGlowIntensity,store.spaceGlowIntensity)
            .environment(\.lumaSpaceOrbitalLines,store.spaceOrbitalLines)
            .environment(\.lumaMangaScreentoneDensity,store.mangaScreentoneDensity)
            .environment(\.lumaMangaLineWeight,store.mangaLineWeight)
            .environment(\.lumaMangaPopoverTranslucent,store.mangaPopoverTranslucent)
            .environment(\.lumaAnimeBlendGlass,store.animeBlendLiquidGlass)
            .environment(\.lumaGlassOpacity,store.glassOpacity).environment(\.lumaAccent,palette.accent).environment(\.lumaInk,palette.ink).environment(\.lumaMuted,palette.muted)
            .environment(\.lumaSurface,palette.chrome).environment(\.lumaGlass,glassEnabled)
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
    @Environment(\.lumaVisualThemeSystem) private var themeSystem
    @Environment(\.lumaMangaLineWeight) private var lineWeight
    @Environment(\.lumaAccent) private var accent
    @AppStorage(LumaUIPrefs.inputOpacity) private var inputOpacity = 1.0

    /// 1.9.1: dim only the field's surface, never its text. Fading the whole
    /// control made typed text illegible at the lower end of the slider.
    private var alpha: Double { min(1, max(0.3, inputOpacity)) }

    @ViewBuilder func body(content:Content) -> some View {
        switch themeSystem {
        case .monet:
            content.textFieldStyle(.plain).padding(8)
                .background(surface.opacity(0.65 * alpha),in:RoundedRectangle(cornerRadius:7))
                .overlay(RoundedRectangle(cornerRadius:7).strokeBorder(ink.opacity(0.15 * alpha),lineWidth:0.7).allowsHitTesting(false))
        case .space:
            content.textFieldStyle(.plain).padding(8)
                .background(Color(hex:"0C1021").opacity(alpha),in:RoundedRectangle(cornerRadius:7))
                .overlay(RoundedRectangle(cornerRadius:7).strokeBorder(accent.opacity(0.38 * alpha),lineWidth:0.85).allowsHitTesting(false))
        case .manga:
            content.textFieldStyle(.plain).padding(8)
                .background(surface.opacity(alpha),in:RoundedRectangle(cornerRadius:2))
                .overlay(RoundedRectangle(cornerRadius:2).strokeBorder(accent.opacity(alpha),lineWidth:CGFloat(lineWeight)).allowsHitTesting(false))
        case .mangaOcean, .mangaCity, .mangaForest:
            content.textFieldStyle(.plain).padding(8)
                .background(surface.opacity(alpha),in:RoundedRectangle(cornerRadius:5))
                .overlay(RoundedRectangle(cornerRadius:5).strokeBorder(accent.opacity(0.78 * alpha),lineWidth:1.4).allowsHitTesting(false))
        case .nier:
            content.textFieldStyle(.plain).padding(8)
                .background(surface.opacity(alpha),in:RoundedRectangle(cornerRadius:2))
                .overlay(alignment:.leading) { Rectangle().fill(accent.opacity(alpha)).frame(width:3).allowsHitTesting(false) }
                .overlay(RoundedRectangle(cornerRadius:2).strokeBorder(accent.opacity(0.65 * alpha),lineWidth:1.0).allowsHitTesting(false))
        case .wasteland:
            content.textFieldStyle(.plain).padding(8)
                .font(.system(.body, design: .monospaced))
                .background(surface.opacity(alpha),in:RoundedRectangle(cornerRadius:3))
                .overlay(RoundedRectangle(cornerRadius:3).strokeBorder(accent.opacity(0.7 * alpha),lineWidth:1.1).allowsHitTesting(false))
        case .zelda:
            content.textFieldStyle(.plain).padding(8)
                .background(surface.opacity(alpha),in:RoundedRectangle(cornerRadius:4))
                .overlay(RoundedRectangle(cornerRadius:4).strokeBorder(accent.opacity(0.62 * alpha),lineWidth:1.1).allowsHitTesting(false))
        case .kanagawa:
            content.textFieldStyle(.plain).padding(8)
                .background(surface.opacity(alpha),in:RoundedRectangle(cornerRadius:4))
                .overlay(RoundedRectangle(cornerRadius:4).strokeBorder(accent.opacity(0.55 * alpha),lineWidth:1.1).allowsHitTesting(false))
        case .roseDawn:
            content.textFieldStyle(.plain).padding(8)
                .background(surface.opacity(alpha),in:RoundedRectangle(cornerRadius:9))
                .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(accent.opacity(0.48 * alpha),style:StrokeStyle(lineWidth:1.0,dash:[4,3])).allowsHitTesting(false))
        default:
            content.textFieldStyle(.plain).padding(8)
                .background(surface.opacity(alpha),in:RoundedRectangle(cornerRadius:8))
                .overlay(RoundedRectangle(cornerRadius:8).strokeBorder(accent.opacity(0.45 * alpha),lineWidth:1.1).allowsHitTesting(false))
        }
    }
}
extension View { func lumaInputSurface() -> some View { modifier(LumaInputSurface()) } }
