import Foundation

enum PageTurnStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case natural, classic, slide, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .natural: return "自然卷页"
        case .classic: return "经典立体"
        case .slide: return "平滑滑动"
        case .none: return "直接切换"
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
