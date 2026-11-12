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
    @AppStorage(HeroImageStore.revisionKey) private var heroRevision = 0
    public var body: some View {
        VisualThemeBackdropDrawing(system: system, paper: paper, accent: accent, glow: glow,
                                   orbitals: orbitals, density: density, lineWeight: lineWeight,
                                   heroRevision: heroRevision).equatable()
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
    /// Plain Int instead of @AppStorage: a property wrapper is not Equatable, which
    /// broke the synthesized conformance and prevented the view from compiling.
    var heroRevision: Int
    init(system: String, paper: Color, accent: Color, glow: Double = 0.55,
                orbitals: Bool = true, density: Double = 0.35, lineWeight: Double = 1.5,
                heroRevision: Int = 0) {
        self.system = system; self.paper = paper; self.accent = accent
        self.glow = glow; self.orbitals = orbitals; self.density = density; self.lineWeight = lineWeight
        self.heroRevision = heroRevision
    }

    var body: some View {
        let custom = system == "monet" ? nil : HeroImageStore.load(system: system)
        ZStack {
            paper
            if system != "monet" && !(custom?.replaceBuiltIn ?? false) {
                scenicIllustrationLayer
                    .drawingGroup()
            }
            #if canImport(AppKit)
            if let custom { HeroImageLayer(settings: custom, paper: paper).id(heroRevision) }
            #endif
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 1.8.0：有主视觉的主题（地标建筑 + 原创角色）直接用大尺寸 HeroScenes，不再叠加旧的小插画。
    private var heroInk: Color {
        #if canImport(AppKit)
        if let c = NSColor(paper).usingColorSpace(.sRGB) {
            if c.alphaComponent < 0.5 { return accent }
            let lum = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
            return lum < 0.5 ? Color(white: 0.93) : Color(white: 0.10)
        }
        #endif
        return Color(white: 0.10)
    }

    private func heroLayer(alpha: Double) -> some View {
        ZStack {
            RadialGradient(colors: [accent.opacity(0.14 * alpha), .clear], center: .topTrailing, startRadius: 20, endRadius: 640)
            if system == "wasteland" {
                RadialGradient(colors: [.clear, Color.black.opacity(0.30 * alpha)], center: .center, startRadius: 260, endRadius: 980)
            }
            if system == "nier" || system == "wasteland" {
                // CRT 扫描线：单个 Path，一次绘制。
                Canvas { context, size in
                    var scan = Path()
                    var y: CGFloat = 0
                    let step: CGFloat = system == "wasteland" ? 3 : 5
                    while y < size.height { scan.move(to: CGPoint(x: 0, y: y)); scan.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                    context.stroke(scan, with: .color((system == "wasteland" ? Color.black : accent).opacity(system == "wasteland" ? 0.14 * alpha : 0.03 * alpha)), lineWidth: 0.7)
                }
            }
            if orbitals && (system != "manga" || density > 0.01) {
                HeroSceneLayer(system: system, accent: accent, ink: heroInk, alpha: alpha)
            }
        }
    }

    @ViewBuilder
    private var scenicIllustrationLayer: some View {
        let alpha = max(0.25, min(1.0, glow))
        if HeroScenes.has(system) {
            heroLayer(alpha: alpha)
        } else {
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
            case "wasteland":
                wastelandTerminalIllustration(alpha: alpha)
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
    }

    // MARK: - 1. NieR 废墟都市（1.8.0 重绘）
    // 苔绿色的坍塌城市：远景高楼剪影、断裂高架桥、垂落藤蔓与树冠、斜射光束；
    // 上层叠加米灰色战术 HUD（细线、方块标记、准星刻度）。不绘制任何角色形象。

    /// 固定种子的伪随机数，保证每次绘制完全一致（静态背景，无闪烁）。
    private struct SeededRandom {
        var state: UInt64
        mutating func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) & 0xFFFF) / 65535
        }
    }

    private func nierAutomataIllustration(alpha: Double) -> some View {
        let moss = Color(red: 0.34, green: 0.46, blue: 0.29)
        let leaf = Color(red: 0.45, green: 0.60, blue: 0.34)
        let concrete = Color(red: 0.55, green: 0.56, blue: 0.50)
        let sun = Color(red: 0.98, green: 0.96, blue: 0.86)
        return ZStack {
            // 雾气天空 + 左上角太阳眩光
            LinearGradient(colors: [moss.opacity(0.10 * alpha), leaf.opacity(0.06 * alpha), moss.opacity(0.22 * alpha)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [sun.opacity(0.42 * alpha), .clear], center: UnitPoint(x: 0.16, y: 0.08), startRadius: 4, endRadius: 520)
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var rng = SeededRandom(state: 0x9E3779B97F4A7C15)
                let groundY = h * 0.94

                // 1. 斜射光束（丁达尔效应）
                for i in 0..<4 {
                    let x0 = w * (0.06 + CGFloat(i) * 0.13)
                    var beam = Path()
                    beam.move(to: CGPoint(x: x0, y: 0))
                    beam.addLine(to: CGPoint(x: x0 + 34 + CGFloat(i) * 10, y: 0))
                    beam.addLine(to: CGPoint(x: x0 + w * 0.42 + CGFloat(i) * 30, y: h))
                    beam.addLine(to: CGPoint(x: x0 + w * 0.30 + CGFloat(i) * 22, y: h))
                    beam.closeSubpath()
                    context.fill(beam, with: .color(sun.opacity(0.07 * alpha)))
                }

                // 2. 远景：灰绿色高楼剪影（部分顶部断裂）
                var x: CGFloat = -10
                while x < w {
                    let bw = 34 + rng.next() * 46
                    let bh = h * (0.30 + rng.next() * 0.34)
                    var b = Path()
                    let top = groundY - bh
                    b.move(to: CGPoint(x: x, y: groundY))
                    b.addLine(to: CGPoint(x: x, y: top + rng.next() * 18))
                    b.addLine(to: CGPoint(x: x + bw * 0.45, y: top + rng.next() * 30))
                    b.addLine(to: CGPoint(x: x + bw * 0.62, y: top + 12 + rng.next() * 26))
                    b.addLine(to: CGPoint(x: x + bw, y: top + rng.next() * 14))
                    b.addLine(to: CGPoint(x: x + bw, y: groundY))
                    b.closeSubpath()
                    context.fill(b, with: .color(concrete.opacity(0.13 * alpha)))
                    x += bw + 6 + rng.next() * 18
                }

                guard orbitals else { return }

                // 3. 中景：带窗格的倾斜高楼、楼顶树冠与垂落藤蔓
                let mid: [(CGFloat, CGFloat, CGFloat, Double)] = [
                    (0.04, 0.10, 0.62, -0.035), (0.17, 0.08, 0.48, 0.02), (0.63, 0.09, 0.56, 0.03),
                    (0.76, 0.11, 0.70, -0.02), (0.90, 0.08, 0.44, 0.05)
                ]
                for (fx, fw, fh, tilt) in mid {
                    let bw = w * fw
                    let bh = h * fh
                    let tr = CGAffineTransform(translationX: w * fx, y: groundY).rotated(by: tilt)
                    var body = Path()
                    body.move(to: CGPoint(x: 0, y: 0))
                    body.addLine(to: CGPoint(x: 0, y: -bh))
                    body.addLine(to: CGPoint(x: bw * 0.55, y: -bh - 10))
                    body.addLine(to: CGPoint(x: bw * 0.70, y: -bh + 22))
                    body.addLine(to: CGPoint(x: bw, y: -bh + 8))
                    body.addLine(to: CGPoint(x: bw, y: 0))
                    body.closeSubpath()
                    context.fill(body.applying(tr), with: .color(concrete.opacity(0.20 * alpha)))
                    context.stroke(body.applying(tr), with: .color(moss.opacity(0.40 * alpha)), lineWidth: 0.9)
                    // 窗格（单一 Path，降低绘制调用）
                    var windows = Path()
                    var wy = -bh + 30
                    while wy < -16 {
                        var wx: CGFloat = 7
                        while wx < bw - 10 {
                            if rng.next() > 0.22 { windows.addRect(CGRect(x: wx, y: wy, width: 5, height: 7)) }
                            wx += 11
                        }
                        wy += 15
                    }
                    context.fill(windows.applying(tr), with: .color(moss.opacity(0.22 * alpha)))
                    // 楼顶树冠
                    var canopy = Path()
                    for k in 0..<5 {
                        let cx = bw * (0.08 + CGFloat(k) * 0.2)
                        let r = 9 + rng.next() * 10
                        canopy.addEllipse(in: CGRect(x: cx - r, y: -bh - r * 0.6, width: r * 2, height: r * 1.3))
                    }
                    context.fill(canopy.applying(tr), with: .color(leaf.opacity(0.42 * alpha)))
                    // 垂落藤蔓
                    var vines = Path()
                    for k in 0..<4 {
                        let vx = bw * (0.12 + CGFloat(k) * 0.24)
                        let len = bh * (0.18 + rng.next() * 0.42)
                        vines.move(to: CGPoint(x: vx, y: -bh + 4))
                        vines.addQuadCurve(to: CGPoint(x: vx + 4, y: -bh + len), control: CGPoint(x: vx - 9, y: -bh + len * 0.5))
                    }
                    context.stroke(vines.applying(tr), with: .color(leaf.opacity(0.55 * alpha)), lineWidth: 1.6)
                }

                // 4. 断裂高架桥 + 垂落钢筋
                let deckY = h * 0.70
                var deckL = Path(CGRect(x: -10, y: deckY, width: w * 0.40, height: 12))
                deckL = deckL.applying(CGAffineTransform(translationX: 0, y: 0))
                var deckR = Path()
                deckR.move(to: CGPoint(x: w * 0.52, y: deckY + 26))
                deckR.addLine(to: CGPoint(x: w + 10, y: deckY - 4))
                deckR.addLine(to: CGPoint(x: w + 10, y: deckY + 8))
                deckR.addLine(to: CGPoint(x: w * 0.52, y: deckY + 38))
                deckR.closeSubpath()
                context.fill(deckL, with: .color(concrete.opacity(0.30 * alpha)))
                context.fill(deckR, with: .color(concrete.opacity(0.30 * alpha)))
                var rebar = Path()
                for k in 0..<6 {
                    let rx = w * 0.40 - CGFloat(k) * 5
                    rebar.move(to: CGPoint(x: rx, y: deckY + 12))
                    rebar.addLine(to: CGPoint(x: rx + 6, y: deckY + 24 + CGFloat(k % 3) * 8))
                }
                context.stroke(rebar, with: .color(moss.opacity(0.45 * alpha)), lineWidth: 0.8)
                for px in [w * 0.12, w * 0.30, w * 0.70, w * 0.88] {
                    let pierTop = px < w * 0.5 ? deckY + 12 : deckY + 30 - (px - w * 0.52) / (w * 0.48) * 30
                    context.fill(Path(CGRect(x: px - 7, y: pierTop, width: 14, height: groundY - pierTop)), with: .color(concrete.opacity(0.24 * alpha)))
                }

                // 5. 地面草丛
                var grass = Path()
                var gx: CGFloat = -12
                while gx < w + 12 {
                    let r = 10 + rng.next() * 16
                    grass.addEllipse(in: CGRect(x: gx, y: groundY - r * 0.9, width: r * 2.2, height: r * 1.6))
                    gx += r * 1.4
                }
                grass.addRect(CGRect(x: 0, y: groundY, width: w, height: h - groundY))
                context.fill(grass, with: .color(leaf.opacity(0.36 * alpha)))

                // 6. 米灰战术 HUD：上方细线 + 方块、右侧准星刻度、淡扫描线
                let hud = accent.opacity(0.55 * alpha)
                var line = Path()
                line.move(to: CGPoint(x: 24, y: 22)); line.addLine(to: CGPoint(x: w * 0.42, y: 22))
                line.move(to: CGPoint(x: w * 0.58, y: 22)); line.addLine(to: CGPoint(x: w - 24, y: 22))
                context.stroke(line, with: .color(hud), lineWidth: 0.8)
                for k in 0..<3 {
                    context.fill(Path(CGRect(x: 24 + CGFloat(k) * 10, y: 28, width: 6, height: 6)), with: .color(hud))
                }
                let reticle = CGPoint(x: w * 0.84, y: h * 0.24)
                for (i, r) in [CGFloat(26), CGFloat(52)].enumerated() {
                    context.stroke(Path(ellipseIn: CGRect(x: reticle.x - r, y: reticle.y - r, width: r * 2, height: r * 2)),
                                   with: .color(hud), style: StrokeStyle(lineWidth: 0.9, dash: i == 1 ? [3, 5] : []))
                }
                var ticks = Path()
                for k in 0..<4 {
                    let a = Double(k) * .pi / 2
                    ticks.move(to: CGPoint(x: reticle.x + CGFloat(cos(a)) * 58, y: reticle.y + CGFloat(sin(a)) * 58))
                    ticks.addLine(to: CGPoint(x: reticle.x + CGFloat(cos(a)) * 70, y: reticle.y + CGFloat(sin(a)) * 70))
                }
                context.stroke(ticks, with: .color(hud), lineWidth: 1.1)
                var diamond = Path()
                diamond.move(to: CGPoint(x: reticle.x, y: reticle.y - 5)); diamond.addLine(to: CGPoint(x: reticle.x + 5, y: reticle.y))
                diamond.addLine(to: CGPoint(x: reticle.x, y: reticle.y + 5)); diamond.addLine(to: CGPoint(x: reticle.x - 5, y: reticle.y))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(hud))
                var scan = Path()
                var sy: CGFloat = 0
                while sy < h { scan.move(to: CGPoint(x: 0, y: sy)); scan.addLine(to: CGPoint(x: w, y: sy)); sy += 5 }
                context.stroke(scan, with: .color(accent.opacity(0.025 * alpha)), lineWidth: 0.6)
            }
        }
    }

    // MARK: - 1b. 废土终端（1.8.0 新增）
    // 荧光单色 CRT：暗角、细网格、扫描线；四角铆钉钢框、指针仪表、条形读数、
    // 线框式锈蚀天际线（水塔、电塔与下垂电线、断桥）。全部为一次性静态绘制。

    private func wastelandTerminalIllustration(alpha: Double) -> some View {
        let steel = Color(red: 0.37, green: 0.43, blue: 0.32)
        return ZStack {
            RadialGradient(colors: [accent.opacity(0.13 * alpha), .clear], center: .center, startRadius: 10, endRadius: 760)
            RadialGradient(colors: [.clear, Color.black.opacity(0.32 * alpha)], center: .center, startRadius: 280, endRadius: 980)
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let phosphor = accent

                // 1. 细网格 + 扫描线
                var grid = Path()
                var gx: CGFloat = 0
                while gx < w { grid.move(to: CGPoint(x: gx, y: 0)); grid.addLine(to: CGPoint(x: gx, y: h)); gx += 36 }
                var gy: CGFloat = 0
                while gy < h { grid.move(to: CGPoint(x: 0, y: gy)); grid.addLine(to: CGPoint(x: w, y: gy)); gy += 36 }
                context.stroke(grid, with: .color(phosphor.opacity(0.035 * alpha)), lineWidth: 0.5)
                var scan = Path()
                var sy: CGFloat = 0
                while sy < h { scan.move(to: CGPoint(x: 0, y: sy)); scan.addLine(to: CGPoint(x: w, y: sy)); sy += 3 }
                context.stroke(scan, with: .color(Color.black.opacity(0.16 * alpha)), lineWidth: 1)

                // 2. 四角铆钉钢框
                let inset: CGFloat = 10
                let arm: CGFloat = 46
                var bezel = Path()
                for (cx, cy, dx, dy) in [(inset, inset, 1.0, 1.0), (w - inset, inset, -1.0, 1.0), (inset, h - inset, 1.0, -1.0), (w - inset, h - inset, -1.0, -1.0)] {
                    bezel.move(to: CGPoint(x: cx, y: cy + CGFloat(dy) * arm))
                    bezel.addLine(to: CGPoint(x: cx, y: cy))
                    bezel.addLine(to: CGPoint(x: cx + CGFloat(dx) * arm, y: cy))
                    for k in 0..<2 {
                        let rx = cx + CGFloat(dx) * (14 + CGFloat(k) * 18)
                        let ry = cy + CGFloat(dy) * 7
                        context.fill(Path(ellipseIn: CGRect(x: rx - 2.2, y: ry - 2.2, width: 4.4, height: 4.4)), with: .color(steel.opacity(0.9 * alpha)))
                    }
                }
                context.stroke(bezel, with: .color(steel.opacity(0.85 * alpha)), style: StrokeStyle(lineWidth: 4, lineCap: .square))

                guard orbitals else { return }

                // 3. 顶部分段标签条
                var tabs = Path()
                tabs.move(to: CGPoint(x: w * 0.18, y: 30)); tabs.addLine(to: CGPoint(x: w * 0.82, y: 30))
                for k in 0...5 {
                    let tx = w * 0.18 + w * 0.64 * CGFloat(k) / 5
                    tabs.move(to: CGPoint(x: tx, y: 24)); tabs.addLine(to: CGPoint(x: tx, y: 36))
                }
                context.stroke(tabs, with: .color(phosphor.opacity(0.32 * alpha)), lineWidth: 1)

                // 4. 右上角指针仪表
                let gc = CGPoint(x: w * 0.85, y: h * 0.22)
                let gr: CGFloat = 46
                var dial = Path()
                dial.addArc(center: gc, radius: gr, startAngle: .degrees(150), endAngle: .degrees(390), clockwise: false)
                context.stroke(dial, with: .color(phosphor.opacity(0.55 * alpha)), lineWidth: 1.6)
                var dialTicks = Path()
                for k in 0...12 {
                    let a = (150.0 + 240.0 * Double(k) / 12.0) * .pi / 180
                    let r0 = gr - (k % 3 == 0 ? 11 : 6)
                    dialTicks.move(to: CGPoint(x: gc.x + CGFloat(cos(a)) * r0, y: gc.y + CGFloat(sin(a)) * r0))
                    dialTicks.addLine(to: CGPoint(x: gc.x + CGFloat(cos(a)) * gr, y: gc.y + CGFloat(sin(a)) * gr))
                }
                context.stroke(dialTicks, with: .color(phosphor.opacity(0.55 * alpha)), lineWidth: 1.1)
                let needleA = 236.0 * .pi / 180
                var needle = Path()
                needle.move(to: gc)
                needle.addLine(to: CGPoint(x: gc.x + CGFloat(cos(needleA)) * (gr - 6), y: gc.y + CGFloat(sin(needleA)) * (gr - 6)))
                context.stroke(needle, with: .color(phosphor.opacity(0.85 * alpha)), lineWidth: 2)
                context.fill(Path(ellipseIn: CGRect(x: gc.x - 4, y: gc.y - 4, width: 8, height: 8)), with: .color(steel.opacity(alpha)))

                // 5. 左侧条形读数 + 刻度尺
                let barBase = h * 0.42
                for k in 0..<5 {
                    let bh = CGFloat([52, 78, 40, 64, 30][k])
                    let rect = CGRect(x: 34 + CGFloat(k) * 12, y: barBase - bh, width: 7, height: bh)
                    context.fill(Path(rect), with: .color(phosphor.opacity(0.22 * alpha)))
                    context.stroke(Path(rect), with: .color(phosphor.opacity(0.45 * alpha)), lineWidth: 0.7)
                }
                var ruler = Path()
                for k in 0..<18 {
                    let ry = h * 0.48 + CGFloat(k) * 9
                    ruler.move(to: CGPoint(x: 26, y: ry)); ruler.addLine(to: CGPoint(x: k % 3 == 0 ? 40 : 33, y: ry))
                }
                context.stroke(ruler, with: .color(phosphor.opacity(0.32 * alpha)), lineWidth: 0.8)
                context.draw(Text("SIGNAL ▮▮▮▯  RAD 0.02").font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(phosphor.opacity(0.55 * alpha)),
                             at: CGPoint(x: 30, y: h - 30), anchor: .leading)

                // 6. 线框废土天际线
                let ground = h * 0.93
                var skyline = Path()
                skyline.move(to: CGPoint(x: 0, y: ground))
                let profile: [(CGFloat, CGFloat)] = [
                    (0.10, 0.80), (0.16, 0.80), (0.16, 0.66), (0.20, 0.62), (0.23, 0.70), (0.23, 0.78), (0.30, 0.78),
                    (0.30, 0.58), (0.33, 0.55), (0.35, 0.60), (0.37, 0.57), (0.37, 0.82), (0.55, 0.82), (0.55, 0.72),
                    (0.60, 0.72), (0.62, 0.64), (0.66, 0.68), (0.66, 0.84), (0.80, 0.84), (0.80, 0.70), (0.86, 0.66),
                    (0.86, 0.80), (1.00, 0.80)
                ]
                for (fx, fy) in profile { skyline.addLine(to: CGPoint(x: w * fx, y: h * fy)) }
                skyline.addLine(to: CGPoint(x: w, y: ground))
                skyline.closeSubpath()
                context.fill(skyline, with: .color(phosphor.opacity(0.07 * alpha)))
                context.stroke(skyline, with: .color(phosphor.opacity(0.42 * alpha)), lineWidth: 1.1)
                // 水塔
                let tc = CGPoint(x: w * 0.46, y: h * 0.62)
                context.stroke(Path(ellipseIn: CGRect(x: tc.x - 22, y: tc.y - 16, width: 44, height: 30)), with: .color(phosphor.opacity(0.5 * alpha)), lineWidth: 1.2)
                var legs = Path()
                for lx in [-16.0, -5.0, 5.0, 16.0] {
                    legs.move(to: CGPoint(x: tc.x + CGFloat(lx), y: tc.y + 12)); legs.addLine(to: CGPoint(x: tc.x + CGFloat(lx) * 1.4, y: h * 0.82))
                }
                legs.move(to: CGPoint(x: tc.x - 20, y: h * 0.72)); legs.addLine(to: CGPoint(x: tc.x + 20, y: h * 0.72))
                context.stroke(legs, with: .color(phosphor.opacity(0.45 * alpha)), lineWidth: 1)
                // 电塔与下垂电线
                var pylons = Path()
                for px in [w * 0.70, w * 0.93] {
                    pylons.move(to: CGPoint(x: px - 12, y: h * 0.84)); pylons.addLine(to: CGPoint(x: px, y: h * 0.52)); pylons.addLine(to: CGPoint(x: px + 12, y: h * 0.84))
                    pylons.move(to: CGPoint(x: px - 16, y: h * 0.57)); pylons.addLine(to: CGPoint(x: px + 16, y: h * 0.57))
                    pylons.move(to: CGPoint(x: px - 10, y: h * 0.66)); pylons.addLine(to: CGPoint(x: px + 10, y: h * 0.66))
                }
                pylons.move(to: CGPoint(x: w * 0.70 + 16, y: h * 0.57))
                pylons.addQuadCurve(to: CGPoint(x: w * 0.93 - 16, y: h * 0.57), control: CGPoint(x: w * 0.815, y: h * 0.66))
                pylons.move(to: CGPoint(x: w * 0.70 - 16, y: h * 0.57))
                pylons.addQuadCurve(to: CGPoint(x: w * 0.52, y: h * 0.62), control: CGPoint(x: w * 0.61, y: h * 0.66))
                context.stroke(pylons, with: .color(phosphor.opacity(0.38 * alpha)), lineWidth: 0.9)
                // 地平线
                var horizon = Path()
                horizon.move(to: CGPoint(x: 0, y: ground)); horizon.addLine(to: CGPoint(x: w, y: ground))
                context.stroke(horizon, with: .color(phosphor.opacity(0.5 * alpha)), lineWidth: 1.2)
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
