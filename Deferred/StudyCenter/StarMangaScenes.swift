import SwiftUI

// 星漫（太空 + 漫画）主题的场景绘制。
// 原则：宇宙是安静的背景，漫画元素只做点缀；所有图层不拦截点击；
// 开启「减少动态效果」时一律静止；会动的部分只用很小的 TimelineView，避免整页重绘。

/// 星漫的固定配色。
public enum StarMangaPalette {
    public static let sky = Color(red: 0.043, green: 0.063, blue: 0.125)        // #0B1020
    public static let panel = Color(red: 0.071, green: 0.094, blue: 0.188)      // #121830
    public static let panelRaised = Color(red: 0.078, green: 0.102, blue: 0.180) // #141A2E
    public static let paper = Color(red: 0.949, green: 0.933, blue: 0.894)      // #F2EEE4
    public static let ink = Color(red: 0.043, green: 0.043, blue: 0.071)        // #0B0B12
    public static let cyan = Color(red: 0.498, green: 0.831, blue: 1.0)         // #7FD4FF
    public static let alert = Color(red: 1.0, green: 0.361, blue: 0.424)        // #FF5C6C
    public static let gold = Color(red: 1.0, green: 0.824, blue: 0.369)         // #FFD25E
    public static let muted = Color(red: 0.604, green: 0.639, blue: 0.749)      // #9AA3BF
}

// MARK: - 网点星空（静态）

/// 漫画网点画的星空 + 几颗四角星 + 右下角半颗墨线星球。静态，不计时。
public struct StarMangaSkyLayer: View {
    public var showPlanet: Bool
    public init(showPlanet: Bool = true) { self.showPlanet = showPlanet }

