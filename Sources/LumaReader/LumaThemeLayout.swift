import SwiftUI

// MARK: - 主题专属布局（1.8.0）
//
// 之前所有主题共用同一套布局，只换颜色和背景插画，看起来高度重复。
// 这里为每个主题定义一份静态「布局档案」：侧栏在左还是在右、阅读顶栏七键的排布、
// 书库标题区的排布、标题字体、书封装饰。全部是值类型的静态描述，不含计时器或常驻动画；
// 切换主题只是换一份档案，不会增加持续的渲染开销。
//
// 明确不受影响的部分（按用户要求）：听写输入框的尺寸与位置、听写进度条、错误反馈、
// 写作高亮与笔记流程。听写练习时侧栏宽度为 0，所以侧栏左右切换不会移动听写输入框。

/// 阅读器顶栏七个功能键的排布方式。七个键的数量、功能与组内顺序保持不变。
enum LumaReaderHeaderArrangement: String, Sendable {
    /// 原始布局：左侧四键（返回、搜索、目录、笔记），右侧三键（设置、AI、书签），书名居中。
    case split
    /// 战术/终端风：七键合并为紧贴红黄绿的一条长栏，书名靠右。
    case unifiedLeading
    /// 浮岛风：两组胶囊并排居中，书名靠右。
    case centerDock
}

/// 书库标题行（标题 + 搜索/更多胶囊）的排布方式。
enum LumaLibraryHeaderArrangement: String, Sendable {
    case titleLeading   // 标题左、工具右（原始）
    case toolsLeading   // 工具左、标题右
    case stacked        // 标题在上、工具在下
    case centered       // 标题与工具居中堆叠
}

enum LumaHeadingDesign: String, Sendable {
    case user, serif, rounded, monospaced, sans
    var fontDesign: Font.Design? {
        switch self {
        case .user: return nil
        case .serif: return .serif
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        case .sans: return .default
        }
    }
}

enum LumaHeadingWeight: String, Sendable {
    case light, regular, medium, semibold, heavy
    var weight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .heavy: return .heavy
        }
    }
}

/// 书封装饰。全部是静态形状，无模糊阴影（模糊阴影在大书架上开销最大）。
enum LumaShelfOrnament: String, Sendable {
    case none, glassSheen, paperStack, softBloom, glowRim
    case inkPanel, neonOffset, leafTape
    case tacticalBrackets, terminalPlate, runeFrame
    case cloudSoft, vermilionBeam, sealStamp, washiTape, lanternGlow, porcelain, orbitRim
}

struct LumaThemeLayout: Equatable, Sendable {
    var sidebarOnTrailing: Bool = false
    var readerHeader: LumaReaderHeaderArrangement = .split
    var libraryHeader: LumaLibraryHeaderArrangement = .titleLeading
    var headingDesign: LumaHeadingDesign = .user
    var headingWeight: LumaHeadingWeight = .medium
    var headingTracking: CGFloat = 0
    var headingPrefix: String = ""
    var headingCaption: String? = nil
    var brandSymbol: String = "book.closed.fill"
    var ornament: LumaShelfOrnament = .glassSheen
    var gridSpacing: CGFloat = 28
    var gridRowSpacing: CGFloat = 30

    /// 关闭「主题专属布局」时使用的统一布局（与 1.7.x 一致）。
    static let standard = LumaThemeLayout(ornament: .none)

