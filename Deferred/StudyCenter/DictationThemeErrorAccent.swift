import SwiftUI

/// One brief, noninteractive accent per failed submission. No repeating timer.
/// Each of the 15 visual theme systems triggers its own unmistakable error visual effect:
/// - `monet`: Soft radial red glow
/// - `space`: Red radar laser scan line across the box
/// - `manga`: Comic exclamation stamp (!) + diagonal speed lines
/// - `mangaOcean`: Fresh Ocean Manga — Cerulean sea-splash comic callout ("WAVE! 浪花") + droplet speed lines
/// - `mangaCity`: Fresh City Pop Manga — Neon chromatic speech bubble ("⚡ RETRY!") + twin magenta/cyan offset frame
/// - `mangaForest`: Fresh Forest Manga — Komorebi leaf-whirl badge ("🍃 木叶") + emerald-amber double border pulse
/// - `nier`: NieR:Automata YoRHa — Tactical HUD alert ("◈ ALERT // LOGIC VIRUS") + horizontal glitch scanbars
/// - `wasteland`: Phosphor terminal glitch bar + "[ ERR ]" readout
/// - `zelda`: Zelda Sheikah/Hyrule — Heart Container damage flash ("♥") + Guardian target reticle & Triforce gold/red rim
/// - `shinkai`: Twin expanding iridescent prism halo rings
/// - `chihiro`: Spirited Away Susuwatari (煤球精灵) + Konpeito star candies burst badge
/// - `kanagawa`: Vermilion Japanese Hanko seal stamp ("再考") in top-right corner
/// - `roseDawn`: Drifting sakura petal scatter badge
/// - `akari`: Warm lantern flicker double-rim pulse
/// - `matcha`: Expanding Uji tea-whisk ripple rings
struct DictationThemeErrorAccent: View {
    let system: String
    let trigger: Int
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 1
    var body: some View {
        GeometryReader { geometry in
            if active && system == "monet" && !reduceMotion {
                ZStack {
                    RadialGradient(colors:[Color.red.opacity(0.17),.clear],center:.leading,startRadius:0,endRadius:max(1,geometry.size.width * 0.65))
                    RadialGradient(colors:[Color.red.opacity(0.10),.clear],center:.bottomTrailing,startRadius:0,endRadius:max(1,geometry.size.width * 0.45))
                }
                .clipShape(RoundedRectangle(cornerRadius:22))
                .scaleEffect(0.78 + progress * 0.22)
                .opacity(1 - progress)
            } else if active && system == "space" {
                ZStack {
                    if !reduceMotion {
                        RoundedRectangle(cornerRadius:22).strokeBorder(Color.red.opacity(0.75),lineWidth:1)
                            .scaleEffect(1 + progress * 0.055).opacity(1 - progress)
                        Rectangle().fill(LinearGradient(colors:[.clear,.red.opacity(0.8),.clear],startPoint:.top,endPoint:.bottom))
                            .frame(width:2,height:max(0,geometry.size.height - 24))
                            .position(x:12 + (geometry.size.width - 24) * progress,y:geometry.size.height / 2)
                            .opacity(1 - progress * 0.85)
                    }
                    RoundedRectangle(cornerRadius:22).strokeBorder(Color.red.opacity(0.9),lineWidth:1.2)
                }
            } else if active && system == "manga" {
                ZStack(alignment:.topTrailing) {
                    if !reduceMotion {
                        Canvas { context, size in
                            var strokes = Path()
                            for i in 0..<3 {
                                let gap = CGFloat(i) * 9
                                strokes.move(to:CGPoint(x:14 + gap,y:12))
                                strokes.addLine(to:CGPoint(x:34 + gap,y:32))
                                strokes.move(to:CGPoint(x:size.width - 14 - gap,y:size.height - 12))
                                strokes.addLine(to:CGPoint(x:size.width - 34 - gap,y:size.height - 32))
                            }
                            context.stroke(strokes,with:.color(Color.black),lineWidth:2)
                        }
                        .scaleEffect(1.035 - progress * 0.035).opacity(1 - progress)
                    }
                    Image(systemName:"exclamationmark").font(.system(size:24,weight:.black))
                        .foregroundStyle(Color.black).frame(width:32,height:36)
                        .background(Color.white).overlay(Rectangle().strokeBorder(Color.black,lineWidth:2))
                        .scaleEffect(reduceMotion ? 1 : 1.18 - progress * 0.18)
                        .padding(12)
                }
            } else if active && system == "mangaOcean" {
                // Fresh Ocean Manga: Sea-splash comic callout + cyan wave border
                let seaBlue = Color(red: 0.01, green: 0.52, blue: 0.78)
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(seaBlue, lineWidth: 2.2)
                    HStack(spacing: 4) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 12, weight: .bold))
                        Text("SPLASH!")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(seaBlue))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white, lineWidth: 1.2))
                    .scaleEffect(reduceMotion ? 1 : (1.18 - progress * 0.18))
                    .padding(12)
                }
            } else if active && system == "mangaCity" {
                // Fresh City Pop Manga: Twin neon magenta/cyan offset frame + comic callout
                let neonPink = Color(red: 0.97, green: 0.46, blue: 0.56)
                let neonBlue = Color(red: 0.48, green: 0.64, blue: 0.97)
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(neonBlue.opacity(0.85), lineWidth: 1.8)
                        .offset(x: 2, y: 2)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(neonPink, lineWidth: 2.0)
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("RETRY")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(neonPink))
                    .scaleEffect(reduceMotion ? 1 : (1.16 - progress * 0.16))
                    .padding(12)
                }
            } else if active && system == "mangaForest" {
                // Fresh Forest Manga: Komorebi leaf whirl + botanical dashed frame
                let forestGreen = Color(red: 0.23, green: 0.58, blue: 0.20)
                let autumnAmber = Color(red: 0.86, green: 0.52, blue: 0.24)
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(autumnAmber, style: StrokeStyle(lineWidth: 2.0, dash: [8, 4]))
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("木漏日")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(forestGreen)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(red: 0.96, green: 0.98, blue: 0.92)))
                    .overlay(Capsule().strokeBorder(forestGreen, lineWidth: 1.3))
                    .scaleEffect(reduceMotion ? 1 : (1.16 - progress * 0.16))
                    .padding(12)
                }
            } else if active && system == "nier" {
                // NieR:Automata YoRHa Tactical Alert HUD
                let alertRed = Color(red: 0.804, green: 0.400, blue: 0.302) // #CD664D
                let yorhaSand = Color(red: 0.855, green: 0.831, blue: 0.733) // #DAD4BB
                let yorhaDark = Color(red: 0.271, green: 0.255, blue: 0.220) // #454138
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(alertRed, lineWidth: 2.0)
                    if !reduceMotion {
                        Rectangle()
                            .fill(alertRed.opacity(0.28 * (1 - progress)))
                            .frame(height: 3)
                            .position(x: geometry.size.width / 2, y: 14 + (geometry.size.height - 28) * progress)
                    }
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(alertRed)
                            .frame(width: 4, height: 14)
                        Text("◈ ALERT // RETRY")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(yorhaSand)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Rectangle().fill(yorhaDark))
                    .overlay(Rectangle().strokeBorder(alertRed, lineWidth: 1.1))
                    .scaleEffect(reduceMotion ? 1 : (1.14 - progress * 0.14))
                    .padding(10)
                }
            } else if active && system == "wasteland" {
                // Wasteland terminal: phosphor glitch bar + bracketed "ERR" readout; brief, error-triggered only.
                let phosphor = Color(red: 0.106, green: 1.0, blue: 0.502) // #1BFF80
                let warn = Color(red: 1.0, green: 0.36, blue: 0.24)
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(warn.opacity(0.9), lineWidth: 1.8)
                    if !reduceMotion {
                        Rectangle()
                            .fill(phosphor.opacity(0.22 * (1 - progress)))
                            .frame(height: 6)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * (0.2 + 0.6 * progress))
                    }
                    Text("[ ERR // 拼写偏差 ]")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(phosphor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Rectangle().fill(Color(red: 0.03, green: 0.07, blue: 0.04)))
                        .overlay(Rectangle().strokeBorder(warn, lineWidth: 1.1))
                        .scaleEffect(reduceMotion ? 1 : (1.12 - progress * 0.12))
                        .padding(10)
                }
            } else if active && system == "zelda" {
                // The Legend of Zelda: Heart Container damage flash + Sheikah target reticle & golden/red double border
                let heartRed = Color(red: 0.945, green: 0.212, blue: 0.184) // #F1362F
                let sheikahBlue = Color(red: 0.235, green: 0.827, blue: 0.988) // #3CD3FC
                let triforceGold = Color(red: 0.988, green: 0.769, blue: 0.075) // #FCC413
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(heartRed.opacity(0.9), lineWidth: 1.8)
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(triforceGold.opacity(0.65), lineWidth: 1.0)
                        .padding(3)
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(heartRed)
                        Image(systemName: "scope")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(sheikahBlue)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.04, green: 0.08, blue: 0.16).opacity(0.92)))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(triforceGold, lineWidth: 1.1))
                    .scaleEffect(reduceMotion ? 1 : (1.18 - progress * 0.18))
                    .padding(12)
                }
            } else if active && system == "shinkai" {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [Color(red: 0.98, green: 0.42, blue: 0.58), Color(red: 0.32, green: 0.72, blue: 0.98), Color(red: 0.98, green: 0.42, blue: 0.58)],
                                center: .center
                            ),
                            lineWidth: 2.0
                        )
                        .frame(width: 96 + progress * 150, height: 96 + progress * 150)
                        .opacity(1 - progress)
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color(red: 0.96, green: 0.36, blue: 0.52).opacity(0.85), lineWidth: 1.8)
                }
            } else if active && system == "chihiro" {
                // Spirited Away: Susuwatari soot sprite & Konpeito star candy badge + Aburaya vermilion border
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color(red: 0.85, green: 0.27, blue: 0.22).opacity(0.88), lineWidth: 2.0)
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().fill(Color(red: 0.14, green: 0.14, blue: 0.16)).frame(width: 18, height: 18)
                            HStack(spacing: 2) {
                                Circle().fill(Color.white).frame(width: 4, height: 4)
                                Circle().fill(Color.white).frame(width: 4, height: 4)
                            }
                        }
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.88, green: 0.62, blue: 0.16))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(red: 0.99, green: 0.96, blue: 0.90)))
                    .overlay(Capsule().strokeBorder(Color(red: 0.85, green: 0.27, blue: 0.22).opacity(0.55), lineWidth: 1.1))
                    .scaleEffect(reduceMotion ? 1 : (1.16 - progress * 0.16))
                    .padding(14)
                }
            } else if active && system == "kanagawa" {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(red: 0.78, green: 0.18, blue: 0.16).opacity(0.88), lineWidth: 1.6)
                    Text("再考")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(Color(red: 0.78, green: 0.18, blue: 0.16))
                        .frame(width: 34, height: 34)
                        .background(Color(red: 0.98, green: 0.95, blue: 0.90))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color(red: 0.78, green: 0.18, blue: 0.16), lineWidth: 1.6)
                        )
                        .rotationEffect(.degrees(-6))
                        .scaleEffect(reduceMotion ? 1 : (1.22 - progress * 0.22))
                        .padding(14)
                }
            } else if active && system == "roseDawn" {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color(red: 0.84, green: 0.42, blue: 0.46), style: StrokeStyle(lineWidth: 1.8, dash: [6, 4]))
                    Image(systemName: "camera.macro")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.84, green: 0.42, blue: 0.46))
                        .padding(8)
                        .background(Circle().fill(Color(red: 0.99, green: 0.94, blue: 0.93)))
                        .scaleEffect(reduceMotion ? 1 : (1.15 - progress * 0.15))
                        .padding(14)
                }
            } else if active && system == "akari" {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color(red: 0.88, green: 0.42, blue: 0.20).opacity(1 - progress * 0.5), lineWidth: 2.2)
                    RadialGradient(
                        colors: [Color(red: 0.96, green: 0.62, blue: 0.24).opacity(0.22 * (1 - progress)), .clear],
                        center: .top,
                        startRadius: 8,
                        endRadius: max(1, geometry.size.width * 0.55)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            } else if active && system == "matcha" {
                ZStack {
                    Circle()
                        .strokeBorder(Color(red: 0.82, green: 0.36, blue: 0.32).opacity(1 - progress), style: StrokeStyle(lineWidth: 1.6, dash: [6, 4]))
                        .frame(width: 80 + progress * 130, height: 80 + progress * 130)
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color(red: 0.82, green: 0.36, blue: 0.32).opacity(0.85), lineWidth: 1.8)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id:trigger) {
            guard active, !reduceMotion else { return }
            withTransaction(Transaction(animation:nil)) { progress = 0 }
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration:system == "space" ? 0.46:(system == "manga" ? 0.24:0.5))) { progress = 1 }
        }
    }
}