    public var body: some View {
        Canvas { context, size in
            // 两层网点：疏而亮、密而暗
            let layers: [(step: CGFloat, radius: CGFloat, alpha: Double, shift: CGPoint)] = [
                (52, 1.1, 0.18, .zero), (23, 0.9, 0.08, CGPoint(x: 11, y: 7))
            ]
            for layer in layers {
                var y = layer.shift.y
                while y < size.height {
                    var x = layer.shift.x
                    while x < size.width {
                        let rect = CGRect(x: x - layer.radius, y: y - layer.radius, width: layer.radius * 2, height: layer.radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(StarMangaPalette.paper.opacity(layer.alpha)))
                        x += layer.step
                    }
                    y += layer.step
                }
            }
            // 四角星
            let sparkles: [(CGFloat, CGFloat, CGFloat, Color)] = [
                (0.14, 0.20, 9, StarMangaPalette.paper), (0.86, 0.15, 7, StarMangaPalette.paper),
                (0.90, 0.78, 8, StarMangaPalette.gold), (0.09, 0.74, 6, StarMangaPalette.cyan)
            ]
            for (fx, fy, r, color) in sparkles {
                context.fill(StarMangaShapes.sparkle(center: CGPoint(x: size.width * fx, y: size.height * fy), radius: r), with: .color(color.opacity(0.75)))
            }
            // 右下角半颗墨线星球
            if showPlanet {
                let r = min(size.width, size.height) * 0.28
                let center = CGPoint(x: size.width + r * 0.15, y: size.height + r * 0.25)
                let disc = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                context.fill(disc, with: .color(Color(red: 0.133, green: 0.188, blue: 0.353).opacity(0.55)))
                context.drawLayer { layer in
                    layer.clip(to: disc)
                    StarMangaShapes.halftone(in: &layer, rect: CGRect(x: center.x - r, y: center.y - r, width: r * 1.1, height: r * 2),
                                             step: 7, radius: 1.4, color: StarMangaPalette.ink.opacity(0.45))
                }
                context.stroke(disc, with: .color(StarMangaPalette.ink.opacity(0.9)), lineWidth: 2.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 自转的墨线星球（主页星轨用）

/// 一颗漫画星球：粗墨线轮廓、网点暗面、表面条纹随 phase 横向流动（看起来在自转）。
public struct StarPlanetDisc: View {
    public let base: Color
    public let band: Color
    public let phase: Double
    public let ringed: Bool
    public init(base: Color, band: Color, phase: Double, ringed: Bool = false) {
        self.base = base; self.band = band; self.phase = phase; self.ringed = ringed
    }

    public var body: some View {
        Canvas { context, size in
            let d = min(size.width, size.height) * (ringed ? 0.72 : 0.94)
            let rect = CGRect(x: (size.width - d) / 2, y: (size.height - d) / 2, width: d, height: d)
            let disc = Path(ellipseIn: rect)
            if ringed {
                let ring = Path(ellipseIn: CGRect(x: rect.minX - d * 0.22, y: rect.midY - d * 0.12, width: d * 1.44, height: d * 0.24))
                context.stroke(ring.applying(CGAffineTransform(translationX: -rect.midX, y: -rect.midY)
                    .concatenating(CGAffineTransform(rotationAngle: -0.24))
                    .concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY))),
                               with: .color(StarMangaPalette.ink), lineWidth: 2.5)
            }
            context.fill(disc, with: .color(base))
            context.drawLayer { layer in
                layer.clip(to: disc)
                // 表面条纹：两道宽带随 phase 平移，循环一个直径
                let travel = CGFloat(phase.truncatingRemainder(dividingBy: 1)) * d
                for offset in [-d, 0, d] {
                    let x = rect.minX + offset - travel
                    layer.fill(Path(CGRect(x: x + d * 0.35, y: rect.minY, width: d * 0.16, height: d)), with: .color(band))
                    layer.fill(Path(CGRect(x: x + d * 0.72, y: rect.minY, width: d * 0.08, height: d)), with: .color(band.opacity(0.7)))
                }
                // 暗面：右下方网点
                StarMangaShapes.halftone(in: &layer, rect: CGRect(x: rect.midX + d * 0.08, y: rect.minY, width: d * 0.5, height: d),
                                         step: 6, radius: 1.3, color: StarMangaPalette.ink.opacity(0.42))
            }
            context.stroke(disc, with: .color(StarMangaPalette.ink), lineWidth: 3)
            // 高光
            let glint = Path { p in
                p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: d * 0.36,
                         startAngle: .degrees(200), endAngle: .degrees(245), clockwise: false)
            }
            context.stroke(glint, with: .color(Color.white.opacity(0.65)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 月球基地听写场景

/// 宇航员的状态：平常、答错（挠头 + 汗珠 + 气泡）、答对（竖大拇指）。
public enum MoonBaseMood: Equatable, Sendable { case idle, wrong, correct }

/// 听写页的月球基地：月面、基地穹顶与天线、自转的地球、漫画宇航员。
/// 只放在四周空白处，作为背景，不拦截任何点击。
public struct MoonBaseScene: View {
    public let mood: MoonBaseMood
    public let dimmed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(mood: MoonBaseMood, dimmed: Bool) { self.mood = mood; self.dimmed = dimmed }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizon = size.height - max(150, size.height * 0.2)
            ZStack(alignment: .topLeading) {
                StarMangaSkyLayer(showPlanet: false)
                MoonTerrain(horizon: horizon)
                MoonBaseStation()
                    .frame(width: 300, height: 210)
                    .position(x: size.width - 160, y: horizon - 30)
                SpinningEarth(reduceMotion: reduceMotion)
                    .frame(width: 148, height: 148)
                    .position(x: size.width - 110, y: 150)
                MoonAstronaut(mood: mood, reduceMotion: reduceMotion)
                    .frame(width: 120, height: 172)
                    .position(x: 104, y: horizon + 6)
                if mood == .wrong {
                    Text("差一点\n订正后 ⌘R 再听")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StarMangaPalette.ink)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StarMangaPalette.paper))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(StarMangaPalette.ink, lineWidth: 2))
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StarMangaPalette.ink).offset(x: 3, y: 3))
                        .fixedSize()
                        .position(x: 108, y: horizon - 112)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: mood)
        }
        .opacity(dimmed ? 0.45 : 1)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: dimmed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MoonTerrain: View {
    let horizon: CGFloat
    var body: some View {
        Canvas { context, size in
            let h = horizon
            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: h))
            ground.addCurve(to: CGPoint(x: size.width * 0.5, y: h - 4),
                            control1: CGPoint(x: size.width * 0.16, y: h - 20), control2: CGPoint(x: size.width * 0.3, y: h + 16))
            ground.addCurve(to: CGPoint(x: size.width, y: h + 2),
                            control1: CGPoint(x: size.width * 0.7, y: h - 22), control2: CGPoint(x: size.width * 0.86, y: h - 18))
            var filled = ground
            filled.addLine(to: CGPoint(x: size.width, y: size.height))
            filled.addLine(to: CGPoint(x: 0, y: size.height))
            filled.closeSubpath()
            context.fill(filled, with: .linearGradient(Gradient(colors: [Color(red: 0.227, green: 0.259, blue: 0.408), Color(red: 0.114, green: 0.137, blue: 0.251)]),
                                                       startPoint: CGPoint(x: 0, y: h), endPoint: CGPoint(x: 0, y: size.height)))
            context.drawLayer { layer in
                layer.clip(to: filled)
                StarMangaShapes.halftone(in: &layer, rect: CGRect(x: 0, y: h - 24, width: size.width, height: size.height - h + 24),
                                         step: 7, radius: 1.3, color: StarMangaPalette.ink.opacity(0.28))
            }
            context.stroke(ground, with: .color(StarMangaPalette.ink), lineWidth: 3)
            let craters: [(CGFloat, CGFloat, CGFloat)] = [(0.26, 0.42, 60), (0.67, 0.72, 80), (0.44, 0.24, 28), (0.92, 0.78, 40)]
            let depth = size.height - h
            for (fx, fy, rx) in craters {
                let rect = CGRect(x: size.width * fx - rx, y: h + depth * fy - rx * 0.22, width: rx * 2, height: rx * 0.44)
                context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.165, green: 0.192, blue: 0.329)))
                context.stroke(Path(ellipseIn: rect), with: .color(StarMangaPalette.ink), lineWidth: 2.5)
            }
            // 宇航员身后一串脚印
            for i in 0..<4 {
                let rect = CGRect(x: 170 + CGFloat(i) * 26, y: h + 22 + CGFloat(i % 2) * 6, width: 14, height: 6)
                context.fill(Path(ellipseIn: rect), with: .color(StarMangaPalette.ink.opacity(0.45)))
            }
        }
    }
}

