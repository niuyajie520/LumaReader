import SwiftUI
import AppKit
import LumaReaderStudyKit

// Fourteen independent visual theme worlds:
// Monet, Space, Upgraded Manga + 3 Fresh Manga Worlds (Ocean, City, Forest) + 2 Iconic Game Worlds (NieR:Automata YoRHa, Zelda:Sheikah/Hyrule) + 6 Anime-Fresh Worlds.
// The five original ReaderTheme palettes remain untouched.
enum LumaVisualThemeSystem: String, CaseIterable, Identifiable, Codable, Sendable {
    case monet, space, manga
    case mangaOcean, mangaCity, mangaForest
    case nier, zelda
    case shinkai, chihiro, kanagawa, roseDawn, akari, matcha

    static let storageKey = "luma.visualThemeSystem"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .monet: return "Monet · 液态玻璃"
        case .space: return "Space · 深空观星台"
        case .manga: return "Manga · 多元漫画原稿"
        case .mangaOcean: return "海风漫绘 · Ocean Manga"
        case .mangaCity: return "都市漫绘 · City Pop Manga"
        case .mangaForest: return "森之漫绘 · Forest Manga"
        case .nier: return "尼尔机械纪元 · YoRHa UI"
        case .zelda: return "塞尔达传说 · Sheikah UI"
        case .shinkai: return "晴空夏影 · Shinkai Sky"
        case .chihiro: return "千与千寻 · Spirited Away"
        case .kanagawa: return "镰仓海风 · Kanagawa Lotus"
        case .roseDawn: return "晨曦白桃 · Rosé Pine Dawn"
        case .akari: return "京都提灯 · Akari Dawn"
        case .matcha: return "抹茶白玉 · Matcha Latte"
        }
    }
    var subtitle: String {
        switch self {
        case .monet: return "封面莫奈动态取色与多层半透明液态玻璃"
        case .space: return "天文台星轨、激光扫描线与暗夜深空视野"
        case .manga: return "支持黑白原稿、大海/城市/森林清新漫风切换与分镜速度线"
        case .mangaOcean: return "蔚蓝海平面分镜、青蓝网点、海面碎光星芒与海鸥速度线"
        case .mangaCity: return "黄昏天际线分镜、霓虹双色硬阴影、电线杆飞鸟与晚霞网点"
        case .mangaForest: return "木漏日树冠分镜、叶脉网点、森林萤光孢子与微风叶影"
        case .nier: return "寄叶部队米灰/暗夜终端、战术重型边条、CRT扫描线与几何准星"
        case .zelda: return "希卡之石夜光蓝、海拉鲁双层角框、三角神力与静谧公主辉光"
        case .shinkai: return "新海诚盛夏积雨云、丁达尔光束与天蓝赛璐璐"
        case .chihiro: return "琥珀川白龙碧玉、油屋红桥提灯与海上列车铁轨"
        case .kanagawa: return "镰仓海浪浮世绘青海波、浪花飞沫与落款朱印"
        case .roseDawn: return "清晨窗边白桃乌龙、手账缝线卡片与飘落樱瓣"
        case .akari: return "破晓京都古巷暖黄圆提灯、石板路与晨雾微光"
        case .matcha: return "日式茶屋宇治抹茶、竹茶筅水纹与牛乳白玉"
        }
    }
    var badgeTag: String {
        switch self {
        case .monet: return "流体光学"
        case .space: return "深空暗夜"
        case .manga: return "多元漫风"
        case .mangaOcean: return "大海漫风"
        case .mangaCity: return "城市漫风"
        case .mangaForest: return "森林漫风"
        case .nier: return "尼尔·寄叶"
        case .zelda: return "塞尔达·希卡"
        case .shinkai: return "新海诚风"
        case .chihiro: return "千与千寻"
        case .kanagawa: return "镰仓和风"
        case .roseDawn: return "日常少女"
        case .akari: return "古巷提灯"
        case .matcha: return "茶屋治愈"
        }
    }
    var symbol: String {
        switch self {
        case .monet: return "paintpalette.fill"
        case .space: return "sparkles"
        case .manga: return "book.pages.fill"
        case .mangaOcean: return "sailboat.fill"
        case .mangaCity: return "building.2.crop.circle.fill"
        case .mangaForest: return "tree.fill"
        case .nier: return "cpu.fill"
        case .zelda: return "shield.lefthalf.filled"
        case .shinkai: return "cloud.sun.fill"
        case .chihiro: return "tram.fill.tunnel"
        case .kanagawa: return "water.waves"
        case .roseDawn: return "camera.macro"
        case .akari: return "lightbulb.max.fill"
        case .matcha: return "cup.and.saucer.fill"
        }
    }
    var isFreshMangaSeries: Bool {
        switch self {
        case .mangaOcean, .mangaCity, .mangaForest: return true
        default: return false
        }
    }
    var isGameLegendSeries: Bool {
        switch self {
        case .nier, .zelda: return true
        default: return false
        }
    }
    var isAnimeFreshSeries: Bool {
        switch self {
        case .shinkai, .chihiro, .kanagawa, .roseDawn, .akari, .matcha,
             .mangaOcean, .mangaCity, .mangaForest, .nier, .zelda:
            return true
        case .monet, .space, .manga:
            return false
        }
    }
}

enum ThemeGalleryCategory: String, CaseIterable, Identifiable {
    case all = "全部主题 (14)"
    case freshManga = "清新漫画 (4)"
    case gameLegends = "游戏殿堂 (2)"
    case animeFresh = "日漫小清新 (6)"
    case immersive = "深空与莫奈 (2)"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .freshManga: return "book.pages.fill"
        case .gameLegends: return "gamecontroller.fill"
        case .animeFresh: return "sparkles.rectangle.stack.fill"
        case .immersive: return "paintpalette.fill"
        }
    }
    func includes(_ item: LumaVisualThemeSystem) -> Bool {
        switch self {
        case .all: return true
        case .freshManga: return item == .manga || item.isFreshMangaSeries
        case .gameLegends: return item.isGameLegendSeries
        case .animeFresh:
            switch item {
            case .shinkai, .chihiro, .kanagawa, .roseDawn, .akari, .matcha: return true
            default: return false
            }
        case .immersive: return item == .monet || item == .space
        }
    }
}

enum SpaceCosmicPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case nebulaViolet, celestialGold, moonlightSilver, customCosmic
    var id: String { rawValue }
    var title: String {
        switch self { case .nebulaViolet:return "星云紫"; case .celestialGold:return "星冕金"; case .moonlightSilver:return "月光银"; case .customCosmic:return "自定义" }
    }
    var accentHex: String {
        switch self { case .nebulaViolet,.customCosmic:return "A78BFA"; case .celestialGold:return "D8C6A2"; case .moonlightSilver:return "C6CAD9" }
    }
}