    static func resolve(system: LumaVisualThemeSystem, classic: ReaderTheme, monetEnabled: Bool) -> LumaThemeLayout {
        switch system {
        case .monet:
            if monetEnabled {
                return LumaThemeLayout(headingCaption: "MONET · 封面取色", brandSymbol: "paintpalette.fill", ornament: .glassSheen)
            }
            switch classic {
            case .paper:
                return LumaThemeLayout(libraryHeader: .centered, headingDesign: .serif, headingWeight: .regular,
                                       headingTracking: 1, headingCaption: "书房 · LIBRARY", brandSymbol: "book.closed.fill",
                                       ornament: .paperStack, gridSpacing: 30, gridRowSpacing: 34)
            case .mint:
                return LumaThemeLayout(libraryHeader: .stacked, headingDesign: .rounded, headingWeight: .semibold,
                                       headingCaption: "青苔 · SAGE", brandSymbol: "leaf.fill", ornament: .glassSheen)
            case .rose:
                return LumaThemeLayout(readerHeader: .centerDock, libraryHeader: .stacked, headingDesign: .rounded,
                                       headingCaption: "花信 · BLOOM", brandSymbol: "camera.macro", ornament: .softBloom,
                                       gridSpacing: 30, gridRowSpacing: 32)
            case .midnight:
                return LumaThemeLayout(sidebarOnTrailing: true, libraryHeader: .toolsLeading, headingDesign: .sans,
                                       headingWeight: .light, headingTracking: 2, headingCaption: "夜读 · NOCTURNE",
                                       brandSymbol: "moon.stars.fill", ornament: .glowRim)
            case .black:
                return LumaThemeLayout(readerHeader: .unifiedLeading, headingDesign: .sans, headingWeight: .semibold,
                                       headingTracking: -0.5, brandSymbol: "circle.lefthalf.filled", ornament: .none,
                                       gridSpacing: 22, gridRowSpacing: 26)
            }
        case .space:
            return LumaThemeLayout(sidebarOnTrailing: true, readerHeader: .centerDock, libraryHeader: .centered,
                                   headingDesign: .sans, headingWeight: .light, headingTracking: 4,
                                   headingCaption: "OBSERVATORY · 观星台", brandSymbol: "sparkles", ornament: .orbitRim,
                                   gridSpacing: 32, gridRowSpacing: 34)
        case .manga:
            return LumaThemeLayout(libraryHeader: .stacked, headingDesign: .sans, headingWeight: .heavy,
                                   headingCaption: "第 1 话 · CHAPTER 01", brandSymbol: "book.pages.fill", ornament: .inkPanel,
                                   gridSpacing: 26, gridRowSpacing: 32)
        case .mangaOcean:
            return LumaThemeLayout(readerHeader: .centerDock, headingDesign: .rounded, headingWeight: .heavy,
                                   headingCaption: "海风 · SEA BREEZE", brandSymbol: "sailboat.fill", ornament: .inkPanel)
        case .mangaCity:
            return LumaThemeLayout(sidebarOnTrailing: true, readerHeader: .unifiedLeading, libraryHeader: .toolsLeading,
                                   headingDesign: .sans, headingWeight: .heavy, headingTracking: 1,
                                   headingCaption: "CITY POP · 都市", brandSymbol: "building.2.fill", ornament: .neonOffset)
        case .mangaForest:
            return LumaThemeLayout(readerHeader: .centerDock, libraryHeader: .stacked, headingDesign: .rounded,
                                   headingWeight: .semibold, headingCaption: "森 · KOMOREBI", brandSymbol: "tree.fill",
                                   ornament: .leafTape)
        case .nier:
            return LumaThemeLayout(readerHeader: .unifiedLeading, libraryHeader: .stacked, headingDesign: .sans,
                                   headingWeight: .light, headingTracking: 3, headingPrefix: "■ ",
                                   headingCaption: "ARCHIVE // 废墟都市 · 资料库", brandSymbol: "square.grid.3x3.square",
                                   ornament: .tacticalBrackets, gridSpacing: 34, gridRowSpacing: 38)
        case .wasteland:
            return LumaThemeLayout(sidebarOnTrailing: true, readerHeader: .centerDock, libraryHeader: .toolsLeading,
                                   headingDesign: .monospaced, headingWeight: .semibold, headingTracking: 1,
                                   headingPrefix: "> ", headingCaption: "TERMINAL · 废土档案库 [ONLINE]",
                                   brandSymbol: "gauge.with.dots.needle.33percent", ornament: .terminalPlate,
                                   gridSpacing: 32, gridRowSpacing: 36)
        case .zelda:
            return LumaThemeLayout(readerHeader: .centerDock, libraryHeader: .centered, headingDesign: .serif,
                                   headingWeight: .regular, headingTracking: 2, headingCaption: "古代石板 · ARCHIVE",
                                   brandSymbol: "shield.lefthalf.filled", ornament: .runeFrame, gridSpacing: 32, gridRowSpacing: 36)
        case .shinkai:
            return LumaThemeLayout(readerHeader: .centerDock, libraryHeader: .centered, headingDesign: .rounded,
                                   headingWeight: .semibold, headingCaption: "晴空 · BLUE SKY", brandSymbol: "cloud.sun.fill",
                                   ornament: .cloudSoft, gridSpacing: 30, gridRowSpacing: 34)
        case .chihiro:
            return LumaThemeLayout(sidebarOnTrailing: true, headingDesign: .serif, headingWeight: .semibold,
                                   headingCaption: "汤屋 · 物语", brandSymbol: "tram.fill.tunnel", ornament: .vermilionBeam,
                                   gridRowSpacing: 34)
        case .kanagawa:
            return LumaThemeLayout(sidebarOnTrailing: true, libraryHeader: .toolsLeading, headingDesign: .serif,
                                   headingWeight: .regular, headingTracking: 2, headingCaption: "浮世 · UKIYO",
                                   brandSymbol: "water.waves", ornament: .sealStamp)
        case .roseDawn:
            return LumaThemeLayout(readerHeader: .centerDock, libraryHeader: .stacked, headingDesign: .rounded,
                                   headingCaption: "晨曦手账 · DIARY", brandSymbol: "camera.macro", ornament: .washiTape,
                                   gridSpacing: 30, gridRowSpacing: 36)
        case .akari:
            return LumaThemeLayout(sidebarOnTrailing: true, libraryHeader: .centered, headingDesign: .serif,
                                   headingWeight: .regular, headingTracking: 1, headingCaption: "古巷 · 灯火",
                                   brandSymbol: "lightbulb.max.fill", ornament: .lanternGlow, gridRowSpacing: 40)
        case .matcha:
            return LumaThemeLayout(readerHeader: .centerDock, headingDesign: .rounded, headingWeight: .semibold,
                                   headingCaption: "茶席 · TEA", brandSymbol: "cup.and.saucer.fill", ornament: .porcelain,
                                   gridSpacing: 30, gridRowSpacing: 34)
        }
    }
}

