// === PROJECT RED LINE / 项目红线 BEGIN ===
// 调色与设计 Token 文件（Theme.swift / MonetTheme.swift / LumaDesignTokens.swift）：
// 五大经典主题（暖纸白、鼠尾草绿、樱花粉、午夜蓝、纯黑）及 Monet 动态调色逻辑必须严格保护，不得擅自修改颜色定义或删除主题。
// Preserve theme definitions, palettes, and design tokens without modification.
// 完整规则见项目根目录 AGENTS.md；所有开发者与 AI 必须遵守。
// All developers and AI assistants must follow the project-root AGENTS.md.
// === PROJECT RED LINE / 项目红线 END ===
import SwiftUI

// MARK: - Luma 设计 token（阅读中心与学习中心共用）
//
// 只描述呈现：时长、缓动、尺寸、状态样式与窗口按钮对齐锚点。
// 不包含任何学习判断、计时、语音、数据或快捷键逻辑。
// 本文件属于 LumaReaderStudyKit（macOS 15+，Swift 6 语言模式），主 App 通过 import 使用。

// MARK: - 界面风格：动态 / 静态（设置 › 外观与排版 › 视觉效果 › 界面风格）

/// 两套界面设计共用同一组控件与语义色，只在动效上不同：
/// - 动态：弹性缩放、指针跟随高光、图标弹跳、选中底色形变、进度环与答对脉冲、错词弹入。
/// - 静态：无缩放、无弹跳、无形变，状态（颜色、底色、实心图标）直接切换。
/// 系统“减少动态效果”、App“关闭动画”或省电模式开启时，动态一律按静态处理。
public enum LumaInterfaceMotionStyle: String, CaseIterable, Identifiable, Sendable {
    case dynamic
    case still = "static"
    public static let storageKey = "luma.ui.motionStyle"
    public var id: String { rawValue }
    public var title: String { self == .dynamic ? "动态" : "静态" }
    public var detail: String {
        self == .dynamic ? "按钮弹性、指针高光、图标弹跳与选中形变" : "无缩放与弹跳，状态直接切换"
    }
}

private struct LumaDynamicMotionKey: EnvironmentKey {
    // 主 App 会注入经过省电 / 关闭动画判断后的值；未注入的子树（如独立弹窗）退回读取设置本身。
    static var defaultValue: Bool {
        UserDefaults.standard.string(forKey: LumaInterfaceMotionStyle.storageKey) != LumaInterfaceMotionStyle.still.rawValue
    }
}

public extension EnvironmentValues {
    /// true = 使用动态设计。仍需与 accessibilityReduceMotion 一起判断。
    var lumaDynamicMotion: Bool {
        get { self[LumaDynamicMotionKey.self] }
        set { self[LumaDynamicMotionKey.self] = newValue }
    }
}

/// 动效 token。所有新增动效只从这里取参数；静态设计或“减少动态效果”时一律退化为 nil（静态切换）。
public enum LumaMotionToken {
    // 时长（秒）。悬停、按下、状态切换均不超过 250ms。
    public static let hoverDuration: Double = 0.18
    public static let pressDuration: Double = 0.14
    public static let releaseDuration: Double = 0.22
    public static let stateDuration: Double = 0.22
    public static let numericDuration: Double = 0.24
    public static let chipDuration: Double = 0.22

    // 缩放幅度（仅控件，绝不用于正文或输入框）。
    public static let hoverScale: CGFloat = 1.04
    public static let pressScale: CGFloat = 0.94

    // 缓动。使用 macOS 14+ 的 smooth / snappy（以感知时长定义，便于控制上限）。
    public static var hover: Animation { .smooth(duration: hoverDuration) }
    public static var press: Animation { .snappy(duration: pressDuration) }
    public static var release: Animation { .snappy(duration: releaseDuration, extraBounce: 0.04) }
    public static var state: Animation { .smooth(duration: stateDuration) }
    public static var numeric: Animation { .smooth(duration: numericDuration) }
    public static var chip: Animation { .smooth(duration: chipDuration) }

    // 动态设计：带回弹的弹簧（以感知时长定义；悬停 / 按下 ≤ 250ms）。
    public static let dynamicHoverScale: CGFloat = 1.07
    public static let dynamicPressScale: CGFloat = 0.90
    public static let sheenOpacity: Double = 0.24
    public static var dynamicHover: Animation { .spring(duration: 0.24, bounce: 0.32) }
    public static var dynamicPress: Animation { .spring(duration: 0.14, bounce: 0) }
    public static var dynamicRelease: Animation { .spring(duration: 0.25, bounce: 0.45) }
    public static var dynamicState: Animation { .spring(duration: 0.25, bounce: 0.30) }
    /// 选中底色在相邻按钮之间滑动、进度环填充。状态过渡，不属于悬停/按下。
    public static var dynamicMorph: Animation { .spring(duration: 0.32, bounce: 0.22) }
    public static var dynamicChip: Animation { .spring(duration: 0.30, bounce: 0.35) }
    public static var dynamicSheen: Animation { .smooth(duration: 0.12) }

