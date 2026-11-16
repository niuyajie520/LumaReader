// === PROJECT RED LINE / 项目红线 BEGIN ===
// 调色与设计 Token 文件（Theme.swift / MonetTheme.swift / LumaDesignTokens.swift）：
// 五大经典主题（暖纸白、鼠尾草绿、樱花粉、午夜蓝、纯黑）及 Monet 动态调色逻辑必须严格保护，不得擅自修改颜色定义或删除主题。
// 1.8.0：主人明确授权重设计经典配色（强调色与表面色）；纸张色保持与 Reader.js 一致。
// Preserve theme definitions, palettes, and design tokens without modification.
// 完整规则见项目根目录 AGENTS.md；所有开发者与 AI 必须遵守。
// All developers and AI assistants must follow the project-root AGENTS.md.
// === PROJECT RED LINE / 项目红线 END ===
import SwiftUI
import LumaReaderStudyKit
import AppKit

enum ReaderTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case paper, mint, rose, midnight, black
    var id: String { rawValue }
    var title: String {
        switch self { case .paper: return "暖纸白"; case .mint: return "鼠尾草绿"; case .rose: return "樱花粉"; case .midnight: return "午夜蓝"; case .black: return "纯黑" }
    }
    var forcesDark: Bool { self == .midnight || self == .black }
    var accent: Color {
        switch self {
        // 1.8.0 (owner-authorised redesign): deeper, more characterful accents; paper colours unchanged
        // so the EPUB engine (Reader.js) palette stays in sync.
        case .paper: return Color(hex: "9A6A3E")
        case .mint: return Color(hex: "4E8A66")
        case .rose: return Color(hex: "C0607F")
        case .midnight: return Color(hex: "94B0F0")
        case .black: return Color(hex: "CFCFCF")
        }
    }
    func paper(dark: Bool) -> Color {
        switch self {
        case .paper: return Color(hex: dark ? "24221F" : "FAF8F3")
        case .mint: return Color(hex: dark ? "1C2620" : "F3F7F0")
        case .rose: return Color(hex: dark ? "2B2026" : "FCF4F7")
        case .midnight: return Color(hex: "151D2C")
        case .black: return Color.black
        }
    }
    func chrome(dark: Bool) -> Color {
        switch self {
        case .paper: return Color(hex: dark ? "2C2822" : "EDE4D3")
        case .mint: return Color(hex: dark ? "212D25" : "E1ECDD")
        case .rose: return Color(hex: dark ? "35252E" : "F5E1E9")
        case .midnight: return Color(hex: "1B2640")
        case .black: return Color(hex: "0C0C0C")
        }
    }
}

// 3-tier motion token hierarchy synthesizing emilkowalski/skills (emil-design-eng, apple-design),
// feitangyuan/motion-web (motion-tokens.md, handfeel.md), and ruiqichenbiec/design-systems (Lens & Overture).
enum LumaMotion {
    static let disclosure = Animation.smooth(duration:0.24,extraBounce:0)
    static let panel = Animation.smooth(duration:0.28,extraBounce:0)
    static let popover = Animation.smooth(duration:0.24,extraBounce:0)
    // Tier 1: Instant pointer-down compression & snappy release rebound (100-160ms feel, scale 0.97).
    static let press = Animation.snappy(duration:0.16,extraBounce:0)
    // Tier 2: Component state transitions, note expansion, and hover response.
    static let interactive = Animation.smooth(duration:0.24,extraBounce:0)
    // Tier 3: Critically damped spatial motion for floating bars, popovers, and panels (zero bounce).
    static let spatial = Animation.smooth(duration:0.28,extraBounce:0)

    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : animation
    }
}

private struct LumaMotionLevelKey: EnvironmentKey {
    static let defaultValue: VisualMotionLevel = .enhanced
}
extension EnvironmentValues {
    var lumaMotionLevel: VisualMotionLevel {
        get { self[LumaMotionLevelKey.self] }
        set { self[LumaMotionLevelKey.self] = newValue }
    }
}
extension LumaMotion {
    static func adjusted(_ animation:Animation,level:VisualMotionLevel,reduceMotion:Bool) -> Animation? {
        if reduceMotion || level == .off { return nil }
        if level == .balanced { return .easeOut(duration:0.18) }
        return animation
    }
}

