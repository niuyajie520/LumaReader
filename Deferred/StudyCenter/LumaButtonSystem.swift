import SwiftUI

// MARK: - Luma 按钮系统（全应用唯一的一套）
//
// 见 DESIGN.md「按钮」。以前混用了十几种按钮样式（玻璃胶囊、触感、侧栏、头部、首页、
// 工具栏、系统 bordered……），各自的高度、圆角、悬停放大和按下回弹都不一样。
// 现在所有样式只从这里取：
//   • 角色 4 种：主要 / 次要 / 安静 / 危险。一屏只放一个「主要」。
//   • 尺寸 3 档：小 28 / 常规 36 / 大 44（高度），圆角统一 10。
//   • 状态 6 种：默认、悬停（只加一层淡底，不放大）、按下（缩到 0.97）、聚焦、禁用（0.38）、选中。
//   • 动效 1 条：按下 / 松开都是 .snappy(0.14)，无回弹；减少动态效果时完全关闭。
// 只描述外观，不含任何学习判断、数据或快捷键逻辑。颜色一律由调用方传入既有语义色。

public enum LumaButtonRole: Sendable, Equatable {
    /// 强调色实底。一屏只有一个。
    case primary
    /// 细描边 + 极淡底。并列的普通操作。
    case secondary
    /// 无边框，悬停才出现淡底。工具栏、行内、图标按钮。
    case quiet
    /// 红色文字；确认框里的删除。
    case destructive
}

public enum LumaButtonSize: Sendable, Equatable {
    case small, regular, large

    public var height: CGFloat {
        switch self {
        case .small: return 28
        case .regular: return 36
        case .large: return 44
        }
    }

    public var horizontalPadding: CGFloat {
        switch self {
        case .small: return 10
        case .regular: return 14
        case .large: return 18
        }
    }

    public var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .regular: return 13
        case .large: return 15
        }
    }

    /// 由旧代码里的任意高度归到最近的一档。
    public static func nearest(to height: CGFloat) -> LumaButtonSize {
        if height <= 31 { return .small }
        if height <= 40 { return .regular }
        return .large
    }
}

/// 全应用共用的按钮数值。
public enum LumaButtonMetric {
    public static let cornerRadius: CGFloat = 10
    public static let pressScale: CGFloat = 0.97
    /// 整行 / 整卡片按下只缩一点，避免大面积跳动。
    public static let rowPressScale: CGFloat = 0.985
    public static let hoverFill: Double = 0.06
    public static let pressFill: Double = 0.11
    public static let selectedFill: Double = 0.16
    public static let secondaryFill: Double = 0.035
    public static let strokeOpacity: Double = 0.16
    public static let disabledOpacity: Double = 0.38
    public static let labelPressOpacity: Double = 0.85

    public static func pressAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .snappy(duration: 0.14)
    }

    public static func hoverAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }
}

/// 统一按钮：所有带底色 / 描边的按钮都走这里。
public struct LumaButtonStyle: ButtonStyle {
    public var role: LumaButtonRole
    public var size: LumaButtonSize
    public var ink: Color
    public var accent: Color
    public var onAccent: Color
    public var selected: Bool
    public var fullWidth: Bool
    public var horizontalPadding: CGFloat?
    public var fixedLabel: Bool

    public init(_ role: LumaButtonRole = .secondary,
                size: LumaButtonSize = .regular,
                ink: Color = .primary,
                accent: Color = .accentColor,
                onAccent: Color = .white,
                selected: Bool = false,
                fullWidth: Bool = false,
                horizontalPadding: CGFloat? = nil,
                fixedLabel: Bool = true) {
        self.role = role
        self.size = size
        self.ink = ink
        self.accent = accent
        self.onAccent = onAccent
        self.selected = selected
        self.fullWidth = fullWidth
        self.horizontalPadding = horizontalPadding
        self.fixedLabel = fixedLabel
    }

    public func makeBody(configuration: Configuration) -> some View {
        LumaButtonBody(configuration: configuration, style: self)
    }
}