    // 既有参数（数值与原 MotionTokens 完全一致，仅集中到此处，供主 App 引用）。
    public static var micro: Animation { .spring(response: 0.22, dampingFraction: 0.82) }
    public static var floating: Animation { .spring(response: 0.32, dampingFraction: 0.86) }
    public static var navigation: Animation { .spring(response: 0.42, dampingFraction: 0.88) }
    public static var aiOpening: Animation { .spring(response: 0.36, dampingFraction: 0.96) }
    public static var aiClosing: Animation { .spring(response: 0.48, dampingFraction: 0.96) }
    public static var settingsOpening: Animation { .spring(response: 0.38, dampingFraction: 0.90) }
    public static var settingsClosing: Animation { .spring(response: 0.46, dampingFraction: 0.90) }

    /// 减少动态效果或动效等级为“关”时返回 nil，调用方因此得到静态切换。
    public static func resolve(_ animation: Animation, reduceMotion: Bool, enabled: Bool = true) -> Animation? {
        (reduceMotion || !enabled) ? nil : animation
    }
}

/// 控件尺寸 token（单位 pt）。
public enum LumaControlMetric {
    // 阅读页顶栏
    public static let toolbarItemHeight: CGFloat = 40
    public static let toolbarItemMaxWidth: CGFloat = 44
    public static let toolbarCapsuleHorizontalPadding: CGFloat = 6
    public static let toolbarCapsuleVerticalPadding: CGFloat = 4
    public static let toolbarIconPointSize: CGFloat = 17
    // 听写页
    public static let actionHeight: CGFloat = 44
    public static let actionIconPointSize: CGFloat = 16
    public static let actionBarPadding: CGFloat = 5
    public static let actionBarRadius: CGFloat = 27      // (44 + 2×5) ÷ 2
    public static let actionBarCompactRadius: CGFloat = 22
    public static let actionBarCompactThreshold: CGFloat = 420
    public static let backCapsuleHeight: CGFloat = 40
    public static let chipVisualHeight: CGFloat = 30
    public static let minimumHitHeight: CGFloat = 40
    // 状态
    public static let focusRingWidth: CGFloat = 2
    public static let focusRingInset: CGFloat = 2
    public static let hoverFillOpacity: Double = 0.08
    public static let pressFillOpacity: Double = 0.14
    public static let selectedFillOpacity: Double = 0.20
    public static let disabledOpacity: Double = 0.38
    public static let increasedContrastStroke: CGFloat = 1
    /// true：自绘强调色焦点环并关闭系统焦点环。若实机上键盘聚焦看不到焦点环，改为 false 即恢复系统焦点环。
    public static let customFocusRing = true
}

// MARK: - 统一按钮样式（六种状态）

/// 默认 / 悬停 / 按下 / 聚焦 / 禁用 / 选中。颜色全部由调用方传入既有语义色。
public struct LumaIconButtonStyle: ButtonStyle {
    public enum Emphasis: Equatable, Sendable {
        /// 默认图标按钮
        case plain
        /// 激活：前景改为强调色（图标填充由调用方切换），无底色。用于书签等“已存在”状态
        case active
        /// 选中：强调色前景 + 强调色淡底（面板打开、提示开启）
        case selected
        /// 主按钮：强调色实底
        case prominent
    }

    var ink: Color
    var accent: Color
    var emphasis: Emphasis
    var onAccent: Color
    var baseFill: Color?
    var baseStroke: Color?
    var motionEnabled: Bool
    var selectionNamespace: Namespace.ID?

    /// - selectionNamespace: 同一组互斥按钮共用时，动态设计下选中底色会在按钮之间滑动。
    public init(ink: Color, accent: Color, emphasis: Emphasis = .plain, onAccent: Color? = nil,
                baseFill: Color? = nil, baseStroke: Color? = nil, motionEnabled: Bool = true,
                selectionNamespace: Namespace.ID? = nil) {
        self.ink = ink
        self.accent = accent
        self.emphasis = emphasis
        self.onAccent = onAccent ?? ink
        self.baseFill = baseFill
        self.baseStroke = baseStroke
        self.motionEnabled = motionEnabled
        self.selectionNamespace = selectionNamespace
    }

    public func makeBody(configuration: Configuration) -> some View {
        LumaIconButtonBody(configuration: configuration, style: self)
    }
}

