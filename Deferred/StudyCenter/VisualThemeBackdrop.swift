import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Static scenic & character/emblem illustration backdrop. No timers, event interception, or session state.
/// Rendered via Metal-backed Canvas + optional custom user-imported wallpaper to avoid a continuous animation loop. Actual rendering cost depends on the window and system.
public struct VisualThemeBackdrop: View {
    public let system: String
    public let paper: Color
    public let accent: Color
    public var glow: Double
    public var orbitals: Bool
    public var density: Double
    public var lineWeight: Double
    public init(system: String, paper: Color, accent: Color, glow: Double = 0.55,
                orbitals: Bool = true, density: Double = 0.35, lineWeight: Double = 1.5) {
        self.system = system; self.paper = paper; self.accent = accent
        self.glow = glow; self.orbitals = orbitals; self.density = density; self.lineWeight = lineWeight
    }
    public var body: some View {
        VisualThemeBackdropDrawing(system: system, paper: paper, accent: accent, glow: glow,
                                   orbitals: orbitals, density: density, lineWeight: lineWeight).equatable()
    }
}

private struct VisualThemeBackdropDrawing: View, Equatable {
    let system: String
    let paper: Color
    let accent: Color
    var glow: Double
    var orbitals: Bool
    var density: Double
    var lineWeight: Double
    init(system: String, paper: Color, accent: Color, glow: Double = 0.55,
                orbitals: Bool = true, density: Double = 0.35, lineWeight: Double = 1.5) {
        self.system = system; self.paper = paper; self.accent = accent
        self.glow = glow; self.orbitals = orbitals; self.density = density; self.lineWeight = lineWeight
    }

    var body: some View {
        ZStack {
            paper
            if system != "monet" {
                scenicIllustrationLayer
                    .drawingGroup()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var scenicIllustrationLayer: some View {
        let alpha = max(0.25, min(1.0, glow))
        ZStack {
            switch system {
            case "space":
                spaceObservatoryIllustration(alpha: alpha)
            case "manga":
                if density > 0.01 {
                    mangaManuscriptIllustration(alpha: max(0.35, density))
                }
            case "mangaOcean":
                mangaOceanIllustration(alpha: alpha)
            case "mangaCity":
                mangaCityIllustration(alpha: alpha)
            case "mangaForest":
                mangaForestIllustration(alpha: alpha)
            case "nier":
                nierAutomataIllustration(alpha: alpha)
            case "zelda":
                zeldaHyruleIllustration(alpha: alpha)
            case "shinkai":
                shinkaiSkyIllustration(alpha: alpha)
            case "chihiro":
                chihiroSpiritedAwayIllustration(alpha: alpha)
            case "kanagawa":
                kanagawaUkiyoeIllustration(alpha: alpha)
            case "roseDawn":
                roseDawnSakuraIllustration(alpha: alpha)
            case "akari":
                akariKyotoIllustration(alpha: alpha)
            case "matcha":
                matchaChashitsuIllustration(alpha: alpha)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - 1. NieR:Automata YoRHa Scenic Illustration (2B + Virtuous Contract Katana + Pod 042 + Engels Ruins + YoRHa Crest + Lunar Tear)

    private func nierAutomataIllustration(alpha: Double) -> some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.16 * alpha), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 620
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let mainCol = accent.opacity(0.26 * alpha)
                let strongCol = accent.opacity(0.42 * alpha)
                let faintCol = accent.opacity(0.12 * alpha)
                let crimsonCol = Color(red: 0.80, green: 0.36, blue: 0.28).opacity(0.38 * alpha)

                // 1. Subtle CRT phosphor horizontal scanlines
                var scan = Path()
                for y in stride(from: CGFloat(0), to: h, by: 6) {
                    scan.move(to: CGPoint(x: 0, y: y))
                    scan.addLine(to: CGPoint(x: w, y: y))
                }
                context.stroke(scan, with: .color(accent.opacity(0.032 * alpha)), lineWidth: 0.6)

                guard orbitals else { return }

                // 2. Upper-Right Sky: Ornate YoRHa Winged Crest & Sword Emblem (寄叶部队徽章)
                let crestCenter = CGPoint(x: w * 0.82, y: h * 0.26)
                for (idx, r) in [CGFloat(42), CGFloat(78), CGFloat(116)].enumerated() {
                    let rect = CGRect(x: crestCenter.x - r, y: crestCenter.y - r, width: r * 2, height: r * 2)
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(idx == 1 ? strongCol : mainCol),
                        style: StrokeStyle(lineWidth: idx == 1 ? 1.3 : 0.9, dash: idx == 2 ? [8, 4, 2, 4] : [])
                    )
                }
                // YoRHa spread mechanical wings (left & right 7-blade fan)
                for side in [-1.0, 1.0] {
                    let s = CGFloat(side)
                    for b in 0..<7 {
                        let bf = CGFloat(b)
                        var feather = Path()
                        let rootPt = CGPoint(x: crestCenter.x + s * 16, y: crestCenter.y - 10 + bf * 5)
                        let tipPt = CGPoint(x: crestCenter.x + s * (115 - bf * 11), y: crestCenter.y - 48 + bf * 14)
                        let ctrlPt = CGPoint(x: crestCenter.x + s * (70 - bf * 5), y: crestCenter.y - 36 + bf * 10)
                        feather.move(to: rootPt)
                        feather.addQuadCurve(to: tipPt, control: ctrlPt)
                        feather.addLine(to: CGPoint(x: tipPt.x - s * 8, y: tipPt.y + 6))
                        feather.closeSubpath()
                        context.fill(feather, with: .color(accent.opacity((0.22 - Double(b) * 0.02) * alpha)))
                        context.stroke(feather, with: .color(strongCol), lineWidth: 0.8)
                    }
                }
                // Central vertical YoRHa ritual sword axis
                var crestSword = Path()
                crestSword.move(to: CGPoint(x: crestCenter.x, y: crestCenter.y - 135))
                crestSword.addLine(to: CGPoint(x: crestCenter.x + 5, y: crestCenter.y + 95))
                crestSword.addLine(to: CGPoint(x: crestCenter.x, y: crestCenter.y + 125))
                crestSword.addLine(to: CGPoint(x: crestCenter.x - 5, y: crestCenter.y + 95))
                crestSword.closeSubpath()
                context.fill(crestSword, with: .color(mainCol))

                // 3. Bottom-Left Midground: Overgrown City Ruins & Dormant Engels Goliath Machine Lifeform (废墟都市与巨型机械生命体)
                let ruinBaseY = h - 14
                let ruinBlocks: [(CGFloat, CGFloat, CGFloat, Double)] = [
                    (28, 52, 130, -0.04), (74, 64, 175, 0.03), (132, 48, 115, -0.02), (176, 58, 148, 0.05)
                ]
                for (rx, rw, rh, tilt) in ruinBlocks {
                    var bldg = Path(CGRect(x: 0, y: -rh, width: rw, height: rh))
                    let tr = CGAffineTransform(translationX: rx, y: ruinBaseY).rotated(by: tilt)
                    context.fill(bldg.applying(tr), with: .color(faintCol))
                    context.stroke(bldg.applying(tr), with: .color(mainCol), lineWidth: 1.0)
                    // Broken window grid
                    for wy in stride(from: -rh + 14, to: -18, by: 16) {
                        for wx in stride(from: CGFloat(8), to: rw - 10, by: 12) {
                            let wRect = Path(CGRect(x: wx, y: wy, width: 6, height: 8)).applying(tr)
                            context.fill(wRect, with: .color(accent.opacity(0.08 * alpha)))
                        }
                    }
                }
                // Dormant Engels Machine Head (spherical dome head + twin glowing circular eyes + jaw)
                let machCenter = CGPoint(x: 265, y: ruinBaseY - 46)
                let machDome = CGRect(x: machCenter.x - 42, y: machCenter.y - 42, width: 84, height: 76)
                context.fill(Path(ellipseIn: machDome), with: .color(accent.opacity(0.18 * alpha)))
                context.stroke(Path(ellipseIn: machDome), with: .color(strongCol), lineWidth: 1.3)
                for eyeX in [machCenter.x - 16, machCenter.x + 12] {
                    let eyeRect = CGRect(x: eyeX - 7, y: machCenter.y - 8, width: 14, height: 14)
                    context.fill(Path(ellipseIn: eyeRect), with: .color(crimsonCol))
                    context.stroke(Path(ellipseIn: eyeRect), with: .color(strongCol), lineWidth: 1.1)
                }

                // 4. Bottom-Right Foreground: 2B Silhouette + Floating Virtuous Contract Katana (白之契约) + Pod 042 + Lunar Tear (月之泪)
                let charX = w - 135
                let charY = h - 18
                // Floating weapon halo ring behind 2B
                let haloCenter = CGPoint(x: charX, y: charY - 118)
                let haloRect = CGRect(x: haloCenter.x - 46, y: haloCenter.y - 46, width: 92, height: 92)
                context.stroke(Path(ellipseIn: haloRect), with: .color(strongCol), style: StrokeStyle(lineWidth: 1.4, dash: [10, 4]))

                // Virtuous Contract (白之契约) diagonal katana floating behind 2B
                var katana = Path()
                katana.move(to: CGPoint(x: charX - 88, y: charY - 48))
                katana.addQuadCurve(to: CGPoint(x: charX + 96, y: charY - 196), control: CGPoint(x: charX + 8, y: charY - 115))
                context.stroke(katana, with: .color(strongCol), lineWidth: 2.6)
                // Katana circular tsuba guard & tassel
                let tsuba = CGRect(x: charX + 48, y: charY - 162, width: 12, height: 12)
                context.stroke(Path(ellipseIn: tsuba), with: .color(strongCol), lineWidth: 1.5)

                // 2B figure silhouette (head with bob hair & visor, high-collar gothic dress, flowing skirt slit, boots)
                var fig = Path()
                // Head & bob hair
                fig.addEllipse(in: CGRect(x: charX - 13, y: charY - 172, width: 26, height: 28))
                // Torso & puffed sleeves
                fig.move(to: CGPoint(x: charX - 18, y: charY - 140))
                fig.addLine(to: CGPoint(x: charX + 18, y: charY - 140))
                fig.addLine(to: CGPoint(x: charX + 12, y: charY - 104))
                // Flared gothic skirt with high side slit
                fig.addLine(to: CGPoint(x: charX + 38, y: charY - 52))
                fig.addQuadCurve(to: CGPoint(x: charX + 6, y: charY - 62), control: CGPoint(x: charX + 22, y: charY - 46))
                // Legs
                fig.addLine(to: CGPoint(x: charX + 10, y: charY))
                fig.addLine(to: CGPoint(x: charX + 2, y: charY))
                fig.addLine(to: CGPoint(x: charX - 2, y: charY - 58))
                fig.addLine(to: CGPoint(x: charX - 10, y: charY))
                fig.addLine(to: CGPoint(x: charX - 18, y: charY))
                fig.addLine(to: CGPoint(x: charX - 14, y: charY - 56))
                fig.addLine(to: CGPoint(x: charX - 34, y: charY - 48))
                fig.addLine(to: CGPoint(x: charX - 12, y: charY - 104))
                fig.closeSubpath()
                context.fill(fig, with: .color(accent.opacity(0.28 * alpha)))
                context.stroke(fig, with: .color(strongCol), lineWidth: 1.1)

                // Pod 042 hovering beside 2B (rectangular tactical drone + articulated arms)
                let podRect = CGRect(x: charX - 66, y: charY - 178, width: 16, height: 24)
                context.fill(Path(roundedRect: podRect, cornerRadius: 2), with: .color(mainCol))
                context.stroke(Path(roundedRect: podRect, cornerRadius: 2), with: .color(strongCol), lineWidth: 1.1)
                context.stroke(Path(CGRect(x: charX - 70, y: charY - 172, width: 3, height: 14)), with: .color(strongCol), lineWidth: 1.0)
                context.stroke(Path(CGRect(x: charX - 49, y: charY - 172, width: 3, height: 14)), with: .color(strongCol), lineWidth: 1.0)

                // Glowing Lunar Tear (月之泪) blossom at bottom-right
                let flowerCenter = CGPoint(x: charX + 58, y: charY - 22)
                for p in 0..<5 {
                    let ang = Double(p) * (.pi * 2 / 5) - .pi / 2
                    var petal = Path()
                    petal.move(to: .zero)
                    petal.addQuadCurve(to: CGPoint(x: 0, y: -13), control: CGPoint(x: -6, y: -7))
                    petal.addQuadCurve(to: .zero, control: CGPoint(x: 6, y: -7))
                    let tr = CGAffineTransform(translationX: flowerCenter.x, y: flowerCenter.y).rotated(by: ang)
                    context.fill(petal.applying(tr), with: .color(Color.white.opacity(0.55 * alpha)))
                    context.stroke(petal.applying(tr), with: .color(strongCol), lineWidth: 0.8)
                }
            }
        }
    }

    // MARK: - 2. The Legend of Zelda Scenic Illustration (Sheikah Eye + Winged Triforce + Master Sword in Pedestal + Silent Princess + Twin Peaks)

    private func zeldaHyruleIllustration(alpha: Double) -> some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.18 * alpha), Color(red: 0.988, green: 0.769, blue: 0.075).opacity(0.07 * alpha), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 600
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let sheikahBlue = Color(red: 0.235, green: 0.827, blue: 0.988) // #3CD3FC
                let triforceGold = Color(red: 0.988, green: 0.769, blue: 0.075) // #FCC413
                let staminaGreen = Color(red: 0.075, green: 1.0, blue: 0.349) // #13FF59
                let tanLine = Color(red: 0.886, green: 0.871, blue: 0.827) // #E2DED3