extension LibraryStore {
    /// 当前主题的布局档案；关闭「主题专属布局」时回到统一布局。
    var themeLayout: LumaThemeLayout {
        guard themeSpecificLayout else { return .standard }
        return LumaThemeLayout.resolve(system: visualThemeSystem, classic: theme, monetEnabled: monetEnabled)
    }

    /// 主题标题字体：字体由主题决定；用户导入的自定义字体仍然优先。
    func themeHeadingFont(_ size: CGFloat, layout: LumaThemeLayout) -> Font {
        homeFont(size, weight: layout.headingWeight.weight, design: layout.headingDesign.fontDesign)
    }
}

// MARK: - 书封装饰

private struct LumaCornerBrackets: Shape {
    var length: CGFloat = 14
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = min(length, rect.width / 3, rect.height / 3)
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

/// 单个 Path 画出整片扫描线，比逐行视图便宜得多。
struct LumaScanlines: Shape {
    var spacing: CGFloat = 3
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y = rect.minY
        while y < rect.maxY {
            p.move(to: CGPoint(x: rect.minX, y: y)); p.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += max(1.5, spacing)
        }
        return p
    }
}

struct LumaShelfOrnamentModifier: ViewModifier {
    let style: LumaShelfOrnament
    let accent: Color
    let ink: Color
    let paper: Color
    let dark: Bool