// Responsive tactile button style: responds immediately on pointer-down (isPressed -> scale(0.97))
// with subtle hover illumination and interruptible spring physics.
struct LumaTactileButtonStyle: ButtonStyle {
    // 统一按钮系统（LumaButtonSystem.swift）：圆角 10、最小高 36、悬停只加淡底、按下 0.97。
    @Environment(\.lumaInk) private var ink
    @Environment(\.lumaGlass) private var glass
    var pressScale: CGFloat = LumaButtonMetric.pressScale
    var cornerRadius: CGFloat = LumaButtonMetric.cornerRadius
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 5
    var prominent: Bool = false
    var accent: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let still = reduceMotion || motionLevel == .off
        let shape = RoundedRectangle(cornerRadius: LumaButtonMetric.cornerRadius, style: .continuous)
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minWidth: 36, minHeight: LumaButtonSize.regular.height)
            .contentShape(shape)
            .background {
                if prominent {
                    shape.fill(accent.opacity(pressed ? 0.84 : (isHovered ? 0.92 : 1.0)))
                } else {
                    shape.fill(ink.opacity(pressed ? LumaButtonMetric.pressFill : (isHovered ? LumaButtonMetric.hoverFill : 0)))
                }
            }
            .overlay {
                if glass && !prominent {
                    shape.strokeBorder(ink.opacity(isHovered ? LumaButtonMetric.strokeOpacity : 0), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
            .foregroundStyle(prominent ? accent.lumaContrastingInk : ink)
            .opacity(isEnabled ? 1 : LumaButtonMetric.disabledOpacity)
            .scaleEffect(still || !pressed ? 1.0 : LumaButtonMetric.pressScale)
            .animation(LumaButtonMetric.hoverAnimation(reduceMotion: still), value: isHovered)
            .animation(LumaButtonMetric.pressAnimation(reduceMotion: still), value: pressed)
            .onHover { isHovered = $0 }
    }
}

// Sidebar row button style with Lens directional specular rim on active selection and tactile press response.
struct LumaSidebarButtonStyle: ButtonStyle {
    // 侧栏行：整行按钮，按下只缩 0.985；选中是强调色淡底，圆角 10。
    @Environment(\.lumaInk) private var ink
    var isSelected: Bool = false
    var accent: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let still = reduceMotion || motionLevel == .off
        let shape = RoundedRectangle(cornerRadius: LumaButtonMetric.cornerRadius, style: .continuous)
        let fill: Color = isSelected
            ? accent.opacity(LumaButtonMetric.selectedFill * 0.6 + (pressed ? 0.04 : 0))
            : ink.opacity(pressed ? LumaButtonMetric.pressFill * 0.8 : (isHovered ? LumaButtonMetric.hoverFill * 0.75 : 0))
        configuration.label
            .frame(maxWidth: .infinity, minHeight: LumaButtonSize.large.height)
            .contentShape(Rectangle())
            .background(shape.fill(fill))
            .scaleEffect(still || !pressed ? 1 : LumaButtonMetric.rowPressScale)
            .animation(LumaButtonMetric.pressAnimation(reduceMotion: still), value: pressed)
            .animation(LumaButtonMetric.hoverAnimation(reduceMotion: still), value: isSelected)
            .onHover { isHovered = $0 }
    }
}

// Press feedback stays; repeated pointer movement changes only a static tint.
struct LumaBookCardButtonStyle: ButtonStyle {
    // 书封：悬停不放大、不上浮，只出现一层很淡的阴影；按下缩 0.985。
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let still = reduceMotion || motionLevel == .off
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(still || !pressed ? 1.0 : LumaButtonMetric.rowPressScale)
            .background {
                RoundedRectangle(cornerRadius: LumaButtonMetric.cornerRadius)
                    .fill(Color.black.opacity(0.02))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
                    .opacity(isHovered ? 1 : 0)
            }
            .animation(LumaButtonMetric.hoverAnimation(reduceMotion: still), value: isHovered)
            .animation(LumaButtonMetric.pressAnimation(reduceMotion: still), value: pressed)
            .onHover { isHovered = $0 }
    }
}

// Highlight ink swatch button style with crisp tactile spring feedback.
struct LumaSwatchButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel

    func makeBody(configuration: Configuration) -> some View {
        let still = reduceMotion || motionLevel == .off
        configuration.label
            .frame(width: LumaButtonSize.large.height - 4, height: LumaButtonSize.large.height - 4).contentShape(Rectangle())
            .scaleEffect(still || !configuration.isPressed ? 1.0 : LumaButtonMetric.pressScale)
            .animation(LumaButtonMetric.pressAnimation(reduceMotion: still), value: configuration.isPressed)
    }
}

extension Color {
    init(hex: String) {
        let n = UInt32(hex, radix:16) ?? 0
        self.init(.sRGB, red:Double((n >> 16) & 255)/255,green:Double((n >> 8) & 255)/255,blue:Double(n & 255)/255,opacity:1)
    }
}