                guard orbitals else { return }

                // 1. Upper-Right Sky: Authentic Sheikah Eye Symbol (希卡之眼: almond eye + pupil + 3 upper lashes + lower teardrop)
                let eyeCenter = CGPoint(x: w * 0.83, y: h * 0.24)
                for (idx, r) in [CGFloat(52), CGFloat(84), CGFloat(120)].enumerated() {
                    let rect = CGRect(x: eyeCenter.x - r, y: eyeCenter.y - r, width: r * 2, height: r * 2)
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(sheikahBlue.opacity((0.30 - Double(idx) * 0.06) * alpha)),
                        style: StrokeStyle(lineWidth: idx == 0 ? 1.4 : 0.95, dash: idx == 1 ? [6, 4] : [16, 6])
                    )
                }
                // Almond eye outline
                var eyeOutline = Path()
                eyeOutline.move(to: CGPoint(x: eyeCenter.x - 36, y: eyeCenter.y))
                eyeOutline.addQuadCurve(to: CGPoint(x: eyeCenter.x + 36, y: eyeCenter.y), control: CGPoint(x: eyeCenter.x, y: eyeCenter.y - 24))
                eyeOutline.addQuadCurve(to: CGPoint(x: eyeCenter.x - 36, y: eyeCenter.y), control: CGPoint(x: eyeCenter.x, y: eyeCenter.y + 24))
                context.stroke(eyeOutline, with: .color(sheikahBlue.opacity(0.48 * alpha)), lineWidth: 2.0)
                // Inner iris & pupil
                context.stroke(Path(ellipseIn: CGRect(x: eyeCenter.x - 13, y: eyeCenter.y - 13, width: 26, height: 26)),
                               with: .color(sheikahBlue.opacity(0.45 * alpha)), lineWidth: 1.6)
                context.fill(Path(ellipseIn: CGRect(x: eyeCenter.x - 6, y: eyeCenter.y - 6, width: 12, height: 12)),
                             with: .color(sheikahBlue.opacity(0.42 * alpha)))
                // 3 pointed upper eyelashes of the Sheikah Eye
                for lashAngle in [-0.48, 0.0, 0.48] {
                    var lash = Path()
                    lash.move(to: CGPoint(x: -5, y: -18))
                    lash.addLine(to: CGPoint(x: 0, y: -36))
                    lash.addLine(to: CGPoint(x: 5, y: -18))
                    lash.closeSubpath()
                    let tr = CGAffineTransform(translationX: eyeCenter.x, y: eyeCenter.y).rotated(by: lashAngle)
                    context.fill(lash.applying(tr), with: .color(sheikahBlue.opacity(0.42 * alpha)))
                }
                // Lower curved teardrop of the Sheikah Eye
                var tear = Path()
                tear.move(to: CGPoint(x: eyeCenter.x, y: eyeCenter.y + 18))
                tear.addQuadCurve(to: CGPoint(x: eyeCenter.x, y: eyeCenter.y + 42), control: CGPoint(x: eyeCenter.x + 10, y: eyeCenter.y + 32))
                tear.addQuadCurve(to: CGPoint(x: eyeCenter.x, y: eyeCenter.y + 18), control: CGPoint(x: eyeCenter.x - 10, y: eyeCenter.y + 32))
                context.fill(tear, with: .color(sheikahBlue.opacity(0.42 * alpha)))

                // 2. Center-Top Emblem: Hyrule Royal Winged Triforce (海拉鲁王室双翼三角神力)
                let triCenter = CGPoint(x: w * 0.83, y: h * 0.24 - 72)
                let ts: CGFloat = 11
                for (ox, oy) in [(CGFloat(0), -ts * 0.9), (-ts * 0.54, CGFloat(0)), (ts * 0.54, CGFloat(0))] {
                    let cx = triCenter.x + ox
                    let cy = triCenter.y + oy
                    var tri = Path()
                    tri.move(to: CGPoint(x: cx, y: cy - ts * 0.48))
                    tri.addLine(to: CGPoint(x: cx + ts * 0.52, y: cy + ts * 0.44))
                    tri.addLine(to: CGPoint(x: cx - ts * 0.52, y: cy + ts * 0.44))
                    tri.closeSubpath()
                    context.fill(tri, with: .color(triforceGold.opacity(0.42 * alpha)))
                    context.stroke(tri, with: .color(triforceGold.opacity(0.68 * alpha)), lineWidth: 0.9)
                }

                // 3. Bottom-Right Foreground: The Master Sword (大师之剑/退魔之剑) in Stone Pedestal + Silent Princess Flowers (静谧公主)
                let pedX = w - 125
                let pedY = h - 18
                // Stone pedestal
                var pedestal = Path()
                pedestal.move(to: CGPoint(x: pedX - 48, y: pedY))
                pedestal.addLine(to: CGPoint(x: pedX - 34, y: pedY - 26))
                pedestal.addLine(to: CGPoint(x: pedX + 34, y: pedY - 26))
                pedestal.addLine(to: CGPoint(x: pedX + 48, y: pedY))
                pedestal.closeSubpath()
                context.fill(pedestal, with: .color(tanLine.opacity(0.18 * alpha)))
                context.stroke(pedestal, with: .color(tanLine.opacity(0.36 * alpha)), lineWidth: 1.2)

                // Master Sword blade, winged purple/gold crossguard, grip & pommel (tilted 8 degrees)
                let swordOrigin = CGPoint(x: pedX, y: pedY - 22)
                let swordTr = CGAffineTransform(translationX: swordOrigin.x, y: swordOrigin.y).rotated(by: 0.12)
                var blade = Path()
                blade.move(to: CGPoint(x: -5.5, y: 0))
                blade.addLine(to: CGPoint(x: -6.5, y: -115))
                blade.addLine(to: CGPoint(x: 0, y: -135))
                blade.addLine(to: CGPoint(x: 6.5, y: -115))
                blade.addLine(to: CGPoint(x: 5.5, y: 0))
                blade.closeSubpath()
                context.fill(blade.applying(swordTr), with: .color(sheikahBlue.opacity(0.28 * alpha)))
                context.stroke(blade.applying(swordTr), with: .color(sheikahBlue.opacity(0.62 * alpha)), lineWidth: 1.3)
                // Winged crossguard
                var guardPath = Path()
                guardPath.move(to: CGPoint(x: 0, y: -112))
                guardPath.addQuadCurve(to: CGPoint(x: -28, y: -126), control: CGPoint(x: -16, y: -110))
                guardPath.addQuadCurve(to: CGPoint(x: -8, y: -120), control: CGPoint(x: -18, y: -124))
                guardPath.addLine(to: CGPoint(x: 8, y: -120))
                guardPath.addQuadCurve(to: CGPoint(x: 28, y: -126), control: CGPoint(x: 18, y: -124))
                guardPath.addQuadCurve(to: CGPoint(x: 0, y: -112), control: CGPoint(x: 16, y: -110))
                context.fill(guardPath.applying(swordTr), with: .color(triforceGold.opacity(0.45 * alpha)))
                context.stroke(guardPath.applying(swordTr), with: .color(triforceGold.opacity(0.75 * alpha)), lineWidth: 1.1)
                // Hilt & pommel
                let hilt = Path(CGRect(x: -3, y: -156, width: 6, height: 34)).applying(swordTr)
                context.fill(hilt, with: .color(sheikahBlue.opacity(0.45 * alpha)))
                let pommel = Path(ellipseIn: CGRect(x: -5.5, y: -164, width: 11, height: 11)).applying(swordTr)
                context.fill(pommel, with: .color(triforceGold.opacity(0.62 * alpha)))

                // Silent Princess (静谧公主) 5-petal blue-white flowers around the pedestal
                for (fx, fy, sc) in [(pedX - 54, pedY - 14, CGFloat(1.0)), (pedX + 52, pedY - 18, CGFloat(0.9)), (pedX - 28, pedY - 8, CGFloat(0.75))] {
                    for p in 0..<5 {
                        let ang = Double(p) * (.pi * 2 / 5) - .pi / 2
                        var petal = Path()
                        petal.move(to: .zero)
                        petal.addQuadCurve(to: CGPoint(x: 0, y: -11 * sc), control: CGPoint(x: -5 * sc, y: -6 * sc))
                        petal.addQuadCurve(to: .zero, control: CGPoint(x: 5 * sc, y: -6 * sc))
                        let tr = CGAffineTransform(translationX: fx, y: fy).rotated(by: ang)
                        context.fill(petal.applying(tr), with: .color(sheikahBlue.opacity(0.38 * alpha)))
                        context.stroke(petal.applying(tr), with: .color(Color.white.opacity(0.55 * alpha)), lineWidth: 0.7)
                    }
                }

                // 4. Bottom-Left Horizon: Twin Peaks (双子山) silhouette & Stamina Wheel
                var peaks = Path()
                peaks.move(to: CGPoint(x: 0, y: h))
                peaks.addLine(to: CGPoint(x: 58, y: h - 68))
                peaks.addLine(to: CGPoint(x: 84, y: h - 22))
                peaks.addLine(to: CGPoint(x: 96, y: h - 22))
                peaks.addLine(to: CGPoint(x: 122, y: h - 72))
                peaks.addLine(to: CGPoint(x: 195, y: h))
                peaks.closeSubpath()
                context.fill(peaks, with: .color(sheikahBlue.opacity(0.09 * alpha)))
                context.stroke(peaks, with: .color(sheikahBlue.opacity(0.24 * alpha)), lineWidth: 1.0)

                var staminaArc = Path()
                staminaArc.addArc(center: CGPoint(x: 42, y: h - 42), radius: 16, startAngle: .degrees(-90), endAngle: .degrees(210), clockwise: false)
                context.stroke(staminaArc, with: .color(staminaGreen.opacity(0.34 * alpha)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            }
        }
    }

    // MARK: - 3. Upgraded Manga Manuscript Illustration (Dynamic Panels + Speed Lines + G-Pen Mountain/Clouds + Screentone)

    private func mangaManuscriptIllustration(alpha: Double) -> some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let inkCol = accent

            // 1. Staggered halftone screentone in top-left & bottom-right
            let step: CGFloat = 11
            let cols = min(80, max(0, Int(w / step)))
            let rows = min(60, max(0, Int(h / step)))
            for row in 0..<rows {
                for col in 0..<cols {
                    let tlFade = max(0, 0.48 - CGFloat(col) / CGFloat(max(1, cols)) * 0.75 - CGFloat(row) / CGFloat(max(1, rows)) * 0.75)
                    let brFade = max(0, 0.42 - CGFloat(cols - 1 - col) / CGFloat(max(1, cols)) * 0.80 - CGFloat(rows - 1 - row) / CGFloat(max(1, rows)) * 0.80)
                    let fade = max(tlFade, brFade)
                    guard fade > 0.02 else { continue }
                    let radius = 1.5 * CGFloat(alpha) * fade
                    let x = CGFloat(col) * step + (row % 2 == 0 ? 0 : step / 2)
                    let y = CGFloat(row) * step
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                                 with: .color(inkCol.opacity(0.16)))
                }
            }

            // 2. Diagonal Manga Panel Frame & Focus Speed Lines (漫画斜切分镜框与集中速度线) in bottom-right
            var panel = Path()
            panel.move(to: CGPoint(x: w - 260, y: h - 14))
            panel.addLine(to: CGPoint(x: w - 220, y: h - 145))
            panel.addLine(to: CGPoint(x: w - 16, y: h - 170))
            panel.addLine(to: CGPoint(x: w - 16, y: h - 14))
            panel.closeSubpath()
            context.stroke(panel, with: .color(inkCol.opacity(0.28 * alpha)), lineWidth: max(1.4, CGFloat(lineWeight)))

            // G-Pen inked mountain & dramatic cloud inside the manga panel
            var mtn = Path()
            mtn.move(to: CGPoint(x: w - 245, y: h - 14))
            mtn.addLine(to: CGPoint(x: w - 165, y: h - 98))
            mtn.addLine(to: CGPoint(x: w - 115, y: h - 54))
            mtn.addLine(to: CGPoint(x: w - 68, y: h - 118))
            mtn.addLine(to: CGPoint(x: w - 16, y: h - 38))
            context.stroke(mtn, with: .color(inkCol.opacity(0.26 * alpha)), lineWidth: 1.5)

            // Radiating manga action speed lines in top-right corner
            var speed = Path()
            let focusPt = CGPoint(x: w - 24, y: 24)
            for i in 0..<14 {
                let ang = Double.pi * (0.52 + Double(i) * 0.035)
                let r1: CGFloat = 28 + CGFloat(i % 3) * 14
                let r2: CGFloat = 140 + CGFloat(i % 4) * 28
                speed.move(to: CGPoint(x: focusPt.x + cos(ang) * r1, y: focusPt.y + sin(ang) * r1))
                speed.addLine(to: CGPoint(x: focusPt.x + cos(ang) * r2, y: focusPt.y + sin(ang) * r2))
            }
            context.stroke(speed, with: .color(inkCol.opacity(0.18 * alpha)), lineWidth: 1.0)

            // 3. Manuscript Tonbo crop marks
            var marks = Path()
            marks.move(to: CGPoint(x: 10, y: max(10, h - 24)))
            marks.addLine(to: CGPoint(x: 10, y: max(10, h - 10)))
            marks.addLine(to: CGPoint(x: 24, y: max(10, h - 10)))
            marks.move(to: CGPoint(x: max(10, w - 24), y: 10))
            marks.addLine(to: CGPoint(x: max(10, w - 10), y: 10))
            marks.addLine(to: CGPoint(x: max(10, w - 10), y: 24))
            context.stroke(marks, with: .color(inkCol.opacity(0.36)), lineWidth: max(0.8, CGFloat(lineWeight) * 0.65))
        }
    }

    // MARK: - 4. Fresh Ocean Manga Scenic Illustration (Cape Lighthouse + Sailboat + Cumulonimbus + Waves + Seagulls)

    private func mangaOceanIllustration(alpha: Double) -> some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.18 * alpha), accent.opacity(0.05 * alpha), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // 1. Cyan comic halftone sky gradient
                let step: CGFloat = 12
                let cols = min(75, max(0, Int(w / step)))
                let rows = min(20, max(0, Int(h * 0.32 / step)))
                for r in 0..<rows {
                    for c in 0..<cols {
                        let fade = max(0, 0.42 - CGFloat(r) / CGFloat(max(1, rows)) * 0.40)
                        let rad = 1.4 * CGFloat(alpha) * fade
                        let x = CGFloat(c) * step + (r % 2 == 0 ? 0 : step * 0.5)
                        let y = CGFloat(r) * step
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: rad * 2, height: rad * 2)),
                                     with: .color(accent.opacity(0.15)))
                    }
                }

                guard orbitals else { return }

                // 2. Towering Summer Cumulonimbus Cloud (盛夏积雨云) on right horizon
                let cloudPuffs: [(CGFloat, CGFloat, CGFloat)] = [
                    (w - 220, h - 75, 48), (w - 170, h - 108, 64), (w - 105, h - 135, 76), (w - 42, h - 98, 58)
                ]
                for (cx, cy, cr) in cloudPuffs {
                    let rect = CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.36 * alpha)))
                    context.stroke(Path(ellipseIn: rect), with: .color(accent.opacity(0.26 * alpha)), lineWidth: 1.2)
                }

                // 3. Rocky Cape & White Lighthouse (海岬白灯塔) at bottom-right
                let lhX = w - 86
                let lhBaseY = h - 32
                var tower = Path()
                tower.move(to: CGPoint(x: lhX - 11, y: lhBaseY))
                tower.addLine(to: CGPoint(x: lhX - 7, y: lhBaseY - 74))
                tower.addLine(to: CGPoint(x: lhX + 7, y: lhBaseY - 74))
                tower.addLine(to: CGPoint(x: lhX + 11, y: lhBaseY))
                tower.closeSubpath()
                context.fill(tower, with: .color(Color.white.opacity(0.68 * alpha)))
                context.stroke(tower, with: .color(accent.opacity(0.48 * alpha)), lineWidth: 1.3)
                // Lighthouse lantern dome & light beam
                let dome = CGRect(x: lhX - 9, y: lhBaseY - 86, width: 18, height: 12)
                context.fill(Path(roundedRect: dome, cornerRadius: 4), with: .color(accent.opacity(0.45 * alpha)))
                var beam = Path()
                beam.move(to: CGPoint(x: lhX - 9, y: lhBaseY - 80))
                beam.addLine(to: CGPoint(x: lhX - 190, y: lhBaseY - 135))
                beam.addLine(to: CGPoint(x: lhX - 190, y: lhBaseY - 55))
                beam.closeSubpath()
                context.fill(beam, with: .color(Color.white.opacity(0.18 * alpha)))

                // 4. Sailboat (夏海帆船) on the left-center horizon
                let boatX = w * 0.64
                let boatY = h - 42
                var mainSail = Path()
                mainSail.move(to: CGPoint(x: boatX, y: boatY - 6))
                mainSail.addLine(to: CGPoint(x: boatX, y: boatY - 56))
                mainSail.addQuadCurve(to: CGPoint(x: boatX - 24, y: boatY - 6), control: CGPoint(x: boatX - 18, y: boatY - 28))
                mainSail.closeSubpath()
                context.fill(mainSail, with: .color(Color.white.opacity(0.65 * alpha)))
                context.stroke(mainSail, with: .color(accent.opacity(0.48 * alpha)), lineWidth: 1.2)
                var jibSail = Path()
                jibSail.move(to: CGPoint(x: boatX + 3, y: boatY - 6))
                jibSail.addLine(to: CGPoint(x: boatX + 3, y: boatY - 46))
                jibSail.addQuadCurve(to: CGPoint(x: boatX + 20, y: boatY - 6), control: CGPoint(x: boatX + 16, y: boatY - 22))
                jibSail.closeSubpath()
                context.fill(jibSail, with: .color(accent.opacity(0.28 * alpha)))
                context.stroke(jibSail, with: .color(accent.opacity(0.48 * alpha)), lineWidth: 1.1)
                var hull = Path()
                hull.move(to: CGPoint(x: boatX - 26, y: boatY - 4))
                hull.addLine(to: CGPoint(x: boatX + 24, y: boatY - 4))
                hull.addLine(to: CGPoint(x: boatX + 16, y: boatY + 5))
                hull.addLine(to: CGPoint(x: boatX - 20, y: boatY + 5))
                hull.closeSubpath()
                context.fill(hull, with: .color(accent.opacity(0.52 * alpha)))

                // 5. Layered manga sea waves & soaring seagulls
                for waveIdx in 0..<3 {
                    let baseY = h - CGFloat(16 + waveIdx * 13)
                    var wave = Path()
                    wave.move(to: CGPoint(x: 0, y: baseY))
                    let segW: CGFloat = 62
                    for i in 0..<max(1, Int(ceil(w / segW))) {
                        let x0 = CGFloat(i) * segW
                        wave.addQuadCurve(to: CGPoint(x: x0 + segW, y: baseY),
                                          control: CGPoint(x: x0 + segW * 0.5, y: baseY - CGFloat(8 - waveIdx * 2)))
                    }
                    context.stroke(wave, with: .color(accent.opacity((0.32 - Double(waveIdx) * 0.07) * alpha)), lineWidth: 1.4)
                }
                for (gx, gy, span) in [(w * 0.72, h * 0.16, CGFloat(13)), (w * 0.78, h * 0.12, CGFloat(9.5)), (w * 0.83, h * 0.18, CGFloat(11))] {
                    var gull = Path()
                    gull.move(to: CGPoint(x: gx - span, y: gy + 2))
                    gull.addQuadCurve(to: CGPoint(x: gx, y: gy + 4), control: CGPoint(x: gx - span * 0.5, y: gy - 5))
                    gull.addQuadCurve(to: CGPoint(x: gx + span, y: gy + 2), control: CGPoint(x: gx + span * 0.5, y: gy - 5))
                    context.stroke(gull, with: .color(accent.opacity(0.42 * alpha)), lineWidth: 1.35)
                }
            }
        }
    }

    // MARK: - 5. Fresh City Pop Manga Scenic Illustration (Tokyo Tower + Twilight Skyline + Train Overpass + Utility Pole & Crows)

    private func mangaCityIllustration(alpha: Double) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.46, blue: 0.56).opacity(0.15 * alpha),
                    accent.opacity(0.12 * alpha),
                    .clear
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let neonPink = Color(red: 0.97, green: 0.46, blue: 0.56)
                let warmWindow = Color(red: 0.99, green: 0.82, blue: 0.46)

                guard orbitals else { return }

                // 1. Foreground Right: Iconic Manga Utility Pole (街头电线杆) with Transformers & Sagging Power Cables
                let poleX = w - 64
                let poleTopY = h * 0.14
                var pole = Path()
                pole.move(to: CGPoint(x: poleX - 3.5, y: h))
                pole.addLine(to: CGPoint(x: poleX - 2.0, y: poleTopY))
                pole.addLine(to: CGPoint(x: poleX + 2.0, y: poleTopY))
                pole.addLine(to: CGPoint(x: poleX + 3.5, y: h))
                pole.closeSubpath()
                context.fill(pole, with: .color(accent.opacity(0.32 * alpha)))
                // Crossarms & transformer cylinder
                for armY in [poleTopY + 14, poleTopY + 34] {
                    context.fill(Path(CGRect(x: poleX - 26, y: armY, width: 52, height: 3.2)), with: .color(accent.opacity(0.36 * alpha)))
                }
                context.fill(Path(roundedRect: CGRect(x: poleX - 18, y: poleTopY + 44, width: 12, height: 22), cornerRadius: 3),
                             with: .color(accent.opacity(0.34 * alpha)))
                // Sagging overhead power cables across the upper-right sky
                for cIdx in 0..<3 {
                    let cy = poleTopY + 15 + CGFloat(cIdx) * 16
                    var wire = Path()
                    wire.move(to: CGPoint(x: w * 0.42, y: 0))
                    wire.addQuadCurve(to: CGPoint(x: poleX - 20 + CGFloat(cIdx) * 18, y: cy),
                                      control: CGPoint(x: w * 0.68, y: cy + 28))
                    wire.addQuadCurve(to: CGPoint(x: w, y: cy + 36),
                                      control: CGPoint(x: poleX + 32, y: cy + 24))
                    context.stroke(wire, with: .color(accent.opacity(0.26 * alpha)), lineWidth: 1.0)
                }

                // 2. Bottom Skyline + Tokyo Tower Communication Spire + Passing Commuter Train on Overpass
                let towerX = w - 185
                let towerBaseY = h - 36
                var spire = Path()
                spire.move(to: CGPoint(x: towerX - 22, y: towerBaseY))
                spire.addQuadCurve(to: CGPoint(x: towerX, y: towerBaseY - 145), control: CGPoint(x: towerX - 6, y: towerBaseY - 60))
                spire.addQuadCurve(to: CGPoint(x: towerX + 22, y: towerBaseY), control: CGPoint(x: towerX + 6, y: towerBaseY - 60))
                context.stroke(spire, with: .color(neonPink.opacity(0.45 * alpha)), lineWidth: 1.8)
                context.fill(Path(CGRect(x: towerX - 12, y: towerBaseY - 62, width: 24, height: 6)), with: .color(neonPink.opacity(0.42 * alpha)))

                // Skyscraper blocks
                let buildings: [(CGFloat, CGFloat, CGFloat)] = [
                    (w - 390, 42, 72), (w - 342, 50, 108), (w - 286, 44, 86),
                    (w - 236, 38, 64), (w - 142, 48, 96), (w - 90, 40, 78)
                ]
                for (bx, bw, bh) in buildings where bx > 0 {
                    let by = h - bh
                    let rect = CGRect(x: bx, y: by, width: bw, height: bh)
                    context.fill(Path(rect), with: .color(accent.opacity(0.14 * alpha)))
                    context.stroke(Path(rect), with: .color(accent.opacity(0.32 * alpha)), lineWidth: 1.1)
                    for wy in stride(from: by + 10, to: h - 38, by: 11) {
                        for wx in stride(from: bx + 7, to: bx + bw - 9, by: 10) {
                            context.fill(Path(CGRect(x: wx, y: wy, width: 4.5, height: 6)),
                                         with: .color(warmWindow.opacity(0.32 * alpha)))
                        }
                    }
                }

                // Elevated Railway Overpass & Glowing Commuter Train along bottom
                let bridgeY = h - 32
                context.fill(Path(CGRect(x: 0, y: bridgeY, width: w, height: 5)), with: .color(accent.opacity(0.28 * alpha)))
                for car in 0..<3 {
                    let cx = w - 360 + CGFloat(car) * 68
                    guard cx > 0 else { continue }
                    let carRect = CGRect(x: cx, y: bridgeY - 16, width: 62, height: 15)
                    context.fill(Path(roundedRect: carRect, cornerRadius: 3), with: .color(accent.opacity(0.34 * alpha)))
                    for wIdx in 0..<4 {
                        let winRect = CGRect(x: cx + 6 + CGFloat(wIdx) * 14, y: bridgeY - 12, width: 10, height: 7)
                        context.fill(Path(roundedRect: winRect, cornerRadius: 1.5), with: .color(warmWindow.opacity(0.58 * alpha)))
                    }
                }
            }
        }
    }

    // MARK: - 6. Fresh Forest Manga Scenic Illustration (Ancient Cedar Canopy + Komorebi Sunbeams + Stone Lantern + Kodama Spirits)

    private func mangaForestIllustration(alpha: Double) -> some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.18 * alpha), Color(red: 0.86, green: 0.94, blue: 0.76).opacity(0.08 * alpha), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let sunGold = Color(red: 0.95, green: 0.88, blue: 0.48)

                // 1. Slanted Komorebi (木漏日) sunbeams piercing from upper canopy
                for i in 0..<5 {
                    var beam = Path()
                    let startX = w * (0.06 + CGFloat(i) * 0.15)
                    let bw: CGFloat = 36 + CGFloat(i % 2) * 18
                    beam.move(to: CGPoint(x: startX, y: 0))
                    beam.addLine(to: CGPoint(x: startX + bw, y: 0))
                    beam.addLine(to: CGPoint(x: startX + bw + h * 0.38, y: h))
                    beam.addLine(to: CGPoint(x: startX + h * 0.38, y: h))
                    beam.closeSubpath()
                    context.fill(beam, with: .color(sunGold.opacity(0.14 * alpha)))
                }

                guard orbitals else { return }

                // 2. Right Edge: Ancient Cedar Tree Trunk, Branch & Layered Leaf Canopy
                var trunk = Path()
                trunk.move(to: CGPoint(x: w - 48, y: h))
                trunk.addQuadCurve(to: CGPoint(x: w - 34, y: 0), control: CGPoint(x: w - 56, y: h * 0.5))
                trunk.addLine(to: CGPoint(x: w, y: 0))
                trunk.addLine(to: CGPoint(x: w, y: h))
                trunk.closeSubpath()
                context.fill(trunk, with: .color(accent.opacity(0.22 * alpha)))
                // Extending horizontal tree bough
                var branch = Path()
                branch.move(to: CGPoint(x: w - 38, y: h * 0.28))
                branch.addQuadCurve(to: CGPoint(x: w - 210, y: h * 0.22), control: CGPoint(x: w - 120, y: h * 0.30))
                context.stroke(branch, with: .color(accent.opacity(0.34 * alpha)), lineWidth: 4.5)

                // Lush canopy puffs along top-right & top-left
                let puffs: [(CGFloat, CGFloat, CGFloat)] = [
                    (w - 40, 26, 68), (w - 110, 18, 58), (w - 175, 28, 48), (w - 230, 14, 42),
                    (46, 22, 56), (112, 14, 46)
                ]
                for (cx, cy, cr) in puffs {
                    let rect = CGRect(x: cx - cr, y: cy - cr * 0.5, width: cr * 2, height: cr * 1.6)
                    context.fill(Path(ellipseIn: rect), with: .color(accent.opacity(0.16 * alpha)))
                    context.stroke(Path(ellipseIn: rect), with: .color(accent.opacity(0.32 * alpha)), style: StrokeStyle(lineWidth: 1.1, dash: [6, 3]))
                }

                // 3. Cute Kodama (木灵 / 森林精灵) sitting on the tree branch
                for (kx, ky) in [(w - 145, h * 0.22 - 14), (w - 172, h * 0.21 - 11)] {
                    let head = CGRect(x: kx - 9, y: ky - 9, width: 18, height: 16)
                    context.fill(Path(ellipseIn: head), with: .color(Color.white.opacity(0.72 * alpha)))
                    context.stroke(Path(ellipseIn: head), with: .color(accent.opacity(0.45 * alpha)), lineWidth: 1.0)
                    context.fill(Path(ellipseIn: CGRect(x: kx - 4.5, y: ky - 3, width: 2.8, height: 3.2)), with: .color(accent.opacity(0.65)))
                    context.fill(Path(ellipseIn: CGRect(x: kx + 2.0, y: ky - 3, width: 2.8, height: 3.2)), with: .color(accent.opacity(0.65)))
                }

                // 4. Bottom-Right: Mossy Stone Lantern (春日石灯笼)
                let lx = w - 96
                let ly = h - 16
                // Pedestal & shaft
                context.fill(Path(CGRect(x: lx - 14, y: ly - 8, width: 28, height: 8)), with: .color(accent.opacity(0.28 * alpha)))
                context.fill(Path(CGRect(x: lx - 6, y: ly - 44, width: 12, height: 36)), with: .color(accent.opacity(0.26 * alpha)))
                // Firebox with warm glowing light
                let box = CGRect(x: lx - 11, y: ly - 62, width: 22, height: 18)
                context.fill(Path(box), with: .color(sunGold.opacity(0.55 * alpha)))
                context.stroke(Path(box), with: .color(accent.opacity(0.48 * alpha)), lineWidth: 1.2)
                // Curved stone roof (笠)
                var roof = Path()
                roof.move(to: CGPoint(x: lx - 22, y: ly - 62))
                roof.addQuadCurve(to: CGPoint(x: lx, y: ly - 78), control: CGPoint(x: lx - 10, y: ly - 74))
                roof.addQuadCurve(to: CGPoint(x: lx + 22, y: ly - 62), control: CGPoint(x: lx + 10, y: ly - 74))
                roof.closeSubpath()
                context.fill(roof, with: .color(accent.opacity(0.36 * alpha)))
            }
        }
    }

    // MARK: - 7. Shinkai Sky Scenic Illustration (Colossal Cumulonimbus + Splitting Comet + Railway Crossing)

    private func shinkaiSkyIllustration(alpha: Double) -> some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.18 * alpha), accent.opacity(0.05 * alpha), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // 1. Diagonal Tyndall sunbeams
                for i in 0..<4 {
                    var beam = Path()
                    let startX = w * (0.08 + CGFloat(i) * 0.16)
                    let beamW: CGFloat = 46 + CGFloat(i) * 18
                    beam.move(to: CGPoint(x: startX, y: 0))
                    beam.addLine(to: CGPoint(x: startX + beamW, y: 0))
                    beam.addLine(to: CGPoint(x: startX + beamW + h * 0.42, y: h))
                    beam.addLine(to: CGPoint(x: startX + h * 0.42, y: h))
                    beam.closeSubpath()
                    context.fill(beam, with: .color(Color.white.opacity(0.16 * alpha)))
                }

                guard orbitals else { return }

                // 2. Upper Sky: Splitting Tiamat Comet (《你的名字》双轨彗星弧光)
                var mainArc = Path()
                mainArc.move(to: CGPoint(x: w * 0.18, y: 14))
                mainArc.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.34), control: CGPoint(x: w * 0.56, y: h * 0.08))
                context.stroke(mainArc, with: .color(Color.white.opacity(0.58 * alpha)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                var splitArc = Path()
                splitArc.move(to: CGPoint(x: w * 0.42, y: h * 0.11))
                splitArc.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.40), control: CGPoint(x: w * 0.64, y: h * 0.18))
                context.stroke(splitArc, with: .color(Color(red: 0.98, green: 0.58, blue: 0.78).opacity(0.48 * alpha)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

                let cometHead = CGPoint(x: w * 0.86, y: h * 0.34)
                context.fill(Path(ellipseIn: CGRect(x: cometHead.x - 14, y: cometHead.y - 14, width: 28, height: 28)),
                             with: .color(Color(red: 0.45, green: 0.86, blue: 1.0).opacity(0.32 * alpha)))
                context.fill(Path(ellipseIn: CGRect(x: cometHead.x - 4.5, y: cometHead.y - 4.5, width: 9, height: 9)),
                             with: .color(Color.white.opacity(0.88 * alpha)))

                // 3. Bottom-Right: Towering Anvil Cumulonimbus Cloud (新海诚巨型入道云)
                let puffs: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.66, 0.94, 58), (0.74, 0.88, 78), (0.83, 0.82, 96),
                    (0.91, 0.76, 112), (0.97, 0.86, 84), (0.78, 0.95, 68)
                ]
                for (px, py, r) in puffs {
                    let rect = CGRect(x: w * px - r, y: h * py - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.44 * alpha)))
                    context.stroke(Path(ellipseIn: rect), with: .color(accent.opacity(0.22 * alpha)), lineWidth: 1.2)
                }

                // 4. Bottom-Left Foreground: Railway Crossing Warning Pole (踏切信号机)
                let rx: CGFloat = 58
                let ry: CGFloat = h - 12
                context.fill(Path(CGRect(x: rx - 2.5, y: ry - 92, width: 5, height: 92)), with: .color(accent.opacity(0.38 * alpha)))
                // Crossbuck X sign
                for rot in [-0.65, 0.65] {
                    let bar = Path(roundedRect: CGRect(x: -18, y: -2.5, width: 36, height: 5), cornerRadius: 1.5)
                        .applying(CGAffineTransform(translationX: rx, y: ry - 72).rotated(by: rot))
                    context.fill(bar, with: .color(Color.white.opacity(0.75 * alpha)))
                    context.stroke(bar, with: .color(accent.opacity(0.48 * alpha)), lineWidth: 1.0)
                }
                // Twin red warning lights
                for lx in [rx - 10, rx + 10] {
                    context.fill(Path(ellipseIn: CGRect(x: lx - 4, y: ry - 52, width: 8, height: 8)),
                                 with: .color(Color(red: 0.95, green: 0.28, blue: 0.32).opacity(0.65 * alpha)))
                }
            }
        }
    }

    // MARK: - 8. Chihiro Spirited Away Scenic Illustration (Aburaya Bathhouse + Haku White Dragon + Sea Train + Susuwatari)

    private func chihiroSpiritedAwayIllustration(alpha: Double) -> some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.96, green: 0.76, blue: 0.35).opacity(0.16 * alpha), accent.opacity(0.08 * alpha), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 560
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let lanternRed = Color(red: 0.86, green: 0.28, blue: 0.22)
                let lanternGold = Color(red: 0.96, green: 0.78, blue: 0.36)

                guard orbitals else { return }

                // 1. Upper Sky: Haku in White Dragon Form (琥珀川白龙) + Paper Shikigami Birds
                var dragon = Path()
                dragon.move(to: CGPoint(x: w * 0.56, y: 52))
                dragon.addCurve(to: CGPoint(x: w * 0.76, y: 44),
                                control1: CGPoint(x: w * 0.62, y: 18),
                                control2: CGPoint(x: w * 0.70, y: 74))
                dragon.addCurve(to: CGPoint(x: w * 0.92, y: 28),
                                control1: CGPoint(x: w * 0.82, y: 16),
                                control2: CGPoint(x: w * 0.88, y: 54))
                context.stroke(dragon, with: .color(Color.white.opacity(0.55 * alpha)), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                context.stroke(dragon, with: .color(accent.opacity(0.45 * alpha)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

                // 2. Bottom-Right: Aburaya Bathhouse (油屋多层汤屋楼阁) & Vermilion Bridge
                let bx = w - 115
                let by = h - 22
                for tier in 0..<3 {
                    let tf = CGFloat(tier)
                    let tw: CGFloat = 110 - tf * 22
                    let th: CGFloat = 28
                    let ty = by - (tf + 1) * th - tf * 6
                    let bodyRect = CGRect(x: bx - tw / 2, y: ty, width: tw, height: th)
                    context.fill(Path(bodyRect), with: .color(lanternRed.opacity(0.22 * alpha)))
                    context.stroke(Path(bodyRect), with: .color(lanternRed.opacity(0.45 * alpha)), lineWidth: 1.1)
                    // Glowing bathhouse windows
                    for wx in stride(from: bodyRect.minX + 10, to: bodyRect.maxX - 12, by: 14) {
                        context.fill(Path(CGRect(x: wx, y: ty + 8, width: 7, height: 11)),
                                     with: .color(lanternGold.opacity(0.52 * alpha)))
                    }
                    // Curved temple roof eave
                    var roof = Path()
                    roof.move(to: CGPoint(x: bx - tw / 2 - 12, y: ty))
                    roof.addQuadCurve(to: CGPoint(x: bx, y: ty - 10), control: CGPoint(x: bx - tw / 4, y: ty - 8))
                    roof.addQuadCurve(to: CGPoint(x: bx + tw / 2 + 12, y: ty), control: CGPoint(x: bx + tw / 4, y: ty - 8))
                    context.stroke(roof, with: .color(accent.opacity(0.52 * alpha)), lineWidth: 2.2)
                }

                // 3. Bottom-Left: Submerged Sea Train Tracks & 2-Car Sea Train (第六站海上列车) + Susuwatari
                let railY1 = h - 20
                let railY2 = h - 11
                var rails = Path()
                rails.move(to: CGPoint(x: 0, y: railY1))
                rails.addLine(to: CGPoint(x: w, y: railY1))
                rails.move(to: CGPoint(x: 0, y: railY2))
                rails.addLine(to: CGPoint(x: w, y: railY2))
                context.stroke(rails, with: .color(accent.opacity(0.24 * alpha)), lineWidth: 1.1)

                // Sea Train carriage silhouette
                let trainRect = CGRect(x: 115, y: railY1 - 24, width: 88, height: 22)
                context.fill(Path(roundedRect: trainRect, cornerRadius: 4), with: .color(lanternRed.opacity(0.26 * alpha)))
                context.stroke(Path(roundedRect: trainRect, cornerRadius: 4), with: .color(accent.opacity(0.42 * alpha)), lineWidth: 1.1)
                for wIdx in 0..<5 {
                    let wRect = CGRect(x: 123 + CGFloat(wIdx) * 15, y: railY1 - 19, width: 10, height: 9)
                    context.fill(Path(roundedRect: wRect, cornerRadius: 1.5), with: .color(lanternGold.opacity(0.55 * alpha)))
                }

                // Susuwatari (煤球精灵) & Konpeito (金平糖) in bottom-left
                for sc in [CGPoint(x: 34, y: h - 42), CGPoint(x: 62, y: h - 36)] {
                    let r: CGFloat = 7.5
                    context.fill(Path(ellipseIn: CGRect(x: sc.x - r, y: sc.y - r, width: r * 2, height: r * 2)),
                                 with: .color(Color.black.opacity(0.32 * alpha)))
                    context.fill(Path(ellipseIn: CGRect(x: sc.x - 3.2, y: sc.y - 2, width: 2.8, height: 2.8)), with: .color(.white.opacity(0.85)))
                    context.fill(Path(ellipseIn: CGRect(x: sc.x + 0.8, y: sc.y - 2, width: 2.8, height: 2.8)), with: .color(.white.opacity(0.85)))
                }
            }
        }
    }

    // MARK: - 9. Kanagawa Ukiyo-e Scenic Illustration (Mt. Fuji + Red Sun + Great Wave + Seigaiha + Hanko Seal)

    private func kanagawaUkiyoeIllustration(alpha: Double) -> some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.14 * alpha), .clear],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let vermilion = Color(red: 0.78, green: 0.22, blue: 0.20)

                guard orbitals else { return }

                // 1. Bottom-Right: Ukiyo-e Vermilion Sun & Snow-Capped Mt. Fuji (浮世绘红日与富士山)
                let fujiX = w - 155
                let fujiBaseY = h - 18
                let sunRect = CGRect(x: fujiX - 46, y: fujiBaseY - 125, width: 92, height: 92)
                context.fill(Path(ellipseIn: sunRect), with: .color(vermilion.opacity(0.22 * alpha)))

                var fuji = Path()
                fuji.move(to: CGPoint(x: fujiX - 125, y: fujiBaseY))
                fuji.addQuadCurve(to: CGPoint(x: fujiX - 16, y: fujiBaseY - 88), control: CGPoint(x: fujiX - 52, y: fujiBaseY - 18))
                fuji.addLine(to: CGPoint(x: fujiX + 16, y: fujiBaseY - 88))
                fuji.addQuadCurve(to: CGPoint(x: fujiX + 125, y: fujiBaseY), control: CGPoint(x: fujiX + 52, y: fujiBaseY - 18))
                fuji.closeSubpath()
                context.fill(fuji, with: .color(accent.opacity(0.26 * alpha)))
                context.stroke(fuji, with: .color(accent.opacity(0.48 * alpha)), lineWidth: 1.4)

                // Snow cap on Mt. Fuji
                var snow = Path()
                snow.move(to: CGPoint(x: fujiX - 16, y: fujiBaseY - 88))
                snow.addLine(to: CGPoint(x: fujiX + 16, y: fujiBaseY - 88))
                snow.addQuadCurve(to: CGPoint(x: fujiX + 36, y: fujiBaseY - 56), control: CGPoint(x: fujiX + 24, y: fujiBaseY - 70))
                snow.addLine(to: CGPoint(x: fujiX + 12, y: fujiBaseY - 64))
                snow.addLine(to: CGPoint(x: fujiX, y: fujiBaseY - 52))
                snow.addLine(to: CGPoint(x: fujiX - 14, y: fujiBaseY - 64))
                snow.addLine(to: CGPoint(x: fujiX - 36, y: fujiBaseY - 56))
                snow.closeSubpath()
                context.fill(snow, with: .color(Color.white.opacity(0.68 * alpha)))

                // 2. Seigaiha (青海波) concentric wave scales
                for c in [CGPoint(x: w - 42, y: 28), CGPoint(x: w - 88, y: 28), CGPoint(x: w - 65, y: 54),
                          CGPoint(x: 42, y: h - 22), CGPoint(x: 88, y: h - 22), CGPoint(x: 65, y: h - 46)] {
                    for r in [CGFloat(12), CGFloat(20), CGFloat(28)] {
                        var arc = Path()
                        arc.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                        context.stroke(arc, with: .color(accent.opacity(0.24 * alpha)), lineWidth: 1.1)
                    }
                }

                // 3. Vermilion Hanko seal in bottom-right corner
                let hankoRect = CGRect(x: max(12, w - 38), y: max(12, h - 42), width: 22, height: 22)
                context.stroke(Path(roundedRect: hankoRect, cornerRadius: 3), with: .color(vermilion.opacity(0.48 * alpha)), lineWidth: 1.4)
            }
        }
    }

    // MARK: - 10. Rose Dawn Scenic Illustration (Blooming Sakura Tree Branches + Cherry Blossoms + Ribbon Wave)

    private func roseDawnSakuraIllustration(alpha: Double) -> some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.18 * alpha), Color(red: 0.96, green: 0.76, blue: 0.72).opacity(0.08 * alpha), .clear],
                center: .topTrailing,
                startRadius: 16,
                endRadius: 520
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let woodCol = Color(red: 0.48, green: 0.34, blue: 0.38).opacity(0.32 * alpha)

                guard orbitals else { return }

                // 1. Top-Right Arching Cherry Blossom Branch (盛放樱花枝桠)
                var branch = Path()
                branch.move(to: CGPoint(x: w, y: 24))
                branch.addQuadCurve(to: CGPoint(x: w - 240, y: 88), control: CGPoint(x: w - 110, y: 18))
                branch.move(to: CGPoint(x: w - 95, y: 34))
                branch.addQuadCurve(to: CGPoint(x: w - 145, y: 128), control: CGPoint(x: w - 110, y: 84))
                context.stroke(branch, with: .color(woodCol), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

                // Detailed 5-petal Sakura blossoms along the branch
                let blossoms: [(CGFloat, CGFloat, CGFloat)] = [
                    (w - 48, 32, 1.15), (w - 92, 28, 1.0), (w - 138, 46, 1.2),
                    (w - 186, 66, 0.95), (w - 232, 86, 0.85), (w - 136, 118, 1.05)
                ]
                for (bx, by, sc) in blossoms {
                    for p in 0..<5 {
                        let ang = Double(p) * (.pi * 2 / 5) - .pi / 2
                        var petal = Path()
                        petal.move(to: .zero)
                        petal.addQuadCurve(to: CGPoint(x: 0, y: -13 * sc), control: CGPoint(x: -6.5 * sc, y: -7 * sc))
                        petal.addQuadCurve(to: .zero, control: CGPoint(x: 6.5 * sc, y: -7 * sc))
                        let tr = CGAffineTransform(translationX: bx, y: by).rotated(by: ang)
                        context.fill(petal.applying(tr), with: .color(accent.opacity(0.32 * alpha)))
                        context.stroke(petal.applying(tr), with: .color(accent.opacity(0.55 * alpha)), lineWidth: 0.75)
                    }
                    context.fill(Path(ellipseIn: CGRect(x: bx - 2.5, y: by - 2.5, width: 5, height: 5)),
                                 with: .color(Color(red: 0.96, green: 0.78, blue: 0.36).opacity(0.65 * alpha)))
                }

                // 2. Stitched ribbon wave along bottom
                var ribbon = Path()
                ribbon.move(to: CGPoint(x: 0, y: h * 0.86))
                ribbon.addCurve(
                    to: CGPoint(x: w, y: h * 0.78),
                    control1: CGPoint(x: w * 0.35, y: h * 0.94),
                    control2: CGPoint(x: w * 0.68, y: h * 0.70)
                )
                context.stroke(ribbon, with: .color(accent.opacity(0.24 * alpha)), style: StrokeStyle(lineWidth: 1.4, dash: [6, 5]))
            }
        }
    }

    // MARK: - 11. Akari Kyoto Scenic Illustration (Yasaka Five-Story Pagoda + Fushimi Inari Torii + Hanging Chochin Lanterns)

    private func akariKyotoIllustration(alpha: Double) -> some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.94, green: 0.58, blue: 0.28).opacity(0.18 * alpha), accent.opacity(0.06 * alpha), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 540
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height

                guard orbitals else { return }

                // 1. Overhead Kyoto alley wires & hanging Chochin lanterns
                var wire = Path()
                wire.move(to: CGPoint(x: 0, y: 18))
                wire.addQuadCurve(to: CGPoint(x: w, y: 14), control: CGPoint(x: w * 0.52, y: 44))
                context.stroke(wire, with: .color(accent.opacity(0.28 * alpha)), lineWidth: 1.0)

                for frac in [CGFloat(0.22), CGFloat(0.50), CGFloat(0.78)] {
                    let lx = w * frac
                    let ly: CGFloat = 36
                    context.fill(Path(ellipseIn: CGRect(x: lx - 26, y: ly - 18, width: 52, height: 52)),
                                 with: .color(accent.opacity(0.16 * alpha)))
                    let body = CGRect(x: lx - 10, y: ly - 6, width: 20, height: 18)
                    context.fill(Path(ellipseIn: body), with: .color(accent.opacity(0.36 * alpha)))
                    context.stroke(Path(ellipseIn: body), with: .color(accent.opacity(0.62 * alpha)), lineWidth: 1.0)
                }

                // 2. Bottom-Right: Kyoto Yasaka Five-Story Pagoda (八坂五重塔) Silhouette
                let px = w - 95
                let py = h - 14
                for level in 0..<5 {
                    let lf = CGFloat(level)
                    let rw: CGFloat = 68 - lf * 8
                    let ry = py - 24 - lf * 24
                    // Pagoda core wall
                    context.fill(Path(CGRect(x: px - (rw * 0.45), y: ry, width: rw * 0.9, height: 18)),
                                 with: .color(accent.opacity(0.20 * alpha)))
                    // Upcurved pagoda roof eave
                    var eave = Path()
                    eave.move(to: CGPoint(x: px - rw * 0.68, y: ry + 2))
                    eave.addQuadCurve(to: CGPoint(x: px, y: ry - 7), control: CGPoint(x: px - rw * 0.3, y: ry - 5))
                    eave.addQuadCurve(to: CGPoint(x: px + rw * 0.68, y: ry + 2), control: CGPoint(x: px + rw * 0.3, y: ry - 5))
                    eave.closeSubpath()
                    context.fill(eave, with: .color(accent.opacity(0.34 * alpha)))
                }
                // Pagoda finial spire (相轮)
                context.fill(Path(CGRect(x: px - 1.8, y: py - 172, width: 3.6, height: 28)), with: .color(accent.opacity(0.38 * alpha)))
            }
        }
    }

    // MARK: - 12. Matcha Chashitsu Scenic Illustration (Circular Zen Window + Bamboo Stalks + Chawan Tea Bowl & Shiratama)

    private func matchaChashitsuIllustration(alpha: Double) -> some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.15 * alpha), Color(red: 0.92, green: 0.96, blue: 0.90).opacity(0.07 * alpha), .clear],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            Canvas { context, size in
                let w = size.width
                let h = size.height

                guard orbitals else { return }

                // 1. Upper-Right: Chashitsu Circular Marumado Window (茶室圆窗) with Bamboo Stalks (修竹)
                let winCenter = CGPoint(x: w - 120, y: 115)
                let winR: CGFloat = 68
                let winRect = CGRect(x: winCenter.x - winR, y: winCenter.y - winR, width: winR * 2, height: winR * 2)
                context.stroke(Path(ellipseIn: winRect), with: .color(accent.opacity(0.32 * alpha)), lineWidth: 2.4)
                context.stroke(Path(ellipseIn: winRect.insetBy(dx: 5, dy: 5)), with: .color(accent.opacity(0.18 * alpha)), lineWidth: 0.9)

                // Bamboo stalks inside the circular window
                for bx in [winCenter.x - 22, winCenter.x + 6, winCenter.x + 28] {
                    var stalk = Path()
                    stalk.move(to: CGPoint(x: bx, y: winCenter.y + winR - 10))
                    stalk.addLine(to: CGPoint(x: bx - 4, y: winCenter.y - winR + 12))
                    context.stroke(stalk, with: .color(accent.opacity(0.34 * alpha)), lineWidth: 3.2)
                }

                // 2. Bottom-Right: Chawan Matcha Bowl, Zen Ripples & Shiratama Mochi
                let center = CGPoint(x: w * 0.86, y: h * 0.82)
                for r in [CGFloat(28), CGFloat(52), CGFloat(80), CGFloat(112)] {
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(accent.opacity(0.18 * alpha)), style: StrokeStyle(lineWidth: 1.1, dash: [8, 5]))
                }
                let s1 = CGRect(x: center.x - 18, y: center.y - 12, width: 16, height: 16)
                let s2 = CGRect(x: center.x + 2, y: center.y - 4, width: 14, height: 14)
                context.fill(Path(ellipseIn: s1), with: .color(Color.white.opacity(0.75 * alpha)))
                context.stroke(Path(ellipseIn: s1), with: .color(accent.opacity(0.32 * alpha)), lineWidth: 1.0)
                context.fill(Path(ellipseIn: s2), with: .color(Color.white.opacity(0.75 * alpha)))
                context.stroke(Path(ellipseIn: s2), with: .color(accent.opacity(0.32 * alpha)), lineWidth: 1.0)
            }
        }
    }

    // MARK: - 13. Space Observatory Scenic Illustration (Ringed Planet + Constellation Lines + Astrolabe Orbitals)

    private func spaceObservatoryIllustration(alpha: Double) -> some View {
        ZStack {
            RadialGradient(colors: [accent.opacity(0.16 * alpha), .clear], center: .topTrailing, startRadius: 30, endRadius: 580)
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // Starfield
                for i in 0..<52 {
                    let x = CGFloat((i * 79 + 23) % 1000) * w / 1000
                    let y = CGFloat((i * 151 + 61) % 1000) * h / 1000
                    let radius: CGFloat = i % 7 == 0 ? 1.5 : 0.9
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                                 with: .color(Color.white.opacity(i % 4 == 0 ? 0.45 : 0.22)))
                }

                guard orbitals else { return }

                // Ringed Exoplanet (土星环系行星) in upper-right
                let pCenter = CGPoint(x: w * 0.84, y: h * 0.20)
                let pRadius: CGFloat = 28
                context.fill(Path(ellipseIn: CGRect(x: pCenter.x - pRadius, y: pCenter.y - pRadius, width: pRadius * 2, height: pRadius * 2)),
                             with: .color(accent.opacity(0.28 * alpha)))
                context.stroke(Path(ellipseIn: CGRect(x: pCenter.x - pRadius, y: pCenter.y - pRadius, width: pRadius * 2, height: pRadius * 2)),
                               with: .color(accent.opacity(0.55 * alpha)), lineWidth: 1.2)
                // Tilted planetary rings
                for rw in [CGFloat(64), CGFloat(78)] {
                    let ringPath = Path(ellipseIn: CGRect(x: -rw, y: -rw * 0.26, width: rw * 2, height: rw * 0.52))
                        .applying(CGAffineTransform(translationX: pCenter.x, y: pCenter.y).rotated(by: -0.32))
                    context.stroke(ringPath, with: .color(Color.white.opacity(0.32 * alpha)), lineWidth: 1.1)
                }

                // Astrolabe orbital arcs
                for radius in [CGFloat(150), CGFloat(270), CGFloat(410)] {
                    var arc = Path()
                    arc.addArc(center: pCenter, radius: radius, startAngle: .degrees(105), endAngle: .degrees(255), clockwise: false)
                    context.stroke(arc, with: .color(Color.white.opacity(0.11 * alpha)), style: StrokeStyle(lineWidth: 0.85, dash: [5, 7]))
                }
            }
        }
    }
}