enum MangaStylePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case classicInk, oceanBreeze, citySunset, forestKomorebi
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classicInk: return "经典黑白原稿 · G笔墨线与网点"
        case .oceanBreeze: return "大海清新漫 · 蔚蓝海岸分镜"
        case .citySunset: return "城市清新漫 · 黄昏霓虹街景"
        case .forestKomorebi: return "森林清新漫 · 森之木漏日"
        }
    }
}

enum MangaOceanPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case kamakuraCoast, coralLagoon, starlightTide
    var id: String { rawValue }
    var title: String {
        switch self {
        case .kamakuraCoast: return "晴空海岬 · 蔚蓝海盐漫风"
        case .coralLagoon: return "珊瑚浅湾 · 薄荷海沫漫风"
        case .starlightTide: return "星潮夜航 · 深海群青漫风"
        }
    }
}

enum MangaCityPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case shibuyaSunset, tokyoSkylight, cyberOverpass
    var id: String { rawValue }
    var title: String {
        switch self {
        case .shibuyaSunset: return "涉谷黄昏 · 晚霞紫蓝漫风"
        case .tokyoSkylight: return "东京晴昼 · 街角天际漫风"
        case .cyberOverpass: return "雨夜高架 · 霓虹青粉漫风"
        }
    }
}

enum MangaForestPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case komorebiCanopy, mistyCedar, autumnMaple
    var id: String { rawValue }
    var title: String {
        switch self {
        case .komorebiCanopy: return "木漏日晴林 · 若叶翠绿漫风"
        case .mistyCedar: return "晨雾杉林 · 苔藓青碧漫风"
        case .autumnMaple: return "秋日枫林 · 暖金琥珀漫风"
        }
    }
}

enum NierYorhaPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case yorhaBunker, automata2BDark, redGirlsTerminal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .yorhaBunker: return "寄叶基地终端 · 经典米灰 (#DAD4BB)"
        case .automata2BDark: return "2B 战术目镜 · 暗夜炭褐 (#24221E)"
        case .redGirlsTerminal: return "逻辑病毒警报 · 机械绯红 (#CD664D)"
        }
    }
}

enum ZeldaRealmPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case sheikahSlate, zonaiTears, hyruleSanctuary
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sheikahSlate: return "旷野之息 · 希卡之石夜光蓝 (#3CD3FC)"
        case .zonaiTears: return "王国之泪 · 左纳乌秘石翠金 (#13FF59)"
        case .hyruleSanctuary: return "海拉鲁王室 · 圣殿羊皮古卷 (#FCC413)"
        }
    }
}

enum ShinkaiTimePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case summerNoon, twilightKataware, afterRainMint
    var id: String { rawValue }
    var title: String {
        switch self {
        case .summerNoon: return "盛夏晴空 · 蔚蓝"
        case .twilightKataware: return "黄昏逢魔 · 琥珀霞光"
        case .afterRainMint: return "雨后天晴 · 翠青"
        }
    }
}

enum ChihiroScenePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case seaTrainDay, bathhouseLantern, hakuRiverJade
    var id: String { rawValue }
    var title: String {
        switch self {
        case .seaTrainDay: return "第六站海上列车 · 晴海碧空"
        case .bathhouseLantern: return "油屋汤屋提灯 · 朱漆暖金"
        case .hakuRiverJade: return "琥珀川白龙 · 翡翠青碧"
        }
    }
}

enum KanagawaWavePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case enoshimaSurf, lotusWashi, kamakuraSunset
    var id: String { rawValue }
    var title: String {
        switch self {
        case .enoshimaSurf: return "江之岛海浪 · 浮世绘海青"
        case .lotusWashi: return "莲池古和纸 · 茜色落款"
        case .kamakuraSunset: return "镰仓高校前 · 夕照珊瑚"
        }
    }
}

enum RoseDawnPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case whitePeachOolong, sakuraMorning, lavenderBreeze
    var id: String { rawValue }
    var title: String {
        switch self {
        case .whitePeachOolong: return "白桃乌龙 · 晨曦粉"
        case .sakuraMorning: return "樱花坂道 · 柔雾粉"
        case .lavenderBreeze: return "放课后微风 · 鸢尾紫"
        }
    }
}

enum AkariLanternPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case dawnAlley, kitsuneAmber, bambooTea
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dawnAlley: return "破晓古巷 · 提灯暖橙"
        case .kitsuneAmber: return "稻荷千本鸟居 · 狐火朱金"
        case .bambooTea: return "岚山竹林茶席 · 焙茶褐"
        }
    }
}

enum MatchaLattePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case ujiMatcha, hojichaMilk, yuzuMatcha
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ujiMatcha: return "宇治一番茶 · 抹茶白玉"
        case .hojichaMilk: return "京都牛乳 · 浅翠若竹"
        case .yuzuMatcha: return "夏日柚子抹茶 · 清新青柠"
        }
    }
}

enum LumaThemeValidation {
    static func hex(_ raw: String) -> String? {
        var clean = raw.trimmingCharacters(in:.whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.utf8.count == 6, clean.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        return clean.uppercased()
    }
    static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound,max(range.lowerBound,value)) : fallback
    }
}

// Separate actor/cache instance: shares only the bounded thumbnail extraction primitive.
enum SpaceColorExtractor { static let shared = CoverColorExtractor() }

enum SpaceThemePaletteGenerator {
    static func makePalette(preset: SpaceCosmicPreset, customHex: String) -> ReadingPalette {
        ReadingPalette(paperHex:"080B17",inkHex:"EEF1FA",mutedHex:"C6CAD9",
                       accentHex:preset == .customCosmic ? (LumaThemeValidation.hex(customHex) ?? "A78BFA") : preset.accentHex,
                       chromeHex:"111629",outlineHex:"2D3656")
    }
    @MainActor static func clampToCosmicGamut(argb: Int) -> String {
        let color = NSColor(srgbRed:CGFloat((argb >> 16) & 255)/255, green:CGFloat((argb >> 8) & 255)/255, blue:CGFloat(argb & 255)/255, alpha:1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h,saturation:&s,brightness:&b,alpha:nil)
        let out = NSColor(hue:h,saturation:min(0.62,max(0.24,s)),brightness:min(0.94,max(0.72,b)),alpha:1).usingColorSpace(.sRGB) ?? color
        return String(format:"%02X%02X%02X",Int((out.redComponent*255).rounded()),Int((out.greenComponent*255).rounded()),Int((out.blueComponent*255).rounded()))
    }
}

