import SwiftUI
#if canImport(AppKit)
import AppKit
import ImageIO
import UniformTypeIdentifiers
#endif

/// 1.9.0：用户自己导入的主题主视觉（漫画风 / 手绘图）。
/// 参考 VS Code 背景插件与 Obsidian 壁纸插件的通行做法：不透明度、模糊、大小、位置，再加一层「可读性遮罩」。
/// 图片只保存在本机 Application Support，导入时缩到最长边 2000px，且只在设置变化时重读。
public struct HeroImageSettings: Codable, Equatable, Sendable {
    public var file: String? = nil
    public var replaceBuiltIn = true      // true：替换内置矢量图；false：叠在矢量图上
    public var fill = false               // false：右下角锚定；true：铺满整个背景
    public var opacity = 0.55
    public var scale = 1.0                // 0.3 ... 1.6，相对默认尺寸
    public var offsetX = 0.0              // -0.5 ... 0.5，占窗口宽度比例
    public var offsetY = 0.0
    public var blur = 0.0                 // 0 ... 24 pt
    public var veil = 0.0                 // 0 ... 0.8，主题底色遮罩，压低过深/过亮的图片
    public var feather = true             // 左、上边缘渐隐，避免盖住内容
    public init() {}

    /// Keep values inside the ranges the settings UI exposes. Protects against
    /// hand-edited defaults and older builds that stored wider ranges.
    public func clamped() -> HeroImageSettings {
        var c = self
        c.opacity = min(1, max(0.05, c.opacity))
        c.veil = min(0.8, max(0, c.veil))
        c.blur = min(24, max(0, c.blur))
        c.scale = min(1.6, max(0.3, c.scale))
        c.offsetX = min(0.5, max(-0.5, c.offsetX))
        c.offsetY = min(0.5, max(-0.5, c.offsetY))
        return c
    }
}

public enum HeroImageStore {
    public static let revisionKey = "luma.hero.revision"
    private static func defaultsKey(_ system: String) -> String { "luma.hero.v1.\(system)" }

    public static func load(system: String) -> HeroImageSettings? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(system)),
              let s = try? JSONDecoder().decode(HeroImageSettings.self, from: data), s.file != nil else { return nil }
        return s
    }

    public static func loadForEditing(system: String) -> HeroImageSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(system)),
              let s = try? JSONDecoder().decode(HeroImageSettings.self, from: data) else { return HeroImageSettings() }
        return s
    }

    public static func save(_ settings: HeroImageSettings, system: String) {
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: defaultsKey(system)) }
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: revisionKey) &+ 1, forKey: revisionKey)
    }

    @MainActor
    public static func remove(system: String) {
        if let s = loadForEditing(system: system).file { try? FileManager.default.removeItem(at: directory.appendingPathComponent(s)) }
        UserDefaults.standard.removeObject(forKey: defaultsKey(system))
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: revisionKey) &+ 1, forKey: revisionKey)
        cache.removeAllObjects()
    }

    public static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("LumaReader/HeroImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    #if canImport(AppKit)
    @MainActor private static let cache = NSCache<NSString, NSImage>()

    /// 把用户选的图片缩到最长边 2000px 存成 PNG，返回新设置；失败返回 nil。
    @discardableResult @MainActor
    public static func importImage(from url: URL, system: String) -> HeroImageSettings? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                     kCGImageSourceCreateThumbnailWithTransform: true,
                                     kCGImageSourceThumbnailMaxPixelSize: 2000]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let name = "\(system)-\(UUID().uuidString.prefix(8)).png"
        let dest = directory.appendingPathComponent(name)
        guard let out = CGImageDestinationCreateWithURL(dest as CFURL, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(out, cg, nil)
        guard CGImageDestinationFinalize(out) else { return nil }
        var s = loadForEditing(system: system)
        if let old = s.file { try? FileManager.default.removeItem(at: directory.appendingPathComponent(old)) }
        s.file = name
        save(s, system: system)
        cache.removeAllObjects()
        return s
    }

    @MainActor
    public static func image(named file: String) -> NSImage? {
        if let hit = cache.object(forKey: file as NSString) { return hit }
        guard let img = NSImage(contentsOf: directory.appendingPathComponent(file)) else { return nil }
        cache.setObject(img, forKey: file as NSString)
        return img
    }
    #endif
}

#if canImport(AppKit)
struct HeroImageLayer: View {
    let settings: HeroImageSettings
    let paper: Color

    var body: some View {
        GeometryReader { geo in
            if let file = settings.file, let ns = HeroImageStore.image(named: file) {
                let w = geo.size.width, h = geo.size.height
                let aspect = max(0.1, ns.size.width / max(1, ns.size.height))
                let imageView = Image(nsImage: ns).resizable()
                Group {
                    if settings.fill {
                        imageView.scaledToFill().frame(width: w, height: h).clipped()
                    } else {
                        let boxW = min(w * 0.66 * settings.scale, h * 0.97 * settings.scale * aspect)
                        imageView.scaledToFit().frame(width: boxW)
                            .frame(width: w, height: h, alignment: .bottomTrailing)
                            .offset(x: w * settings.offsetX, y: h * settings.offsetY)
                    }
                }
                .blur(radius: settings.blur)
                .overlay { if settings.veil > 0.01 { paper.opacity(settings.veil) } }
                .mask {
                    if settings.feather {
                        // One diagonal fade feathers the left and top edges together and avoids
                        // the ambiguous blendMode overlay the previous mask used.
                        LinearGradient(stops: [.init(color: .clear, location: 0),
                                               .init(color: .black, location: 0.30),
                                               .init(color: .black, location: 1)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else { Color.black }
                }
                .opacity(settings.opacity)
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}
#endif