    @ViewBuilder func body(content: Content) -> some View {
        switch style {
        case .none:
            content
        case .glassSheen:
            content.overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.30 : 0.60), .white.opacity(0), accent.opacity(0.28)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .allowsHitTesting(false))
        case .paperStack:
            // 一摞纸：后面两张错位的纸页
            content.background {
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(ink.opacity(0.07)).offset(x: 7, y: 6)
                    RoundedRectangle(cornerRadius: 3).fill(paper)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(ink.opacity(0.12), lineWidth: 0.6))
                        .offset(x: 3.5, y: 3)
                }
            }
        case .softBloom:
            content
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accent.opacity(dark ? 0.20 : 0.14)).padding(-6))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(dark ? 0.18 : 0.7), lineWidth: 1.2).allowsHitTesting(false))
        case .glowRim:
            content
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(accent.opacity(0.10)).padding(-5))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(accent.opacity(0.55), lineWidth: 1).allowsHitTesting(false))
        case .inkPanel:
            content
                .background(Rectangle().fill(ink).offset(x: 4, y: 4))
                .overlay(Rectangle().strokeBorder(ink, lineWidth: 2).allowsHitTesting(false))
        case .neonOffset:
            content
                .background(ZStack {
                    Rectangle().fill(accent.opacity(0.85)).offset(x: 5, y: 5)
                    Rectangle().fill(Color(hex: "7AA2F7").opacity(0.65)).offset(x: -3, y: -3)
                })
                .overlay(Rectangle().strokeBorder(ink.opacity(0.9), lineWidth: 1.5).allowsHitTesting(false))
        case .leafTape:
            content
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(accent.opacity(0.55), lineWidth: 1.2).allowsHitTesting(false))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "leaf.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                        .rotationEffect(.degrees(-24)).offset(x: 7, y: -8).allowsHitTesting(false)
                }
        case .tacticalBrackets:
            content
                .overlay(LumaCornerBrackets(length: 16).stroke(ink.opacity(0.85), lineWidth: 1.5).padding(-6).allowsHitTesting(false))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 3) {
                        Rectangle().fill(accent).frame(width: 6, height: 6)
                        Rectangle().fill(ink.opacity(0.55)).frame(width: 22, height: 1)
                    }
                    .offset(x: -6, y: 13).allowsHitTesting(false)
                }
        case .terminalPlate:
            // 铆钉钢板 + 荧光单色显像：封面被「显示」在终端屏幕上
            let steel = Color(hex: dark ? "2A3127" : "B9BFAA")
            let rim = Color(hex: dark ? "5F6D52" : "7E8870")
            // 暗色 CRT：封面去色后乘以荧光色；日光版保持原封面（colorMultiply(.white) 为恒等）。
            content
                .grayscale(dark ? 1 : 0)
                .colorMultiply(dark ? ink : .white)
                .overlay(LumaScanlines(spacing: 3).stroke(Color.black.opacity(dark ? 0.28 : 0.10), lineWidth: 0.8).allowsHitTesting(false))
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(steel)
                        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(rim, lineWidth: 2))
                        .padding(-7)
                )
                .overlay {
                    GeometryReader { geo in
                        let w = geo.size.width, h = geo.size.height
                        ForEach(0..<4, id: \.self) { i in
                            Circle().fill(rim).frame(width: 4, height: 4)
                                .position(x: i % 2 == 0 ? -3.5 : w + 3.5, y: i < 2 ? -3.5 : h + 3.5)
                        }
                    }
                    .allowsHitTesting(false)
                }
        case .runeFrame:
            content
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(accent.opacity(0.75), lineWidth: 1).padding(-4).allowsHitTesting(false))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: "E2DED3").opacity(0.45), lineWidth: 0.8).padding(-7).allowsHitTesting(false))
                .overlay(alignment: .top) {
                    Rectangle().fill(accent).frame(width: 7, height: 7).rotationEffect(.degrees(45)).offset(y: -8).allowsHitTesting(false)
                }
        case .cloudSoft:
            content
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(dark ? 0.10 : 0.62)).padding(-6))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(dark ? 0.22 : 0.8), lineWidth: 1).allowsHitTesting(false))
        case .vermilionBeam:
            content
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(hex: "D94E3E")).frame(height: 5).padding(.horizontal, -6).offset(y: -8).allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(accent.opacity(0.8)).frame(height: 2).allowsHitTesting(false)
                }
        case .sealStamp:
            content
                .overlay(Rectangle().strokeBorder(ink.opacity(0.25), lineWidth: 0.8).padding(-4).allowsHitTesting(false))
                .overlay(alignment: .bottomTrailing) {
                    Text("読").font(.system(size: 11, weight: .bold, design: .serif)).foregroundStyle(.white)
                        .frame(width: 19, height: 19)
                        .background(Color(hex: "B83B35"), in: RoundedRectangle(cornerRadius: 2))
                        .rotationEffect(.degrees(-5)).offset(x: 6, y: 6).allowsHitTesting(false)
                }
        case .washiTape:
            content
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 1.5).fill(accent.opacity(0.42))
                        .overlay(RoundedRectangle(cornerRadius: 1.5).strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2])))
                        .frame(width: 48, height: 15).rotationEffect(.degrees(-6)).offset(y: -7).allowsHitTesting(false)
                }
        case .lanternGlow:
            content
                .background(alignment: .bottom) {
                    Ellipse().fill(RadialGradient(colors: [accent.opacity(dark ? 0.55 : 0.40), .clear], center: .center, startRadius: 2, endRadius: 80))
                        .frame(height: 44).padding(.horizontal, -18).offset(y: 24)
                }
        case .porcelain:
            content
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(dark ? 0.25 : 0.8), lineWidth: 2.5).allowsHitTesting(false))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(accent.opacity(0.35), lineWidth: 0.8).padding(-2).allowsHitTesting(false))
        case .orbitRim:
            content
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [accent.opacity(0.85), accent.opacity(0.05)], startPoint: .topTrailing, endPoint: .bottomLeading), lineWidth: 1)
                    .allowsHitTesting(false))
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle().strokeBorder(accent.opacity(0.8), lineWidth: 0.8).frame(width: 12, height: 12)
                        Circle().fill(.white).frame(width: 3.5, height: 3.5)
                    }
                    .offset(x: 5, y: -5).allowsHitTesting(false)
                }
        }
    }
}

extension View {
    func lumaShelfOrnament(_ style: LumaShelfOrnament, accent: Color, ink: Color, paper: Color, dark: Bool) -> some View {
        modifier(LumaShelfOrnamentModifier(style: style, accent: accent, ink: ink, paper: paper, dark: dark))
    }
}
