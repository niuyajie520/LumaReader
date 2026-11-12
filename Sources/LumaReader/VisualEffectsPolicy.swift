import Foundation

enum ReaderPageLayout: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic, single, spread
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "自动（宽窗口双页）"
        case .single: return "单页"
        case .spread: return "双页（书册跨页）"
        }
    }
}

enum PageTurnStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case slide = "slide"
    case push = "push"
    case curl = "natural"
    case flip = "classic"
    case paperFlip
    case fade = "fade"
    case none = "none"
    var id: String { rawValue }
    static var natural: PageTurnStyle { .curl }
    static var classic: PageTurnStyle { .flip }
    static var animationCases: [PageTurnStyle] { [.slide, .push, .curl, .paperFlip, .flip, .fade] }
    var title: String {
        switch self {
        case .slide: return "平滑滑动"
        case .push: return "柔和推页"
        case .curl: return "真实纸张弯曲"
        case .flip: return "整页翻转"
        case .paperFlip: return "纸张翻页（StPageFlip）"
        case .fade: return "柔和淡化"
        case .none: return "直接切换"
        }
    }
}

enum PageTurnSpeed: String, CaseIterable, Identifiable, Codable, Sendable {
    case slow, normal, fast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .slow: return "慢速"
        case .normal: return "标准"
        case .fast: return "快速"
        }
    }
    var scale: Double {
        switch self {
        case .slow: return 1.45
        case .normal: return 1.0
        case .fast: return 0.65
        }
    }
}

enum VisualMotionLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case enhanced, balanced, off
    var id: String { rawValue }
    var title: String {
        switch self {
        case .enhanced: return "完整动画"
        case .balanced: return "柔和动画"
        case .off: return "关闭动画"
        }
    }
    var detail: String {
        switch self {
        case .enhanced: return "流畅的弹簧、展开与形态过渡"
        case .balanced: return "缩短动画时间，减少形变"
        case .off: return "直接切换，无过渡动画"
        }
    }
}

enum VisualEffectsPolicy {
    static func effectiveMotion(requested: VisualMotionLevel, energySaving: Bool, systemLowPower: Bool, reduceMotion: Bool) -> VisualMotionLevel {
        energySaving || systemLowPower || reduceMotion ? .off : requested
    }
    static func glassEnabled(requested: Bool, energySaving: Bool, systemLowPower: Bool, reduceTransparency: Bool) -> Bool {
        requested && !energySaving && !systemLowPower && !reduceTransparency
    }
}