enum MangaThemePaletteGenerator {
    // Preserves the exact signature and monochrome contract verified by IndependentThemeTests.
    static func makePalette(pureWhitePaper: Bool) -> ReadingPalette {
        ReadingPalette(paperHex:pureWhitePaper ? "FFFFFF":"F5F5F5",inkHex:"0A0A0A",mutedHex:"777777",accentHex:"0A0A0A",chromeHex:pureWhitePaper ? "F5F5F5":"FFFFFF",outlineHex:"D7D7D7")
    }

    static func makePalette(pureWhitePaper: Bool, style: MangaStylePreset, dark: Bool = false) -> ReadingPalette {
        switch style {
        case .classicInk:
            return makePalette(pureWhitePaper: pureWhitePaper)
        case .oceanBreeze:
            return MangaOceanThemePaletteGenerator.makePalette(preset: .kamakuraCoast, dark: dark)
        case .citySunset:
            return MangaCityThemePaletteGenerator.makePalette(preset: .shibuyaSunset, dark: dark)
        case .forestKomorebi:
            return MangaForestThemePaletteGenerator.makePalette(preset: .komorebiCanopy, dark: dark)
        }
    }
}

/// Fresh Ocean Manga Palette (inspired by rebelot/kanagawa.nvim & seaside summer manga).
enum MangaOceanThemePaletteGenerator {
    static func makePalette(preset: MangaOceanPreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        let paper: String
        let chrome: String
        let ink: String
        let muted: String
        let outline: String
        switch preset {
        case .kamakuraCoast:
            baseAccent = dark ? "38BDF8" : "0284C7"
            paper = dark ? "0D1B2A" : "F2F9FC"
            chrome = dark ? "15283C" : "E3F2FA"
            ink = dark ? "E6F4FC" : "0F293D"
            muted = dark ? "89B0C9" : "4B728F"
            outline = dark ? "264B6B" : "A9D4EC"
        case .coralLagoon:
            baseAccent = dark ? "2DD4BF" : "0D9488"
            paper = dark ? "0C1F24" : "F1FBF9"
            chrome = dark ? "143036" : "DFF6F2"
            ink = dark ? "E4F8F5" : "102E33"
            muted = dark ? "84BAB2" : "497874"
            outline = dark ? "235459" : "A6DFD7"
        case .starlightTide:
            baseAccent = dark ? "7E9CD8" : "2D5A9E"
            paper = dark ? "16161D" : "F3F6FA"
            chrome = dark ? "1F1F28" : "E5ECF5"
            ink = dark ? "DCD7BA" : "182232"
            muted = dark ? "938AA9" : "58657D"
            outline = dark ? "363646" : "BAC8DE"
        }
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

/// Fresh City Pop Manga Palette (inspired by folke/tokyonight.nvim & anime sunset cityscapes).
enum MangaCityThemePaletteGenerator {
    static func makePalette(preset: MangaCityPreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        let paper: String
        let chrome: String
        let ink: String
        let muted: String
        let outline: String
        switch preset {
        case .shibuyaSunset:
            baseAccent = dark ? "BB9AF7" : "6E4AE2"
            paper = dark ? "1A1B26" : "FAF6FC"
            chrome = dark ? "24283B" : "F1E9F8"
            ink = dark ? "C0CAF5" : "1F2335"
            muted = dark ? "7982A9" : "645E82"
            outline = dark ? "414868" : "D5C6E8"
        case .tokyoSkylight:
            baseAccent = dark ? "7AA2F7" : "2E64E5"
            paper = dark ? "1F2335" : "F4F7FC"
            chrome = dark ? "292E42" : "E6EEF9"
            ink = dark ? "C8D3F5" : "1B2234"
            muted = dark ? "7A88CF" : "586688"
            outline = dark ? "3B4261" : "C2D1EC"
        case .cyberOverpass:
            baseAccent = dark ? "F7768E" : "D93B65"
            paper = dark ? "16161E" : "FDF5F7"
            chrome = dark ? "202330" : "F7E6EC"
            ink = dark ? "D5D6DB" : "241C28"
            muted = dark ? "8990B3" : "755A6C"
            outline = dark ? "3D4463" : "E6C3D0"
        }
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

/// Fresh Forest Manga Palette (inspired by sainnhe/everforest & Ghibli Komorebi sunbeams).
enum MangaForestThemePaletteGenerator {
    static func makePalette(preset: MangaForestPreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        let paper: String
        let chrome: String
        let ink: String
        let muted: String
        let outline: String
        switch preset {
        case .komorebiCanopy:
            baseAccent = dark ? "A7C080" : "3A9428"
            paper = dark ? "272E33" : "F4F8F0"
            chrome = dark ? "2E383C" : "E7F0DF"
            ink = dark ? "D3C6AA" : "1F3322"
            muted = dark ? "859289" : "5A7058"
            outline = dark ? "414B50" : "C0D4B4"
        case .mistyCedar:
            baseAccent = dark ? "83C092" : "2B8762"
            paper = dark ? "1E2326" : "F2F7F4"
            chrome = dark ? "272E33" : "E3EEE8"
            ink = dark ? "D3C6AA" : "1B2E26"
            muted = dark ? "7A8478" : "556E62"
            outline = dark ? "374145" : "B8D1C4"
        case .autumnMaple:
            baseAccent = dark ? "E69875" : "C96228"
            paper = dark ? "292421" : "FDF6E3"
            chrome = dark ? "342E2A" : "F4EAD5"
            ink = dark ? "E4D7C5" : "3A2E25"
            muted = dark ? "9E8D7B" : "736252"
            outline = dark ? "4F453E" : "DECBAF"
        }
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

/// NieR:Automata YoRHa Tactical Interface Palette (inspired by accrazed/YoRHA-UI-BetterDiscord & MavisWRK/MVSCord-YoRHa).
enum NierThemePaletteGenerator {
    static func makePalette(preset: NierYorhaPreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        let paper: String
        let chrome: String
        let ink: String
        let muted: String
        let outline: String
        switch preset {
        case .yorhaBunker:
            if dark {
                baseAccent = "DAD4BB"
                paper = "2B2925"
                chrome = "38352F"
                ink = "DAD4BB"
                muted = "9E9986"
                outline = "5C584D"
            } else {
                baseAccent = "454138"
                paper = "DAD4BB"
                chrome = "CDC8B0"
                ink = "454138"
                muted = "706B5D"
                outline = "9C9684"
            }
        case .automata2BDark:
            baseAccent = "C8C2AA"
            paper = "1F1E1B"
            chrome = "2B2924"
            ink = "E2DEC9"
            muted = "96917E"
            outline = "4E4B42"
        case .redGirlsTerminal:
            baseAccent = "CD664D"
            paper = dark ? "221A1A" : "DFD6C7"
            chrome = dark ? "2F2323" : "D2C8B8"
            ink = dark ? "E6DCD2" : "3D2B29"
            muted = dark ? "A88A84" : "755A56"
            outline = dark ? "5E3B36" : "B39A94"
        }
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

/// The Legend of Zelda: Breath of the Wild / Tears of the Kingdom Palette (inspired by chaos-xxl/zelda-hyrule-ui).
enum ZeldaThemePaletteGenerator {
    static func makePalette(preset: ZeldaRealmPreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        let paper: String
        let chrome: String
        let ink: String
        let muted: String
        let outline: String
        switch preset {
        case .sheikahSlate:
            baseAccent = "3CD3FC"
            paper = "0A1428"
            chrome = "13223D"
            ink = "E9E1D1"
            muted = "A8A294"
            outline = "385678"
        case .zonaiTears:
            baseAccent = "13FF59"
            paper = "0E1C18"
            chrome = "162B25"
            ink = "E9E1D1"
            muted = "98B5A6"
            outline = "2F5E4E"
        case .hyruleSanctuary:
            if dark {
                baseAccent = "FCC413"
                paper = "1E1D1A"
                chrome = "2B2924"
                ink = "E9E1D1"
                muted = "ADA595"
                outline = "5C5442"
            } else {
                baseAccent = "B8860B"
                paper = "F4EFE2"
                chrome = "EAE2D0"
                ink = "2B261E"
                muted = "6E6555"
                outline = "C9BC9C"
            }
        }
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

enum ShinkaiThemePaletteGenerator {
    static func makePalette(preset: ShinkaiTimePreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        let paper: String
        let chrome: String
        let ink: String
        let muted: String
        let outline: String
        switch preset {
        case .summerNoon:
            baseAccent = dark ? "5CA8FF" : "2B7DE9"
            paper = dark ? "101B2B" : "F2F8FE"
            chrome = dark ? "17263B" : "E3F1FD"
            ink = dark ? "EBF4FF" : "182C42"
            muted = dark ? "94B0CE" : "587594"
            outline = dark ? "2B4466" : "BDD9F2"
        case .twilightKataware:
            baseAccent = dark ? "FF7E6B" : "E05A47"
            paper = dark ? "1C162B" : "FFF6F2"
            chrome = dark ? "28203D" : "FCEAE3"
            ink = dark ? "F9ECE8" : "2E1E28"
            muted = dark ? "BCA6C4" : "7D5E6B"
            outline = dark ? "463666" : "E8C8BE"
        case .afterRainMint:
            baseAccent = dark ? "38C6B4" : "1D9A8C"
            paper = dark ? "0F2024" : "F1FBF9"
            chrome = dark ? "172F34" : "E0F4F0"
            ink = dark ? "E6F7F5" : "163330"
            muted = dark ? "8EBAB5" : "527A75"
            outline = dark ? "28524D" : "B6DFD9"
        }
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

enum ChihiroThemePaletteGenerator {
    static func makePalette(preset: ChihiroScenePreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        let paper: String
        let chrome: String
        let ink: String
        let muted: String
        let outline: String
        switch preset {
        case .seaTrainDay:
            baseAccent = dark ? "4DC4B0" : "248F7D"
            paper = dark ? "121C24" : "F3FAF8"
            chrome = dark ? "1A2833" : "E3F3EF"
            ink = dark ? "E6F4F1" : "1B2E2B"
            muted = dark ? "8EB5AE" : "567872"
            outline = dark ? "2B4A46" : "B8DDD6"
        case .bathhouseLantern:
            baseAccent = dark ? "F26B5B" : "D94E3E"
            paper = dark ? "1A1420" : "FCF6EE"
            chrome = dark ? "261D2E" : "F4E8D8"
            ink = dark ? "EFE6F2" : "2E1D1A"
            muted = dark ? "B8A2C0" : "7A5E56"
            outline = dark ? "4A3656" : "E0C6B4"
        case .hakuRiverJade:
            baseAccent = dark ? "52C9A2" : "1E8C6E"
            paper = dark ? "111E1C" : "F2FAF6"
            chrome = dark ? "182B28" : "E0F2EA"
            ink = dark ? "E5F6F0" : "162E26"
            muted = dark ? "8CB8AA" : "50786A"
            outline = dark ? "2A4F44" : "B4DCD0"
        }
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

enum KanagawaThemePaletteGenerator {
    static func makePalette(preset: KanagawaWavePreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        switch preset {
        case .enoshimaSurf: baseAccent = dark ? "6B9BD2" : "3E6899"
        case .lotusWashi: baseAccent = dark ? "E06660" : "B83B35"
        case .kamakuraSunset: baseAccent = dark ? "E88D67" : "C4603C"
        }
        let paper = dark ? "1A1C24" : "F4EFE0"
        let chrome = dark ? "242733" : "EAE2CE"
        let ink = dark ? "E6E2D6" : "222630"
        let muted = dark ? "9E9A8E" : "68665E"
        let outline = dark ? "3E4254" : "CFC5AE"
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

enum RoseDawnThemePaletteGenerator {
    static func makePalette(preset: RoseDawnPreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        switch preset {
        case .whitePeachOolong: baseAccent = dark ? "EA9A97" : "D7827E"
        case .sakuraMorning: baseAccent = dark ? "EB86A8" : "C96286"
        case .lavenderBreeze: baseAccent = dark ? "B496E0" : "907AA9"
        }
        let paper = dark ? "191724" : "FAF4ED"
        let chrome = dark ? "232033" : "F2E9E1"
        let ink = dark ? "E8E2F0" : "575279"
        let muted = dark ? "9893A5" : "797593"
        let outline = dark ? "403C58" : "DFDAD9"
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

enum AkariThemePaletteGenerator {
    static func makePalette(preset: AkariLanternPreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        switch preset {
        case .dawnAlley: baseAccent = dark ? "F08C4B" : "D4763B"
        case .kitsuneAmber: baseAccent = dark ? "E86446" : "C4482C"
        case .bambooTea: baseAccent = dark ? "C99A5B" : "9E7238"
        }
        let paper = dark ? "1C1815" : "F6EFE6"
        let chrome = dark ? "28221E" : "EDE3D5"
        let ink = dark ? "EFE6DC" : "2D2520"
        let muted = dark ? "A89B8E" : "736559"
        let outline = dark ? "4A3E36" : "D6C7B5"
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

enum MatchaThemePaletteGenerator {
    static func makePalette(preset: MatchaLattePreset, dark: Bool, overrideAccentHex: String? = nil) -> ReadingPalette {
        let baseAccent: String
        switch preset {
        case .ujiMatcha: baseAccent = dark ? "68C274" : "40914B"
        case .hojichaMilk: baseAccent = dark ? "5BB89A" : "2E8B6E"
        case .yuzuMatcha: baseAccent = dark ? "8CC94C" : "629926"
        }
        let paper = dark ? "161E19" : "F2F5F1"
        let chrome = dark ? "202B24" : "E4EBE2"
        let ink = dark ? "E4EFE7" : "1E2D22"
        let muted = dark ? "92A898" : "5C7362"
        let outline = dark ? "344A3B" : "C4D4C7"
        return ReadingPalette(paperHex: paper, inkHex: ink, mutedHex: muted, accentHex: overrideAccentHex ?? baseAccent, chromeHex: chrome, outlineHex: outline)
    }
}

private struct LumaVisualThemeSystemKey: EnvironmentKey { static let defaultValue: LumaVisualThemeSystem = .monet }
extension EnvironmentValues { var lumaVisualThemeSystem: LumaVisualThemeSystem { get { self[LumaVisualThemeSystemKey.self] } set { self[LumaVisualThemeSystemKey.self] = newValue } } }

private struct LumaSpaceGlassOpacityKey: EnvironmentKey { static let defaultValue: Double = 0.76 }
extension EnvironmentValues { var lumaSpaceGlassOpacity: Double { get { self[LumaSpaceGlassOpacityKey.self] } set { self[LumaSpaceGlassOpacityKey.self] = newValue } } }

private struct LumaSpaceGlowIntensityKey: EnvironmentKey { static let defaultValue: Double = 0.55 }
extension EnvironmentValues { var lumaSpaceGlowIntensity: Double { get { self[LumaSpaceGlowIntensityKey.self] } set { self[LumaSpaceGlowIntensityKey.self] = newValue } } }

private struct LumaSpaceOrbitalLinesKey: EnvironmentKey { static let defaultValue: Bool = true }
extension EnvironmentValues { var lumaSpaceOrbitalLines: Bool { get { self[LumaSpaceOrbitalLinesKey.self] } set { self[LumaSpaceOrbitalLinesKey.self] = newValue } } }

private struct LumaMangaScreentoneDensityKey: EnvironmentKey { static let defaultValue: Double = 0.35 }
extension EnvironmentValues { var lumaMangaScreentoneDensity: Double { get { self[LumaMangaScreentoneDensityKey.self] } set { self[LumaMangaScreentoneDensityKey.self] = newValue } } }

private struct LumaMangaLineWeightKey: EnvironmentKey { static let defaultValue: Double = 1.5 }
extension EnvironmentValues { var lumaMangaLineWeight: Double { get { self[LumaMangaLineWeightKey.self] } set { self[LumaMangaLineWeightKey.self] = newValue } } }

private struct LumaMangaPopoverTranslucentKey: EnvironmentKey { static let defaultValue: Bool = false }
extension EnvironmentValues { var lumaMangaPopoverTranslucent: Bool { get { self[LumaMangaPopoverTranslucentKey.self] } set { self[LumaMangaPopoverTranslucentKey.self] = newValue } } }

private struct LumaAnimeBlendGlassKey: EnvironmentKey { static let defaultValue: Bool = false }
extension EnvironmentValues { var lumaAnimeBlendGlass: Bool { get { self[LumaAnimeBlendGlassKey.self] } set { self[LumaAnimeBlendGlassKey.self] = newValue } } }

struct SpaceObservatoryCanvas: View {
    let accent: Color
    let showOrbitalGeometry: Bool
    let glowIntensity: Double
    var body: some View {
        VisualThemeBackdrop(system:"space",paper:Color(hex:"080B17"),accent:accent,glow:glowIntensity,orbitals:showOrbitalGeometry)
    }
}
struct MangaScreentoneCanvas: View {
    let paperColor: Color
    let accentColor: Color
    let screentoneDensity: Double
    let lineWeight: Double
    let styleSystem: String
    init(paperColor: Color, accentColor: Color = Color(hex: "0A0A0A"), screentoneDensity: Double, lineWeight: Double, styleSystem: String = "manga") {
        self.paperColor = paperColor
        self.accentColor = accentColor
        self.screentoneDensity = screentoneDensity
        self.lineWeight = lineWeight
        self.styleSystem = styleSystem
    }
    var body: some View {
        VisualThemeBackdrop(system:styleSystem,paper:paperColor,accent:accentColor,glow:max(0.45, screentoneDensity),orbitals:true,density:screentoneDensity,lineWeight:lineWeight)
    }
}
struct AnimeThemeCanvas: View {
    let system: LumaVisualThemeSystem
    let paperColor: Color
    let accent: Color
    let intensity: Double
    let showDetails: Bool
    var body: some View {
        VisualThemeBackdrop(
            system: system.rawValue,
            paper: paperColor,
            accent: accent,
            glow: intensity,
            orbitals: showDetails,
            density: intensity,
            lineWeight: 1.3
        )
    }
}

// MARK: - Scale-inspired Theme Gallery Matrix (Category Filter + Bento Visual Cards)

struct LumaThemeSystemSelectorView: View {
    @Bindable var store: LibraryStore
    // Persisted so switching a theme (which re-evaluates the settings tree) cannot jump back to "全部主题".
    @AppStorage("luma.themeGallery.category") private var selectedCategoryRaw: String = ThemeGalleryCategory.all.rawValue
    @State private var hoveredItem: LumaVisualThemeSystem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedCategory: ThemeGalleryCategory {
        ThemeGalleryCategory(rawValue: selectedCategoryRaw) ?? .all
    }

    private var filteredSystems: [LumaVisualThemeSystem] {
        LumaVisualThemeSystem.allCases.filter { selectedCategory.includes($0) }
    }

    var body: some View {
        let palette = store.readingPalette(dark: store.isDarkAppearance)
        let ink = palette.ink
        let accent = palette.accent
        let chrome = palette.chrome
        return VStack(alignment: .leading, spacing: 12) {
            // 1. Top Segmented Filter Bar (Scale style)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ThemeGalleryCategory.allCases) { category in
                        let isSel = (selectedCategory == category)
                        Button {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                                selectedCategoryRaw = category.rawValue
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.symbol)
                                    .font(.system(size: 11, weight: isSel ? .semibold : .medium))
                                Text(L10n.text(category.rawValue))
                                    .font(.system(size: 11.5, weight: isSel ? .semibold : .medium))
                            }
                            .foregroundStyle(isSel ? Color.white : ink.opacity(0.82))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSel ? accent : ink.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 2. Adaptive Bento Theme Gallery Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158, maximum: 230), spacing: 10)], spacing: 10) {
                ForEach(filteredSystems) { item in
                    let isSelected = (store.visualThemeSystem == item)
                    let isHovered = (hoveredItem == item)
                    Button {
                        // Theme switching is an instant material swap: no spring, no layout travel.
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { store.visualThemeSystem = item }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                preview(item)
                                    .frame(height: 82)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.6)
                                    )

                                Text(L10n.text(item.badgeTag))
                                    .lumaFont(size: 9.5, weight: .semibold, design: .rounded)
                                    .foregroundStyle(badgeTextColor(for: item))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(badgeBackgroundColor(for: item))
                                    )
                                    .padding(6)
                            }

                            HStack(alignment: .center, spacing: 6) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(isSelected ? accent : .secondary)
                                Text(L10n.text(item.title))
                                    .lumaFont(size: 12, weight: .semibold)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(accent)
                                }
                            }

                            Text(L10n.text(item.subtitle))
                                .lumaFont(size: 10.5)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            chrome,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(
                                    isSelected ? accent : accent.opacity(isHovered ? 0.42 : 0.16),
                                    lineWidth: isSelected ? 2.0 : 0.8
                                )
                        )
                        .scaleEffect(!reduceMotion && isHovered ? 1.012 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in hoveredItem = inside ? item : (hoveredItem == item ? nil : hoveredItem) }
                    .accessibilityLabel(L10n.text(item.title))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func badgeTextColor(for item: LumaVisualThemeSystem) -> Color {
        switch item {
        case .space: return Color(hex: "EEF1FA")
        case .manga: return Color.white
        case .nier: return Color(hex: "DAD4BB")
        case .zelda: return Color(hex: "3CD3FC")
        case .mangaCity: return Color(hex: "C0CAF5")
        default: return Color(hex: "1C2836")
        }
    }

    private func badgeBackgroundColor(for item: LumaVisualThemeSystem) -> Color {
        switch item {
        case .space: return Color(hex: "1C2542").opacity(0.88)
        case .manga: return Color(hex: "0A0A0A").opacity(0.88)
        case .nier: return Color(hex: "454138").opacity(0.92)
        case .zelda: return Color(hex: "0A1428").opacity(0.92)
        case .mangaCity: return Color(hex: "1A1B26").opacity(0.90)
        default: return Color.white.opacity(0.86)
        }
    }

    private func preview(_ item: LumaVisualThemeSystem) -> some View {
        ThemeGalleryThumbnail(item: item)
    }
}

/// Lightweight static thumbnail for the gallery.
private struct ThemeGalleryThumbnail: View {
    let item: LumaVisualThemeSystem

    private var colors: [Color] {
        switch item {
        case .monet: return [Color(hex:"7B8CDE"), Color(hex:"B88B9E"), Color(hex:"6E9277")]
        case .space: return [Color(hex:"1C2542"), Color(hex:"0C1021"), Color(hex:"A78BFA")]
        case .manga: return [Color(hex:"FFFFFF"), Color(hex:"EAF4FC"), Color(hex:"0A0A0A")]
        case .mangaOcean: return [Color(hex:"D8F1FD"), Color(hex:"F2F9FC"), Color(hex:"0284C7")]
        case .mangaCity: return [Color(hex:"1A1B26"), Color(hex:"2E2B4F"), Color(hex:"F7768E")]
        case .mangaForest: return [Color(hex:"E5F2DC"), Color(hex:"F4F8F0"), Color(hex:"3A9428")]
        case .nier: return [Color(hex:"DAD4BB"), Color(hex:"CDC8B0"), Color(hex:"454138")]
        case .zelda: return [Color(hex:"0A1428"), Color(hex:"162C46"), Color(hex:"3CD3FC")]
        case .shinkai: return [Color(hex:"BFE3FF"), Color(hex:"E6F3FE"), Color(hex:"2B7DE9")]
        case .chihiro: return [Color(hex:"DDF3EC"), Color(hex:"EEF8F5"), Color(hex:"248F7D")]
        case .kanagawa: return [Color(hex:"F4EFE0"), Color(hex:"EAE2CE"), Color(hex:"3E6899")]
        case .roseDawn: return [Color(hex:"FAF4ED"), Color(hex:"F6E7E2"), Color(hex:"D7827E")]
        case .akari: return [Color(hex:"F6EFE6"), Color(hex:"EDE3D5"), Color(hex:"D4763B")]
        case .matcha: return [Color(hex:"F2F5F1"), Color(hex:"E8F0E6"), Color(hex:"40914B")]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if item != .monet {
                VisualThemeBackdrop(
                    system: item.rawValue,
                    paper: .clear,
                    accent: colors[2],
                    glow: 0.95,
                    orbitals: true,
                    density: 0.65,
                    lineWeight: 1.5
                )
            }
            motif
        }
        .drawingGroup()
    }

    @ViewBuilder private var motif: some View {
        switch item {
        case .monet:
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.34)).frame(width: 42, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(.white.opacity(0.75)).frame(width: 48, height: 5)
                    Capsule().fill(.white.opacity(0.45)).frame(width: 32, height: 4)
                }
            }
        case .space:
            ZStack {
                Circle().strokeBorder(Color(hex:"A78BFA").opacity(0.55), lineWidth: 1).frame(width: 36, height: 36)
                Circle().fill(Color(hex:"A78BFA").opacity(0.75)).frame(width: 8, height: 8).offset(x: 14, y: -10)
                Circle().fill(.white.opacity(0.8)).frame(width: 3, height: 3).offset(x: -22, y: 12)
            }
        case .manga:
            ZStack {
                HStack(spacing: 4) {
                    Rectangle().fill(Color(hex:"0284C7").opacity(0.25)).frame(width: 18, height: 34)
                    Rectangle().fill(Color(hex:"F7768E").opacity(0.25)).frame(width: 18, height: 34)
                    Rectangle().fill(Color(hex:"3A9428").opacity(0.25)).frame(width: 18, height: 34)
                }
                Rectangle().strokeBorder(Color(hex:"0A0A0A"), lineWidth: 1.8).padding(9)
            }
        case .mangaOcean:
            ZStack {
                // Sea horizon & comic wave arcs + 4-point star sparkle
                VStack(spacing: 4) {
                    Spacer()
                    Capsule().fill(Color(hex:"0284C7").opacity(0.75)).frame(width: 72, height: 3.5)
                    Capsule().fill(Color(hex:"38BDF8").opacity(0.55)).frame(width: 52, height: 2.5)
                }
                .padding(.bottom, 10)
                Circle().fill(Color.white).frame(width: 10, height: 10).offset(x: -24, y: -10)
                RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex:"0F293D"), lineWidth: 1.6).padding(8)
            }
        case .mangaCity:
            ZStack(alignment: .bottom) {
                // Twilight skyline blocks + neon offset frame
                HStack(alignment: .bottom, spacing: 4) {
                    Rectangle().fill(Color(hex:"7AA2F7").opacity(0.65)).frame(width: 12, height: 24)
                    Rectangle().fill(Color(hex:"BB9AF7").opacity(0.75)).frame(width: 16, height: 34)
                    Rectangle().fill(Color(hex:"F7768E").opacity(0.75)).frame(width: 14, height: 20)
                    Rectangle().fill(Color(hex:"7AA2F7").opacity(0.55)).frame(width: 12, height: 28)
                }
                .padding(.bottom, 8)
                RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex:"7AA2F7"), lineWidth: 1.4).padding(8)
            }
        case .mangaForest:
            ZStack {
                // Komorebi sunbeams & emerald forest canopy
                HStack(spacing: 10) {
                    Rectangle().fill(Color.white.opacity(0.55)).frame(width: 8, height: 54).rotationEffect(.degrees(22))
                    Rectangle().fill(Color(hex:"A7C080").opacity(0.45)).frame(width: 6, height: 54).rotationEffect(.degrees(22))
                }
                Circle().fill(Color(hex:"3A9428").opacity(0.75)).frame(width: 22, height: 22).offset(x: -20, y: -8)
                Circle().fill(Color(hex:"83C092").opacity(0.75)).frame(width: 16, height: 16).offset(x: -6, y: -12)
                RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex:"1F3322"), lineWidth: 1.5).padding(8)
            }
        case .nier:
            ZStack {
                // YoRHa tactical left bar + geometric target circle + hairline frame
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex:"454138")).frame(width: 5, height: 44)
                    Spacer()
                }
                .padding(.leading, 10)
                Circle().strokeBorder(Color(hex:"454138").opacity(0.7), lineWidth: 1.1).frame(width: 28, height: 28)
                Rectangle().fill(Color(hex:"454138")).frame(width: 6, height: 6).rotationEffect(.degrees(45))
                Rectangle().strokeBorder(Color(hex:"454138").opacity(0.65), lineWidth: 1.0).padding(8)
            }
        case .zelda:
            ZStack {
                // Sheikah Slate blue glow ring + golden Triforce + angular double border
                Circle().strokeBorder(Color(hex:"3CD3FC").opacity(0.85), lineWidth: 1.3).frame(width: 32, height: 32)
                Image(systemName: "triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex:"FCC413"))
                RoundedRectangle(cornerRadius: 3).strokeBorder(Color(hex:"E2DED3").opacity(0.55), lineWidth: 1.0).padding(8)
            }
        case .shinkai:
            ZStack {
                Circle().fill(.white.opacity(0.85)).frame(width: 18, height: 18).offset(x: 30, y: -14)
                HStack(spacing: 4) {
                    Capsule().fill(.white.opacity(0.9)).frame(width: 34, height: 8)
                    Capsule().fill(.white.opacity(0.65)).frame(width: 20, height: 6)
                }
                .offset(x: -12, y: 12)
            }
        case .chihiro:
            ZStack {
                Rectangle().fill(Color(hex:"D94E3E")).frame(width: 34, height: 4).offset(y: -8)
                HStack(spacing: 20) {
                    Rectangle().fill(Color(hex:"D94E3E")).frame(width: 4, height: 26)
                    Rectangle().fill(Color(hex:"D94E3E")).frame(width: 4, height: 26)
                }
                .offset(y: 4)
            }
        case .kanagawa:
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(Color(hex:"3E6899").opacity(0.55))
                        .frame(width: CGFloat(54 - i * 12), height: 3)
                        .offset(x: CGFloat(i * 8 - 10), y: CGFloat(i * 8 - 8))
                }
                Rectangle().fill(Color(hex:"B83B35")).frame(width: 9, height: 9).offset(x: 30, y: 14)
            }
        case .roseDawn:
            ZStack {
                Circle().fill(Color(hex:"D7827E").opacity(0.7)).frame(width: 20, height: 20).offset(x: 24, y: -10)
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(.white.opacity(0.65)).frame(width: 4, height: 4)
                        .offset(x: CGFloat(i * 12 - 14), y: CGFloat(i * 6 + 12))
                }
            }
        case .akari:
            ZStack {
                Capsule().fill(Color(hex:"D4763B").opacity(0.28)).frame(width: 26, height: 34)
                Circle().fill(Color(hex:"D4763B").opacity(0.85)).frame(width: 14, height: 14)
                Rectangle().fill(Color(hex:"7A4A2A").opacity(0.65)).frame(width: 1, height: 10).offset(y: -20)
            }
        case .matcha:
            ZStack {
                Circle().trim(from: 0.5, to: 1).stroke(Color(hex:"40914B"), lineWidth: 3).frame(width: 30, height: 30).offset(y: 4)
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule().fill(Color(hex:"40914B").opacity(0.55)).frame(width: 1.5, height: 8)
                    }
                }
                .offset(y: -2)
            }
        }
    }
}

