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
    @Environment(\.lumaVisualThemeSystem) private var themeSystem
    @ViewBuilder func body(content:Content)->some View {
        switch themeSystem {
        case .monet:
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
        default:
            content.modifier(IndependentThemeMaterial(system:themeSystem,radius:radius,enabled:enabled,accent:tint))
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
    @Environment(\.lumaVisualThemeSystem) private var themeSystem
    @ViewBuilder func body(content:Content)->some View {
        switch themeSystem {
        case .monet:
            if enabled && !reduceTransparency {
                content.background(backing.opacity(opacity),in:RoundedRectangle(cornerRadius:radius))
                    .monetLiquidGlass(tint:accent,cornerRadius:radius)
            } else { content.background(backing,in:RoundedRectangle(cornerRadius:radius)) }
        default:
            content.modifier(IndependentThemeMaterial(system:themeSystem,radius:radius,enabled:enabled,accent:accent,backing:backing))
        }
    }
}
extension View {
    func monetLiquidGlass(tint:Color,cornerRadius:CGFloat = 16)->some View {
        modifier(MonetLiquidGlass(tint:tint,radius:cornerRadius))
    }
}

/// A single material layer per surface; each of the 13 non-Monet independent themes has its own distinct physical border, corner radius, and shadow physics.
private struct IndependentThemeMaterial: ViewModifier {
    let system: LumaVisualThemeSystem
    let radius: CGFloat
    let enabled: Bool
    let accent: Color
    var backing: Color? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lumaSurface) private var envSurface
    @Environment(\.lumaInk) private var envInk
    @Environment(\.lumaSpaceGlassOpacity) private var spaceOpacity
    @Environment(\.lumaSpaceGlowIntensity) private var glow
    @Environment(\.lumaMangaLineWeight) private var weight
    @Environment(\.lumaMangaPopoverTranslucent) private var translucent
    @Environment(\.lumaAnimeBlendGlass) private var blendGlass

    private var surfaceFill: Color { backing ?? envSurface }

    @ViewBuilder func body(content: Content) -> some View {
        switch system {
        case .monet:
            content
        case .space:
            let shape = RoundedRectangle(cornerRadius:radius,style:.continuous)
            content.background {
                if reduceTransparency || !enabled || contrast == .increased {
                    shape.fill(Color(hex:"111629"))
                } else {
                    shape.fill(.ultraThinMaterial).environment(\.colorScheme,.dark)
                        .overlay(shape.fill(Color(hex:"111629").opacity(spaceOpacity)))
                        .overlay(shape.fill(LinearGradient(colors:[accent.opacity(0.16 * glow),.clear],startPoint:.topLeading,endPoint:.bottomTrailing)))
                }
            }
            .overlay(shape.strokeBorder(LinearGradient(colors:[accent.opacity(0.45 + 0.3 * glow),Color(hex:"C6CAD9").opacity(0.32),Color(hex:"D8C6A2").opacity(0.18 * glow)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:contrast == .increased ? 1.4:0.95).allowsHitTesting(false))
        case .manga:
            let shape = RoundedRectangle(cornerRadius:min(radius,4),style:.continuous)
            content.background {
                ZStack {
                    shape.fill(accent).offset(x:2.4,y:2.4)
                    shape.fill(surfaceFill.opacity(translucent && !reduceTransparency && contrast != .increased ? 0.94:1))
                }
            }
            .overlay(shape.strokeBorder(accent,lineWidth:max(CGFloat(weight),contrast == .increased ? 2:1)).allowsHitTesting(false))
        case .mangaOcean:
            // Fresh Ocean Manga: Crisp comic panel (6pt radius) + 3pt solid Cerulean-Ink comic offset shadow + cobalt frame
            let r = min(radius, 6)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                ZStack {
                    shape.fill(accent.opacity(0.38)).offset(x: 2.8, y: 2.8)
                    if blendGlass && enabled && !reduceTransparency {
                        shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.82)))
                    } else {
                        shape.fill(surfaceFill)
                    }
                }
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(accent.opacity(0.85), lineWidth: 1.65)
                    RoundedRectangle(cornerRadius: max(2, r - 2), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8)
                        .padding(1.8)
                }
                .allowsHitTesting(false)
            )
        case .mangaCity:
            // Fresh City Pop Manga: Urban comic frame (5pt radius) + twin neon magenta/cyan offset comic shadows
            let r = min(radius, 5)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            let neonPink = Color(red: 0.97, green: 0.46, blue: 0.56)
            content.background {
                ZStack {
                    shape.fill(neonPink.opacity(0.28)).offset(x: -1.6, y: -1.6)
                    shape.fill(accent.opacity(0.36)).offset(x: 2.6, y: 2.6)
                    if blendGlass && enabled && !reduceTransparency {
                        shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.82)))
                    } else {
                        shape.fill(surfaceFill)
                    }
                }
            }
            .overlay(shape.strokeBorder(accent.opacity(0.86), lineWidth: 1.6).allowsHitTesting(false))
        case .mangaForest:
            // Fresh Forest Manga: Botanical comic panel (9pt radius) + moss offset shadow + inner leaf-vein dashed border
            let r = min(radius, 9)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                ZStack {
                    shape.fill(accent.opacity(0.28)).offset(x: 2.4, y: 2.4)
                    if blendGlass && enabled && !reduceTransparency {
                        shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.82)))
                    } else {
                        shape.fill(surfaceFill)
                    }
                }
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(accent.opacity(0.78), lineWidth: 1.55)
                    RoundedRectangle(cornerRadius: max(3, r - 2.5), style: .continuous)
                        .strokeBorder(accent.opacity(0.38), style: StrokeStyle(lineWidth: 0.85, dash: [5, 3]))
                        .padding(2.4)
                }
                .allowsHitTesting(false)
            )
        case .nier:
            // NieR:Automata YoRHa Tactical Container: Razor-sharp 2pt corners, 4pt solid leading tactical bar & inset hairline border
            let r = min(radius, 2)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                if blendGlass && enabled && !reduceTransparency {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.86)))
                } else {
                    shape.fill(surfaceFill)
                }
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent.opacity(0.88))
                    .frame(width: 3.8)
                    .padding(.vertical, 2)
                    .allowsHitTesting(false)
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(accent.opacity(0.68), lineWidth: 1.1)
                    RoundedRectangle(cornerRadius: max(1, r - 1), style: .continuous)
                        .strokeBorder(accent.opacity(0.26), lineWidth: 0.65)
                        .padding(2.5)
                }
                .allowsHitTesting(false)
            )
        case .wasteland:
            // Wasteland terminal: riveted steel bezel (3pt corners) around a phosphor screen with a faint inner glow line.
            let r = min(radius, 3)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                if blendGlass && enabled && !reduceTransparency {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.88)))
                } else {
                    shape.fill(surfaceFill)
                }
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(Color(hex: "5F6D52").opacity(0.95), lineWidth: contrast == .increased ? 2.4 : 1.8)
                    RoundedRectangle(cornerRadius: max(1, r - 1), style: .continuous)
                        .strokeBorder(accent.opacity(0.42), lineWidth: 0.7)
                        .padding(3)
                }
                .allowsHitTesting(false)
            )
        case .zelda:
            // The Legend of Zelda (zelda-hyrule-ui specification):
            // Angular 4pt outer / 2pt inner double-border (inset 3px, tan #E2DED3 border) + top Sheikah Blue gradient line decoration
            let r = min(radius, 4)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            let tanBorder = Color(red: 0.886, green: 0.871, blue: 0.827) // #E2DED3
            content.background {
                if blendGlass && enabled && !reduceTransparency {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.84)))
                } else {
                    shape.fill(surfaceFill)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, accent.opacity(0.72), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.2)
                    .padding(.horizontal, 10)
                    .allowsHitTesting(false)
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(accent.opacity(0.45), lineWidth: 1.0)
                    RoundedRectangle(cornerRadius: max(1.5, r - 2), style: .continuous)
                        .strokeBorder(tanBorder.opacity(0.36), lineWidth: 0.95)
                        .padding(2.8)
                }
                .allowsHitTesting(false)
            )
        case .shinkai:
            // Shinkai Sky: Crisp anime cel-frame (solid sky border + vertical 0,2.5 sky shadow)
            let shape = RoundedRectangle(cornerRadius: min(radius, 12), style: .continuous)
            content.background {
                ZStack {
                    shape.fill(accent.opacity(0.24)).offset(x: 0, y: 2.5)
                    if blendGlass && enabled && !reduceTransparency {
                        shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.76)))
                    } else {
                        shape.fill(surfaceFill)
                    }
                }
            }
            .overlay(shape.strokeBorder(accent.opacity(0.62), lineWidth: 1.4).allowsHitTesting(false))
        case .chihiro:
            // Chihiro Spirited Away: Bathhouse bridge lacquer & golden lantern inner rim
            let r = min(radius, 11)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                ZStack {
                    shape.fill(accent.opacity(0.22)).offset(x: 1.5, y: 2.0)
                    if blendGlass && enabled && !reduceTransparency {
                        shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.80)))
                    } else {
                        shape.fill(surfaceFill)
                    }
                }
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(accent.opacity(0.68), lineWidth: 1.4)
                    RoundedRectangle(cornerRadius: max(2, r - 2.5), style: .continuous)
                        .strokeBorder(Color(red: 0.92, green: 0.72, blue: 0.28).opacity(0.42), lineWidth: 0.8)
                        .padding(2.5)
                }
                .allowsHitTesting(false)
            )
        case .kanagawa:
            // Kanagawa Lotus: Hokusai woodblock print sharp 4pt corner + double-line ukiyo-e frame + 2,2 offset
            let r = min(radius, 5)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                ZStack {
                    shape.fill(accent.opacity(0.26)).offset(x: 2.0, y: 2.0)
                    if blendGlass && enabled && !reduceTransparency {
                        shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.82)))
                    } else {
                        shape.fill(surfaceFill)
                    }
                }
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(accent.opacity(0.72), lineWidth: 1.35)
                    RoundedRectangle(cornerRadius: max(1, r - 2.5), style: .continuous)
                        .strokeBorder(accent.opacity(0.28), lineWidth: 0.65)
                        .padding(2.5)
                }
                .allowsHitTesting(false)
            )
        case .roseDawn:
            // Rose Pine Dawn: Velvet oat diary card with delicate dashed stitch border
            let r = min(radius, 14)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                if blendGlass && enabled && !reduceTransparency {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.80)))
                } else {
                    shape.fill(surfaceFill)
                }
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(accent.opacity(0.32), lineWidth: 1.0)
                    RoundedRectangle(cornerRadius: max(3, r - 2.5), style: .continuous)
                        .strokeBorder(accent.opacity(0.55), style: StrokeStyle(lineWidth: 0.9, dash: [4, 3]))
                        .padding(2.5)
                }
                .allowsHitTesting(false)
            )
        case .akari:
            // Akari Dawn: Kyoto paper lantern surface with top-illuminated warm amber rim
            let r = min(radius, 10)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                if blendGlass && enabled && !reduceTransparency {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.80)))
                } else {
                    shape.fill(surfaceFill)
                        .overlay(
                            shape.fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.14), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        )
                }
            }
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.78), accent.opacity(0.24)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.3
                )
                .allowsHitTesting(false)
            )
        case .matcha:
            // Matcha Latte: Smooth porcelain glaze card (18pt rounded + 2pt white cream inner rim)
            let r = min(radius, 18)
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            content.background {
                if blendGlass && enabled && !reduceTransparency {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(surfaceFill.opacity(0.78)))
                } else {
                    shape.fill(surfaceFill)
                }
            }
            .overlay(
                ZStack {
                    shape.strokeBorder(accent.opacity(0.48), lineWidth: 1.3)
                    RoundedRectangle(cornerRadius: max(4, r - 1.8), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.2)
                        .padding(1.5)
                }
                .allowsHitTesting(false)
            )
        }
    }
}