private struct MoonBaseStation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                let ink = StarMangaPalette.ink
                func shape(_ path: Path, _ fill: Color) {
                    context.fill(path, with: .color(fill))
                    context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                }
                // 太阳能板与支架
                shape(Path { p in p.move(to: CGPoint(x: 26, y: 66)); p.addLine(to: CGPoint(x: 88, y: 66)); p.addLine(to: CGPoint(x: 82, y: 92)); p.addLine(to: CGPoint(x: 20, y: 92)); p.closeSubpath() },
                      Color(red: 0.231, green: 0.310, blue: 0.561))
                context.stroke(Path { p in p.move(to: CGPoint(x: 50, y: 92)); p.addLine(to: CGPoint(x: 50, y: 118)) }, with: .color(ink), lineWidth: 2.5)
                // 舱段与舷窗
                shape(Path(roundedRect: CGRect(x: 10, y: 112, width: 92, height: 52), cornerRadius: 10), StarMangaPalette.paper.opacity(0.85))
                shape(Path(ellipseIn: CGRect(x: 27, y: 127, width: 18, height: 18)), StarMangaPalette.gold)
                shape(Path(ellipseIn: CGRect(x: 57, y: 127, width: 18, height: 18)), StarMangaPalette.gold)
                // 连接管
                shape(Path(CGRect(x: 98, y: 128, width: 40, height: 22)), StarMangaPalette.muted)
                // 穹顶
                let dome = Path { p in
                    p.move(to: CGPoint(x: 132, y: 164))
                    p.addArc(center: CGPoint(x: 214, y: 164), radius: 82, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    p.closeSubpath()
                }
                shape(dome, Color(red: 0.902, green: 0.914, blue: 0.949))
                context.stroke(Path { p in p.addArc(center: CGPoint(x: 214, y: 164), radius: 54, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false) },
                               with: .color(ink), lineWidth: 2)
                context.stroke(Path { p in p.move(to: CGPoint(x: 214, y: 82)); p.addLine(to: CGPoint(x: 214, y: 164)) }, with: .color(ink), lineWidth: 2)
                context.stroke(Path { p in p.move(to: CGPoint(x: 150, y: 134)); p.addLine(to: CGPoint(x: 278, y: 134)) },
                               with: .color(StarMangaPalette.gold), lineWidth: 5)
                // 天线
                context.stroke(Path { p in p.move(to: CGPoint(x: 250, y: 98)); p.addLine(to: CGPoint(x: 250, y: 32)) }, with: .color(ink), lineWidth: 2.5)
                shape(Path { p in p.addArc(center: CGPoint(x: 250, y: 46), radius: 16, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: true); p.closeSubpath() },
                      Color(red: 0.902, green: 0.914, blue: 0.949))
            }
            BeaconLight(reduceMotion: reduceMotion)
                .frame(width: 12, height: 12)
                .position(x: 250, y: 26)
        }
    }
}

