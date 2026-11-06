import SwiftUI
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
        case .paper: return Color(hex: "8C7862")
        case .mint: return Color(hex: "6E9277")
        case .rose: return Color(hex: "BC7B94")
        case .midnight: return Color(hex: "879FCD")
        case .black: return Color(hex: "AAAAAA")
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
        case .paper: return Color(hex: dark ? "292621" : "EEE9E0")
        case .mint: return Color(hex: dark ? "222C25" : "E6EDE2")
        case .rose: return Color(hex: dark ? "33262E" : "F2E4EB")
        case .midnight: return Color(hex: "1C273A")
        case .black: return Color.black
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
    @Environment(\.lumaInk) private var ink
    @Environment(\.lumaGlass) private var glass
    var pressScale: CGFloat = 0.96
    var cornerRadius: CGFloat = 8
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 5
    var prominent: Bool = false
    var accent: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.lumaSurfacePolish) private var polished
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minWidth:40,minHeight:36)
            .contentShape(Rectangle())
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(accent.opacity(pressed ? 0.82 : (isHovered ? 0.92 : 1.0)))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(ink.opacity(pressed ? 0.11 : (isHovered ? 0.055 : 0)))
                }
            }
            .overlay {
                if glass {
                    RoundedRectangle(cornerRadius:cornerRadius,style:.continuous)
                        .strokeBorder(LinearGradient(colors:[accent.opacity(0.28),accent.opacity(0.07)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.7)
                        .allowsHitTesting(false)
                }
            }
            .foregroundStyle(prominent ? accent.lumaContrastingInk : ink)
            .scaleEffect(reduceMotion || motionLevel == .off ? 1.0 : (pressed ? pressScale : 1.0))
            .animation(LumaMotion.adjusted(polished ? SurfaceMotion.press:LumaMotion.press,level:motionLevel,reduceMotion:reduceMotion), value: pressed)
            .onHover { isHovered = $0 }
    }
}

// Sidebar row button style with Lens directional specular rim on active selection and tactile press response.
struct LumaSidebarButtonStyle: ButtonStyle {
    @Environment(\.lumaInk) private var ink
    var isSelected: Bool = false
    var accent: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.lumaSurfacePolish) private var polished
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let fillOpacity: Double = isSelected
            ? (pressed ? 0.12 : 0.085)
            : (pressed ? 0.09 : (isHovered ? 0.045 : 0))
        configuration.label
            .frame(maxWidth:.infinity,minHeight:44)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill((isSelected ? accent:ink).opacity(fillOpacity))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(colorScheme == .dark ? 0.16 : 0.45),
                                            accent.opacity(0.18),
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        }
                    }
            }
            .scaleEffect(reduceMotion || motionLevel == .off ? 1:(pressed ? 0.985:1))
            .animation(LumaMotion.adjusted(SurfaceMotion.press,level:motionLevel,reduceMotion:reduceMotion),value:pressed)
            .animation(LumaMotion.adjusted(SurfaceMotion.interactive,level:motionLevel,reduceMotion:reduceMotion),value:isSelected)
            .onHover { isHovered = $0 }
    }
}

// Press feedback stays; repeated pointer movement changes only a static tint.
struct LumaBookCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.lumaSurfacePolish) private var polished
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let scale: CGFloat = reduceMotion || motionLevel == .off ? 1.0 : (pressed ? 0.972 : (isHovered ? 1.018:1.0))
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(scale)
            .offset(y:reduceMotion || motionLevel != .enhanced ? 0:(isHovered && !pressed ? -4:0))
            .background { RoundedRectangle(cornerRadius:10).fill(Color.black.opacity(0.025)).shadow(color:.black.opacity(0.10),radius:12,y:7).opacity(isHovered ? 1:0) }
            .animation(LumaMotion.adjusted(polished ? SurfaceMotion.interactive:LumaMotion.interactive,level:motionLevel,reduceMotion:reduceMotion),value:isHovered)
            .animation(LumaMotion.adjusted(polished ? SurfaceMotion.press:LumaMotion.press,level:motionLevel,reduceMotion:reduceMotion), value: pressed)
            .onHover { isHovered = $0 }
    }
}

// Highlight ink swatch button style with crisp tactile spring feedback.
struct LumaSwatchButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.lumaSurfacePolish) private var polished

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let scale: CGFloat = reduceMotion || motionLevel == .off ? 1.0 : (pressed ? 0.90 : 1.0)
        configuration.label
            .frame(width:40,height:40).contentShape(Rectangle())
            .scaleEffect(scale)
            .animation(LumaMotion.adjusted(polished ? SurfaceMotion.press:LumaMotion.press,level:motionLevel,reduceMotion:reduceMotion), value: pressed)
    }
}

extension Color {
    init(hex: String) {
        let n = UInt32(hex, radix:16) ?? 0
        self.init(.sRGB, red:Double((n >> 16) & 255)/255,green:Double((n >> 8) & 255)/255,blue:Double(n & 255)/255,opacity:1)
    }
}

struct LumaHeaderButtonStyle:ButtonStyle {
    @Environment(\.lumaInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.lumaSurfacePolish) private var polished
    func makeBody(configuration:Configuration)->some View {
        configuration.label.frame(minWidth:44,minHeight:44).contentShape(Rectangle())
            .background(ink.opacity(configuration.isPressed ? 0.1:0),in:RoundedRectangle(cornerRadius:9))
            .scaleEffect(reduceMotion || motionLevel == .off ? 1:(configuration.isPressed ? 0.97:1))
            .animation(LumaMotion.adjusted(.easeOut(duration:0.1),level:motionLevel,reduceMotion:reduceMotion),value:configuration.isPressed)
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