struct LumaIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let style: LumaIconButtonStyle
    @State private var hovered = false
    @State private var pointer: CGPoint?
    @State private var bounceTick = 0
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lumaDynamicMotion) private var dynamicStyle

    private var pressed: Bool { configuration.isPressed && isEnabled }
    private var hot: Bool { hovered && isEnabled }
    /// 动态设计是否生效；静态设计下所有动画为 nil。
    private var dynamic: Bool { style.motionEnabled && dynamicStyle && !reduceMotion }

    private var selectedFill: Color {
        style.accent.opacity(LumaControlMetric.selectedFillOpacity + (pressed ? 0.08 : (hot ? 0.04 : 0)))
    }

    private var stateFill: Color {
        switch style.emphasis {
        case .prominent:
            return style.accent.opacity(pressed ? 0.84 : (hot ? 0.93 : 1))
        case .selected:
            return selectedFill
        case .plain, .active:
            return style.ink.opacity(pressed ? LumaControlMetric.pressFillOpacity : (hot ? LumaControlMetric.hoverFillOpacity : 0))
        }
    }

    private var foreground: Color {
        switch style.emphasis {
        case .prominent: return style.onAccent
        case .selected, .active: return style.accent
        case .plain: return style.ink
        }
    }

    private var scale: CGFloat {
        guard dynamic else { return 1 }
        if pressed { return LumaMotionToken.dynamicPressScale }
        return hot ? LumaMotionToken.dynamicHoverScale : 1
    }

    private var sheenColor: Color { style.emphasis == .prominent ? style.onAccent : style.accent }

    var body: some View {
        let shape = Capsule(style: .continuous)
        configuration.label
            .foregroundStyle(foreground)
            // 动态：松手与选中状态变化时图标弹跳一次（事件触发，不循环）。
            .symbolEffect(.bounce.down, options: .nonRepeating, value: bounceTick)
            .background {
                ZStack {
                    if let base = style.baseFill { shape.fill(base) }
                    if style.emphasis == .selected, dynamic, let ns = style.selectionNamespace {
                        // 同组互斥按钮共享这块底色：切换时在按钮之间滑动。
                        shape.fill(selectedFill).matchedGeometryEffect(id: "luma.selection", in: ns)
                    } else {
                        shape.fill(stateFill)
                    }
                }
            }
            .overlay {
                // 动态：指针跟随的柔和高光，只在悬停期间存在。
                if dynamic, hot, let pointer {
                    GeometryReader { proxy in
                        RadialGradient(
                            colors: [sheenColor.opacity(LumaMotionToken.sheenOpacity), sheenColor.opacity(0)],
                            center: UnitPoint(x: pointer.x / max(1, proxy.size.width), y: pointer.y / max(1, proxy.size.height)),
                            startRadius: 0,
                            endRadius: max(proxy.size.width, proxy.size.height) * 0.8
                        )
                    }
                    .clipShape(shape)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .overlay {
                if let stroke = style.baseStroke {
                    shape.strokeBorder(stroke, lineWidth: 1)
                } else if contrast == .increased, style.emphasis == .selected || hot {
                    // 提高对比度：选中与悬停额外描边，不只依赖淡底。
                    shape.strokeBorder(foreground.opacity(0.7), lineWidth: LumaControlMetric.increasedContrastStroke)
                }
            }
            .overlay {
                if isFocused && LumaControlMetric.customFocusRing {
                    shape.inset(by: LumaControlMetric.focusRingInset)
                        .strokeBorder(style.emphasis == .prominent ? style.onAccent : style.accent,
                                      lineWidth: LumaControlMetric.focusRingWidth)
                        .allowsHitTesting(false)
                }
            }
            .opacity(isEnabled ? 1 : LumaControlMetric.disabledOpacity)
            .scaleEffect(scale)
            .contentShape(shape)
            .focusEffectDisabled(LumaControlMetric.customFocusRing)
            .onHover { inside in hovered = inside }
            .onContinuousHover { phase in
                guard dynamic else { if pointer != nil { pointer = nil }; return }
                switch phase {
                case .active(let location): pointer = location
                case .ended: pointer = nil
                }
            }
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                if dynamic, wasPressed, !isPressed { bounceTick += 1 }
            }
            .onChange(of: style.emphasis) { _, _ in
                if dynamic { bounceTick += 1 }
            }
            .animation(dynamic ? LumaMotionToken.dynamicHover : nil, value: hovered)
            .animation(dynamic ? LumaMotionToken.dynamicSheen : nil, value: pointer)
            .animation(dynamic ? (configuration.isPressed ? LumaMotionToken.dynamicPress : LumaMotionToken.dynamicRelease) : nil,
                       value: configuration.isPressed)
            .animation(dynamic ? LumaMotionToken.dynamicState : nil, value: style.emphasis)
    }
}

// MARK: - 红黄绿对齐锚点

/// 顶栏胶囊上报自己的垂直中心（自窗口顶部起算，SwiftUI `.global` 坐标），
/// 主 App 读取后作为 NativeWindowControls 的对齐目标。多个来源时取第一个非空值。
public struct LumaWindowControlsAnchorKey: PreferenceKey {
    public static let defaultValue: CGFloat? = nil
    public static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if value == nil { value = nextValue() }
    }
}

public extension View {
    /// 把本视图的中心 y 作为红黄绿对齐目标上报。
    func lumaWindowControlsAnchor(_ enabled: Bool = true) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: LumaWindowControlsAnchorKey.self,
                                       value: enabled ? proxy.frame(in: .global).midY : nil)
            }
        }
    }
}
