import SwiftUI
import AppKit
import ImageIO
import MaterialColorUtilities

/// All native and web surfaces consume these same semantic roles.
struct ReadingPalette: Equatable, Sendable {
    let paperHex: String
    let inkHex: String
    let mutedHex: String
    let accentHex: String
    let chromeHex: String
    let outlineHex: String
    var paper: Color { Color(hex: paperHex) }
    var ink: Color { Color(hex: inkHex) }
    var muted: Color { Color(hex: mutedHex) }
    var accent: Color { Color(hex: accentHex) }
    var chrome: Color { Color(hex: chromeHex) }
    var webColors: [String:String] {
        ["paper":"#"+paperHex,"ink":"#"+inkHex,"muted":"#"+mutedHex,
         "accent":"#"+accentHex,"surface":"#"+chromeHex,"line":"#"+outlineHex]
    }
    static func hex(_ value: Int) -> String { String(format:"%06X",value & 0xFFFFFF) }
    static func hex(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "888888" }
        return String(format:"%02X%02X%02X",Int((rgb.redComponent*255).rounded()),Int((rgb.greenComponent*255).rounded()),Int((rgb.blueComponent*255).rounded()))
    }
    static func classic(_ theme: ReaderTheme, dark: Bool) -> Self {
        let d = dark || theme.forcesDark
        // These match the EPUB engine's existing classic themes.
        let ink: String
        switch theme {
        case .paper: ink = d ? "DFDBD3":"36332F"
        case .mint: ink = d ? "DCE7DC":"303C32"
        case .rose: ink = d ? "F0DCE7":"45333C"
        case .midnight: ink = "DDE5F4"
        case .black: ink = "DEDEDE"
        }
        return Self(paperHex:hex(theme.paper(dark:d)),inkHex:ink,
                    mutedHex:d ? "B9B5AE":"625E58",accentHex:hex(theme.accent),
                    chromeHex:hex(theme.chrome(dark:d)),outlineHex:d ? "555550":"CCC7BF")
    }
}

enum MonetSource: String, CaseIterable, Identifiable {
    case cover, manual, image, wallpaper
    var id: Self { self }
    var title: String {
        switch self { case .cover:return "当前书籍封面";case .manual:return "手动主色";case .image:return "自选图片";case .wallpaper:return "桌面壁纸" }
    }
}
enum MonetStyle: String, CaseIterable, Identifiable {
    case tonalSpot, neutral, vibrant, expressive, monochrome, content
    var id: Self { self }
    var title: String {
        switch self { case .tonalSpot:return "柔和协调";case .neutral:return "中性";case .vibrant:return "鲜明";case .expressive:return "表现力";case .monochrome:return "黑白";case .content:return "忠于封面" }
    }
}
struct MonetPalettePair: Equatable, Sendable {
    // Upstream MaterialDynamicColors shares mutable DynamicColor HCT caches.
    // Serialize the entire conversion boundary, not just an individual test.
    // Only immutable color-role strings leave this boundary.
    private static let generationLock = NSLock()
    let light: ReadingPalette
    let dark: ReadingPalette
    static func make(seed: Int, style: MonetStyle) -> Self {
        generationLock.lock()
        defer { generationLock.unlock() }
        func palette(dark: Bool) -> ReadingPalette {
            let hct = Hct.fromInt(seed)
            let scheme: DynamicScheme
            switch style {
            case .tonalSpot: scheme = SchemeTonalSpot(sourceColorHct:hct,isDark:dark,contrastLevel:0)
            case .neutral: scheme = SchemeNeutral(sourceColorHct:hct,isDark:dark,contrastLevel:0)
            case .vibrant: scheme = SchemeVibrant(sourceColorHct:hct,isDark:dark,contrastLevel:0)
            case .expressive: scheme = SchemeExpressive(sourceColorHct:hct,isDark:dark,contrastLevel:0)
            case .monochrome: scheme = SchemeMonochrome(sourceColorHct:hct,isDark:dark,contrastLevel:0)
            case .content: scheme = SchemeContent(sourceColorHct:hct,isDark:dark,contrastLevel:0)
            }
            return ReadingPalette(paperHex:ReadingPalette.hex(scheme.surface),inkHex:ReadingPalette.hex(scheme.onSurface),
                                  mutedHex:ReadingPalette.hex(scheme.onSurfaceVariant),accentHex:ReadingPalette.hex(scheme.primary),
                                  chromeHex:ReadingPalette.hex(scheme.surfaceContainer),outlineHex:ReadingPalette.hex(scheme.outlineVariant))
        }
        return Self(light:palette(dark:false),dark:palette(dark:true))
    }
}

/// Image decoding, Celebi quantization and scoring happen off the main actor.
/// Only a 96px thumbnail is decoded; at most 64 cached seeds are retained.
actor CoverColorExtractor {
    static let shared = CoverColorExtractor()
    private var cache: [String:Int] = [:]
    func seed(from url: URL, cacheURL: URL) -> Int? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath:url.path) else { return nil }
        let stamp = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let key = url.path + ":" + String(stamp) + ":" + String((attrs[.size] as? NSNumber)?.intValue ?? 0)
        if cache.isEmpty, let data = try? Data(contentsOf:cacheURL), let saved = try? JSONDecoder().decode([String:Int].self,from:data) { cache = saved }
        if let value = cache[key] { return value }
        guard let source = CGImageSourceCreateWithURL(url as CFURL,nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:96,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else { return nil }
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating:0,count:w*h*4)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data:buffer.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,
                                          space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image,in:CGRect(x:0,y:0,width:w,height:h)); return true
        }
        guard rendered else { return nil }
        var pixels: [Int] = []
        for i in stride(from:0,to:bytes.count,by:4) where bytes[i+3] >= 250 {
            pixels.append(0xFF000000 | Int(bytes[i]) << 16 | Int(bytes[i+1]) << 8 | Int(bytes[i+2]))
        }
        guard !pixels.isEmpty else { return nil }
        let histogram = QuantizerCelebi().quantize(pixels,32).colorToCount
        let seed = Score.score(histogram,desired:1,fallbackColorARGB:0xFF8C7862).first ?? 0xFF8C7862
        if cache.count >= 64 { cache.removeAll(keepingCapacity:true) }
        cache[key] = seed
        if let data = try? JSONEncoder().encode(cache) { try? data.write(to:cacheURL,options:.atomic) }
        return seed
    }
}