struct LumaButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let style: LumaButtonStyle
    @State private var hovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pressed: Bool { configuration.isPressed && isEnabled }
    private var hot: Bool { hovered && isEnabled }

    private var foreground: Color {
        switch style.role {
        case .primary: return style.onAccent
        case .destructive: return .red
        case .secondary, .quiet: return style.selected ? style.accent : style.ink
        }
    }

    private var fill: Color {
        switch style.role {
        case .primary:
            return style.accent.opacity(pressed ? 0.84 : (hot ? 0.92 : 1))
        case .secondary:
            if style.selected { return style.accent.opacity(LumaButtonMetric.selectedFill + (pressed ? 0.06 : 0)) }
            return style.ink.opacity(pressed ? LumaButtonMetric.pressFill : (hot ? LumaButtonMetric.hoverFill + 0.02 : LumaButtonMetric.secondaryFill))
        case .quiet, .destructive:
            if style.selected { return style.accent.opacity(LumaButtonMetric.selectedFill + (pressed ? 0.06 : 0)) }
            let tint: Color = style.role == .destructive ? .red : style.ink
            return tint.opacity(pressed ? LumaButtonMetric.pressFill : (hot ? LumaButtonMetric.hoverFill : 0))
        }
    }

    private var stroke: Color {
        switch style.role {
        case .secondary: return style.selected ? style.accent.opacity(0.45) : style.ink.opacity(LumaButtonMetric.strokeOpacity)
        default: return .clear
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: LumaButtonMetric.cornerRadius, style: .continuous)
        configuration.label
            .lineLimit(1)
            .fixedSize(horizontal: style.fixedLabel && !style.fullWidth, vertical: false)
            .font(.system(size: style.size.fontSize, weight: style.role == .primary || style.selected ? .semibold : .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, style.horizontalPadding ?? style.size.horizontalPadding)
            .frame(maxWidth: style.fullWidth ? .infinity : nil, minHeight: style.size.height)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(stroke, lineWidth: 1).allowsHitTesting(false))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : LumaButtonMetric.disabledOpacity)
            .scaleEffect(pressed && !reduceMotion ? LumaButtonMetric.pressScale : 1)
            .onHover { hovered = $0 }
            .animation(LumaButtonMetric.hoverAnimation(reduceMotion: reduceMotion), value: hot)
            .animation(LumaButtonMetric.pressAnimation(reduceMotion: reduceMotion), value: pressed)
    }
}

/// 无底色的按钮（整张卡片、整行、自带外观的标签）：外观不变，只加统一的按下反馈。
public struct LumaPressStyle: ButtonStyle {
    public enum Extent: Sendable { case control, row }
    public var extent: Extent
    public var dims: Bool

    public init(_ extent: Extent = .control, dims: Bool = true) {
        self.extent = extent
        self.dims = dims
    }

    public func makeBody(configuration: Configuration) -> some View {
        LumaPressBody(configuration: configuration, extent: extent, dims: dims)
    }
}

struct LumaPressBody: View {
    let configuration: ButtonStyleConfiguration
    let extent: LumaPressStyle.Extent
    let dims: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pressed = configuration.isPressed && isEnabled
        let scale = extent == .row ? LumaButtonMetric.rowPressScale : LumaButtonMetric.pressScale
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(pressed && !reduceMotion ? scale : 1)
            .opacity(pressed && dims ? LumaButtonMetric.labelPressOpacity : 1)
            .animation(LumaButtonMetric.pressAnimation(reduceMotion: reduceMotion), value: pressed)
    }
}

public extension ButtonStyle where Self == LumaPressStyle {
    /// 统一的「只有按下反馈」样式。
    static var lumaPress: LumaPressStyle { LumaPressStyle() }
    static var lumaRowPress: LumaPressStyle { LumaPressStyle(.row) }
}

public extension ButtonStyle where Self == LumaButtonStyle {
    static var lumaPrimary: LumaButtonStyle { LumaButtonStyle(.primary) }
    static var lumaSecondary: LumaButtonStyle { LumaButtonStyle(.secondary) }
    static var lumaQuiet: LumaButtonStyle { LumaButtonStyle(.quiet) }
}