private struct BeaconLight: View {
    let reduceMotion: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4)
            let on = reduceMotion || (t > 1.8 && t < 2.2)
            Circle()
                .fill(StarMangaPalette.alert.opacity(on ? 1 : 0.3))
                .overlay(Circle().strokeBorder(StarMangaPalette.ink, lineWidth: 2))
        }
    }
}

private struct SpinningEarth: View {
    let reduceMotion: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0.2 : timeline.date.timeIntervalSinceReferenceDate / 90
            StarPlanetDisc(base: Color(red: 0.239, green: 0.482, blue: 0.851),
                           band: Color(red: 0.435, green: 0.812, blue: 0.557),
                           phase: phase)
        }
    }
}

private struct MoonAstronaut: View {
    let mood: MoonBaseMood
    let reduceMotion: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
            let bob = reduceMotion ? 0 : sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 3.6) * 1.5
            Canvas { context, _ in
                let ink = StarMangaPalette.ink
                let paper = StarMangaPalette.paper
                func part(_ path: Path, _ fill: Color) {
                    context.fill(path, with: .color(fill))
                    context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                }
                context.translateBy(x: 0, y: CGFloat(bob))
                part(Path(roundedRect: CGRect(x: 22, y: 58, width: 76, height: 60), cornerRadius: 10), Color(red: 0.788, green: 0.812, blue: 0.890))
                part(Path(roundedRect: CGRect(x: 36, y: 122, width: 20, height: 34), cornerRadius: 8), paper)
                part(Path(roundedRect: CGRect(x: 64, y: 122, width: 20, height: 34), cornerRadius: 8), paper)
                part(Path(roundedRect: CGRect(x: 32, y: 150, width: 28, height: 14), cornerRadius: 6), StarMangaPalette.muted)
                part(Path(roundedRect: CGRect(x: 60, y: 150, width: 28, height: 14), cornerRadius: 6), StarMangaPalette.muted)
                part(Path(roundedRect: CGRect(x: 30, y: 70, width: 60, height: 58), cornerRadius: 16), paper)
                part(Path(roundedRect: CGRect(x: 48, y: 86, width: 24, height: 14), cornerRadius: 3), StarMangaPalette.cyan)
                part(Path(roundedRect: CGRect(x: 14, y: 76, width: 18, height: 44), cornerRadius: 9), paper)
                // 右臂：平常垂下；答错抬手挠头盔；答对举起大拇指
                switch mood {
                case .idle:
                    part(Path(roundedRect: CGRect(x: 88, y: 76, width: 18, height: 44), cornerRadius: 9), paper)
                case .wrong:
                    part(Path(roundedRect: CGRect(x: 86, y: 30, width: 18, height: 46), cornerRadius: 9)
                        .applying(CGAffineTransform(translationX: -95, y: -76).concatenating(CGAffineTransform(rotationAngle: -0.49)).concatenating(CGAffineTransform(translationX: 95, y: 76))), paper)
                case .correct:
                    part(Path(roundedRect: CGRect(x: 90, y: 40, width: 18, height: 40), cornerRadius: 9), paper)
                    part(Path(roundedRect: CGRect(x: 93, y: 26, width: 9, height: 18), cornerRadius: 4.5), paper)
                }
                context.stroke(Path { p in p.move(to: CGPoint(x: 60, y: 10)); p.addLine(to: CGPoint(x: 60, y: 2)) }, with: .color(ink), lineWidth: 2.5)
                part(Path(ellipseIn: CGRect(x: 26, y: 10, width: 68, height: 68)), paper)
                part(Path(ellipseIn: CGRect(x: 36, y: 29, width: 48, height: 36)), Color(red: 0.102, green: 0.145, blue: 0.314))
                context.fill(Path(ellipseIn: CGRect(x: 44, y: 37, width: 14, height: 8)), with: .color(Color.white.opacity(0.65)))
                let tip = mood == .wrong ? StarMangaPalette.alert : StarMangaPalette.cyan
                part(Path(ellipseIn: CGRect(x: 56.5, y: -1.5, width: 7, height: 7)), tip)
                if mood == .wrong {
                    let drop = Path { p in
                        p.move(to: CGPoint(x: 104, y: 14))
                        p.addCurve(to: CGPoint(x: 102, y: 30), control1: CGPoint(x: 100, y: 22), control2: CGPoint(x: 98, y: 26))
                        p.addCurve(to: CGPoint(x: 104, y: 14), control1: CGPoint(x: 110, y: 31), control2: CGPoint(x: 110, y: 22))
                    }
                    part(drop, StarMangaPalette.cyan)
                }
            }
        }
    }
}