// MARK: - Context-Sensitive Inspector per Theme System

struct LumaThemePreferences: View {
    @Bindable var store: LibraryStore
    @State private var customHex = ""
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            LumaThemeSystemSelectorView(store:store)

            if store.visualThemeSystem != .monet {
                ZStack(alignment: .bottomLeading) {
                    VisualThemeBackdrop(
                        system: store.visualThemeSystem == .manga ? store.mangaStyleSystemKey : store.visualThemeSystem.rawValue,
                        paper: store.paper(dark: store.isDarkAppearance),
                        accent: store.accent,
                        glow: max(0.65, store.animeAtmosphereIntensity),
                        orbitals: true,
                        density: max(0.55, store.mangaScreentoneDensity),
                        lineWeight: store.mangaLineWeight
                    )
                    .frame(height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(store.accent.opacity(0.45), lineWidth: 1.2)
                    )

                    HStack(spacing: 8) {
                        Image(systemName: store.visualThemeSystem.symbol)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(store.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.visualThemeSystem.title + " · 专属主题插画预览")
                                .lumaFont(size: 12.5, weight: .bold)
                            Text(store.visualThemeSystem.subtitle)
                                .lumaFont(size: 10.5)
                                .opacity(0.78)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .padding(8)
                }
            }

            Divider().opacity(0.22)

            switch store.visualThemeSystem {
            case .monet:
                HStack(spacing: 8) {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(store.accent)
                    Text(L10n.text("当前使用「Monet · 液态玻璃」，可在下方自由选择 5 款经典纸张主题或开启封面动态取色。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .space:
                Picker(L10n.text("深空配色"),selection:$store.spacePreset) {
                    ForEach(SpaceCosmicPreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                if store.spacePreset == .customCosmic {
                    HStack {
                        TextField(L10n.text("RRGGBB"),text:$customHex).textFieldStyle(.roundedBorder).frame(maxWidth:130)
                        Button(L10n.text("应用")) { if let hex = LumaThemeValidation.hex(customHex) { store.spaceCustomHex = hex } }
                            .disabled(LumaThemeValidation.hex(customHex) == nil)
                    }
                    .onAppear { customHex = store.spaceCustomHex }
                    .onChange(of:store.spaceCustomHex) { _,value in customHex = value }
                }
                HStack {
                    Button(L10n.text("从星云图片取色…")) { store.chooseSpaceCosmicImage() }
                    Spacer()
                    Text("#" + (store.spacePreset == .customCosmic ? store.spaceCustomHex : store.spacePreset.accentHex)).font(.caption.monospaced())
                }
                slider("深空玻璃不透明度",value:$store.spaceGlassOpacity,range:0.35...0.95)
                slider("边缘微光",value:$store.spaceGlowIntensity,range:0.15...1)
                Toggle(L10n.text("显示星图轨道"),isOn:$store.spaceOrbitalLines)
                if !store.spaceImageStatus.isEmpty { Text(L10n.text(store.spaceImageStatus)).font(.caption) }

            case .manga:
                Picker(L10n.text("漫画分镜画风"), selection: $store.mangaStylePreset) {
                    ForEach(MangaStylePreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                if store.mangaStylePreset == .classicInk {
                    Toggle(L10n.text("纯白原稿纸张"),isOn:$store.mangaPureWhitePaper)
                }
                slider("网点与速度线浓度",value:$store.mangaScreentoneDensity,range:0...0.85)
                HStack {
                    Text(L10n.text("分镜线框粗细"))
                    Slider(value:$store.mangaLineWeight,in:1...2.5,step:0.25)
                    Text(String(format:"%.2f pt",store.mangaLineWeight)).monospacedDigit().frame(width:60)
                }
                Toggle(L10n.text("菜单轻微半透明"),isOn:$store.mangaPopoverTranslucent)

            case .mangaOcean:
                Picker(L10n.text("大海漫绘场景"), selection: $store.mangaOceanPreset) {
                    ForEach(MangaOceanPreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("海平面网点与星芒密度", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示海浪分镜线、海面碎光与海鸥"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "海风漫绘")

            case .mangaCity:
                Picker(L10n.text("城市漫绘场景"), selection: $store.mangaCityPreset) {
                    ForEach(MangaCityPreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("晚霞网点与霓虹双色阴影强度", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示城市天际线、电线杆与黄昏飞鸟"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "都市漫绘")

            case .mangaForest:
                Picker(L10n.text("森林漫绘场景"), selection: $store.mangaForestPreset) {
                    ForEach(MangaForestPreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("木漏日丁达尔光束与叶脉网点", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示树冠枝叶剪影与森林萤光孢子"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "森之漫绘")

            case .nier:
                Picker(L10n.text("寄叶部队终端制式"), selection: $store.nierPreset) {
                    ForEach(NierYorhaPreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("CRT 扫描线与战术准星对比度", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示 YoRHa 几何刻度线与雷达环"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "尼尔机械纪元")

            case .zelda:
                Picker(L10n.text("海拉鲁圣物形态"), selection: $store.zeldaPreset) {
                    ForEach(ZeldaRealmPreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("希卡符文辉光与精力环浓度", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示希卡之石星图环、三角神力与静谧微光"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "塞尔达传说")

            case .shinkai:
                Picker(L10n.text("天色时刻"), selection: $store.shinkaiPreset) {
                    ForEach(ShinkaiTimePreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("丁达尔光束与棱镜光晕", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示积雨云轮廓"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "晴空夏影")

            case .chihiro:
                Picker(L10n.text("千寻场景"), selection: $store.chihiroPreset) {
                    ForEach(ChihiroScenePreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("油屋提灯与金平糖微光", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示海上列车轨道、提灯与煤球精灵"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "千与千寻")

            case .kanagawa:
                Picker(L10n.text("镰仓海景"), selection: $store.kanagawaPreset) {
                    ForEach(KanagawaWavePreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("浮世绘波纹与金砂密度", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示青海波浪纹与落款朱印"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "镰仓海风")

            case .roseDawn:
                Picker(L10n.text("晨曦风味"), selection: $store.roseDawnPreset) {
                    ForEach(RoseDawnPreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("白桃晨雾与樱瓣浓度", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示手账缝线丝带与樱瓣"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "晨曦白桃")

            case .akari:
                Picker(L10n.text("古巷灯火"), selection: $store.akariPreset) {
                    ForEach(AkariLanternPreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("京都圆提灯暖光浓度", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示古巷提灯串"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "京都提灯")

            case .matcha:
                Picker(L10n.text("茶席风味"), selection: $store.matchaPreset) {
                    ForEach(MatchaLattePreset.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                slider("茶筅水纹与金箔光泽", value: $store.animeAtmosphereIntensity, range: 0.15...1.0)
                Toggle(L10n.text("显示茶碗水纹与牛乳白玉"), isOn: $store.animeShowCanvasDetails)
                animeOptionalFusionSection(title: "抹茶白玉")
            }
        }
    }

    @ViewBuilder
    private func animeOptionalFusionSection(title: String) -> some View {
        Divider().opacity(0.18)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.2.square.on.square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.accent)
                Text(L10n.text("可选融合项（默认关闭，保持「\(title)」纯粹独立材质）"))
                    .lumaFont(size: 11, weight: .semibold)
                    .foregroundStyle(.secondary)
            }
            Picker(L10n.text("明暗模式"), selection: $store.appearance) {
                ForEach(Appearance.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
            }
            Toggle(L10n.text("融入液态玻璃半透明效果（关闭则使用主题原生实体卡片）"), isOn: $store.animeBlendLiquidGlass)
            Toggle(L10n.text("融入当前书籍封面 Monet 强调色（关闭则使用主题专属配色）"), isOn: $store.animeBlendMonetAccent)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(store.accent.opacity(0.06))
        )
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack { Text(L10n.text(title)); Slider(value:value,in:range); Text("\(Int(value.wrappedValue * 100))%").monospacedDigit().frame(width:42) }
    }
}