struct LumaHeaderButtonStyle: ButtonStyle {
    @Environment(\.lumaInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        let still = reduceMotion || motionLevel == .off
        let pressed = configuration.isPressed
        configuration.label
            .frame(minWidth: LumaButtonSize.large.height, minHeight: LumaButtonSize.large.height)
            .contentShape(Rectangle())
            .background(ink.opacity(pressed ? LumaButtonMetric.pressFill : (isHovered ? LumaButtonMetric.hoverFill : 0)),
                        in: RoundedRectangle(cornerRadius: LumaButtonMetric.cornerRadius, style: .continuous))
            .scaleEffect(still || !pressed ? 1 : LumaButtonMetric.pressScale)
            .animation(LumaButtonMetric.pressAnimation(reduceMotion: still), value: pressed)
            .animation(LumaButtonMetric.hoverAnimation(reduceMotion: still), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// Animate only the newly presented content. Its opaque themed backing is already visible.
struct LumaPanelEntrance:ViewModifier {
    var anchor:UnitPoint = .topLeading
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.lumaSurfacePolish) private var polished
    @State private var visible = false
    func body(content:Content)->some View {
        content.opacity(visible ? 1:0).scaleEffect(visible || reduceMotion || motionLevel == .off ? 1:0.985,anchor:anchor)
            .offset(y:visible || reduceMotion || motionLevel == .off ? 0:-5)
            .animation(LumaMotion.adjusted(polished ? SurfaceMotion.popover:LumaMotion.popover,level:motionLevel,reduceMotion:reduceMotion),value:visible)
            .onAppear { visible = true }.onDisappear { visible = false }
    }
}

struct LumaSidebarSection<Content:View>:View {
    @Environment(\.lumaMuted) private var muted
    @Environment(\.lumaInk) private var ink
    @Environment(\.lumaSurface) private var surface
    @Environment(\.lumaGlass) private var glass
    let title:String
    let onAdd:(()->Void)?
    let onSearch:(()->Void)?
    let symbol:String?
    let prominent:Bool
    let headerFont:Font?
    let busy:Bool
    let content:Content
    @AppStorage private var expanded:Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.lumaSurfacePolish) private var polished
    init(_ title:String,key:String,onAdd:(()->Void)? = nil,onSearch:(()->Void)? = nil,symbol:String? = nil,prominent:Bool = false,font:Font? = nil,busy:Bool = false,@ViewBuilder content:()->Content) {
        self.title = title; self.onAdd = onAdd; self.busy = busy; self.content = content()
        self.onSearch = onSearch; self.symbol = symbol; self.prominent = prominent; self.headerFont = font
        _expanded = AppStorage(wrappedValue:true,key)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:3) {
            Group {
                if prominent { sectionHeader.readerGlass(radius:12,enabled:glass,tint:surface).padding(.horizontal,12) }
                else { sectionHeader }
            }
            if expanded { content.transition(.opacity) }
        }.animation(reduceMotion || motionLevel == .off ? nil:.spring(duration:0.30,bounce:0.08),value:expanded)
    }
    private var sectionHeader:some View {
            HStack(spacing:0) {
                Button { expanded.toggle() } label: {
                    HStack(spacing:7) {
                        if !prominent {
                        Image(systemName:"chevron.right").font(.system(size:11,weight:.semibold))
                            .rotationEffect(.degrees(expanded ? 90:0)).frame(width:18)
                        }
                        if let symbol { Image(systemName:symbol).font(.system(size:21,weight:.regular)).frame(width:24) }
                        Text(L10n.text(title)).font(headerFont ?? .system(size:prominent ? 17:12,weight:.medium))
                        Spacer(minLength:0)
                        if prominent { Image(systemName:"chevron.right").font(.system(size:12,weight:.medium)).rotationEffect(.degrees(expanded ? 90:0)).frame(width:18) }
                    }.foregroundStyle(prominent ? ink:muted).padding(.leading,prominent ? 12:16).padding(.trailing,prominent ? 12:8).frame(maxWidth:.infinity,minHeight:prominent ? 50:44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(L10n.text((expanded ? "折叠":"展开")+title))
                if busy { ProgressView().controlSize(.mini).padding(.horizontal,6) }
                if let onSearch {
                    Button { expanded = true; onSearch() } label: { Image(systemName:"magnifyingglass").font(.system(size:12)).frame(width:32,height:44).contentShape(Rectangle()) }
                        .buttonStyle(LumaHeaderButtonStyle()).help(L10n.text("搜索分类")).accessibilityLabel(L10n.text("搜索分类"))
                }
                if let onAdd {
                    Button { expanded = true; onAdd() } label: { Image(systemName:"plus").frame(width:40,height:44).contentShape(Rectangle()) }
                        .buttonStyle(LumaHeaderButtonStyle()).help(L10n.text("新建分类")).accessibilityLabel(L10n.text("新建分类"))
                }
            }.padding(.trailing,onAdd == nil ? 0:8)
    }
}

/// A short, capped cascade for a fresh result set; text entry itself never moves.
struct LumaResultEntrance: ViewModifier {
    var index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.lumaSurfacePolish) private var polished
    @State private var appeared = false
    func body(content:Content) -> some View {
        let animated = !reduceMotion && motionLevel == .enhanced
        content.opacity(appeared || !animated ? 1:0)
            .offset(y:appeared || !animated ? 0:5)
            .animation(animated ? .easeOut(duration:0.16).delay(Double(min(index,4))*0.02):nil,value:appeared)
            .onAppear { appeared = true }
    }
}