// MARK: - 输入框装饰（只加角线与网点，不改尺寸）

/// 输入框四角的漫画分镜角线 + 底部一层渐隐网点。
public struct StarMangaPanelDecor: View {
    public let tint: Color
    public init(tint: Color) { self.tint = tint }
    public var body: some View {
        ZStack {
            Canvas { context, size in
                let inset: CGFloat = 14, arm: CGFloat = 18
                var corners = Path()
                corners.move(to: CGPoint(x: inset, y: inset + arm)); corners.addLine(to: CGPoint(x: inset, y: inset)); corners.addLine(to: CGPoint(x: inset + arm, y: inset))
                corners.move(to: CGPoint(x: size.width - inset - arm, y: inset)); corners.addLine(to: CGPoint(x: size.width - inset, y: inset)); corners.addLine(to: CGPoint(x: size.width - inset, y: inset + arm))
                corners.move(to: CGPoint(x: inset, y: size.height - inset - arm)); corners.addLine(to: CGPoint(x: inset, y: size.height - inset)); corners.addLine(to: CGPoint(x: inset + arm, y: size.height - inset))
                corners.move(to: CGPoint(x: size.width - inset - arm, y: size.height - inset)); corners.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset)); corners.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset - arm))
                context.stroke(corners, with: .color(tint), style: StrokeStyle(lineWidth: 3, lineCap: .square))
                let band = CGRect(x: 0, y: size.height - 70, width: size.width, height: 70)
                context.drawLayer { layer in
                    layer.clip(to: Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 22))
                    var y = band.minY
                    while y < band.maxY {
                        let fade = Double((y - band.minY) / band.height)
                        var x: CGFloat = 4
                        while x < size.width {
                            layer.fill(Path(ellipseIn: CGRect(x: x - 1.3, y: y - 1.3, width: 2.6, height: 2.6)), with: .color(tint.opacity(0.22 * fade)))
                            x += 8
                        }
                        y += 8
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 共用图形

enum StarMangaShapes {
    /// 四角星。
    static func sparkle(center c: CGPoint, radius r: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: c.x, y: c.y - r))
            p.addLine(to: CGPoint(x: c.x + r * 0.18, y: c.y - r * 0.18))
            p.addLine(to: CGPoint(x: c.x + r, y: c.y))
            p.addLine(to: CGPoint(x: c.x + r * 0.18, y: c.y + r * 0.18))
            p.addLine(to: CGPoint(x: c.x, y: c.y + r))
            p.addLine(to: CGPoint(x: c.x - r * 0.18, y: c.y + r * 0.18))
            p.addLine(to: CGPoint(x: c.x - r, y: c.y))
            p.addLine(to: CGPoint(x: c.x - r * 0.18, y: c.y - r * 0.18))
            p.closeSubpath()
        }
    }

    /// 在矩形里铺一层网点。
    static func halftone(in context: inout GraphicsContext, rect: CGRect, step: CGFloat, radius: CGFloat, color: Color) {
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
                x += step
            }
            y += step
        }
    }
}