/// Different impulses, same error semantics; Monet keeps its original effect.
struct IndependentDictationShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    let system: String
    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        let p = animatableData - floor(animatableData)
        let envelope = max(0,sin(p * .pi))
        let x: CGFloat
        let y: CGFloat
        switch system {
        case "space":
            x = 6 * sin(animatableData * .pi * 4) * envelope
            y = 0
        case "manga":
            x = 10 * sin(animatableData * .pi * 4) * envelope
            y = 0
        case "mangaOcean":
            x = 7.5 * sin(animatableData * .pi * 4) * envelope
            y = -2.0 * abs(sin(animatableData * .pi * 2)) * envelope
        case "mangaCity":
            x = 8.5 * sin(animatableData * .pi * 4) * envelope
            y = 0
        case "mangaForest":
            x = 6.0 * sin(animatableData * .pi * 3) * envelope
            y = -1.8 * sin(animatableData * .pi * 2) * envelope
        case "nier":
            x = 9.0 * sin(animatableData * .pi * 6) * envelope
            y = 0
        case "wasteland":
            x = 8.0 * sin(animatableData * .pi * 5) * envelope
            y = 0
        case "zelda":
            x = 7.0 * sin(animatableData * .pi * 4) * envelope
            y = -1.5 * abs(sin(animatableData * .pi * 2)) * envelope
        case "shinkai":
            x = 5.5 * sin(animatableData * .pi * 3) * envelope
            y = 0
        case "chihiro":
            x = 6.5 * sin(animatableData * .pi * 4) * envelope
            y = -2.5 * abs(sin(animatableData * .pi * 2)) * envelope
        case "kanagawa":
            x = 5.0 * sin(animatableData * .pi * 4) * envelope
            y = 0
        case "roseDawn":
            x = 5.0 * sin(animatableData * .pi * 3) * envelope
            y = -1.5 * sin(animatableData * .pi * 2) * envelope
        case "akari":
            x = 6.0 * sin(animatableData * .pi * 3) * envelope
            y = 0
        case "matcha":
            x = 5.2 * sin(animatableData * .pi * 3) * envelope
            y = 0
        default:
            x = 0
            y = 0
        }
        return ProjectionTransform(CGAffineTransform(translationX:x,y:y))
    }
}
