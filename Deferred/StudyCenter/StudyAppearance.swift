import SwiftUI

public struct StudyAppearance: Equatable, Sendable {
    public nonisolated(unsafe) static var current = StudyAppearance(
        paper: Color(nsColor: .windowBackgroundColor),
        ink: .primary,
        accent: .accentColor,
        surface: Color.primary.opacity(0.06)
    )
    public nonisolated(unsafe) static var liveOverride: StudyAppearance? = nil

    public var paper: Color
    public var ink: Color
    public var accent: Color
    public var surface: Color
    public var glassEnabled: Bool
    public var glassOpacity: Double
    public var visualThemeSystem: String = "monet"
    public var spaceGlowIntensity: Double = 0.55
    public var spaceOrbitalLines: Bool = true
    public var mangaScreentoneDensity: Double = 0.35
    public var mangaLineWeight: Double = 1.5
    public var mangaPopoverTranslucent: Bool = false
    public var isDark: Bool
    public var glassRenderer: (@MainActor @Sendable (AnyView, CGFloat, Bool, Bool, Color) -> AnyView)?

    public init(
        paper: Color,
        ink: Color,
        accent: Color,
        surface: Color,
        glassEnabled: Bool = true,
        glassOpacity: Double = 0.72,
        isDark: Bool = false,
        visualThemeSystem: String = "monet", spaceGlowIntensity: Double = 0.55,
        spaceOrbitalLines: Bool = true, mangaScreentoneDensity: Double = 0.35,
        mangaLineWeight: Double = 1.5, mangaPopoverTranslucent: Bool = false,
        glassRenderer: (@MainActor @Sendable (AnyView, CGFloat, Bool, Bool, Color) -> AnyView)? = nil
    ) {
        self.paper = paper
        self.ink = ink
        self.accent = accent
        self.surface = surface
        self.glassEnabled = glassEnabled
        self.glassOpacity = glassOpacity
        self.isDark = isDark
        self.visualThemeSystem = visualThemeSystem; self.spaceGlowIntensity = spaceGlowIntensity
        self.spaceOrbitalLines = spaceOrbitalLines; self.mangaScreentoneDensity = mangaScreentoneDensity
        self.mangaLineWeight = mangaLineWeight; self.mangaPopoverTranslucent = mangaPopoverTranslucent
        self.glassRenderer = glassRenderer
    }

    public static func == (lhs: StudyAppearance, rhs: StudyAppearance) -> Bool {
        lhs.paper == rhs.paper &&
        lhs.ink == rhs.ink &&
        lhs.accent == rhs.accent &&
        lhs.surface == rhs.surface &&
        lhs.glassEnabled == rhs.glassEnabled &&
        lhs.glassOpacity == rhs.glassOpacity &&
        lhs.isDark == rhs.isDark && lhs.visualThemeSystem == rhs.visualThemeSystem &&
        lhs.spaceGlowIntensity == rhs.spaceGlowIntensity && lhs.spaceOrbitalLines == rhs.spaceOrbitalLines &&
        lhs.mangaScreentoneDensity == rhs.mangaScreentoneDensity && lhs.mangaLineWeight == rhs.mangaLineWeight &&
        lhs.mangaPopoverTranslucent == rhs.mangaPopoverTranslucent
    }

    public var background: some View {
        VisualThemeBackdrop(system:visualThemeSystem, paper:paper, accent:accent, glow:spaceGlowIntensity,
                            orbitals:spaceOrbitalLines, density:mangaScreentoneDensity, lineWeight:mangaLineWeight)
    }
    public var line: Color { ink.opacity(isDark ? 0.16 : 0.12) }
    public var selected: Color { accent.opacity(isDark ? 0.28 : 0.18) }
    public var primaryGradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(isDark ? 0.28 : 0.20), surface], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    public var secondaryGradient: LinearGradient {
        LinearGradient(colors: [surface, paper], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct StudyAppearanceKey: EnvironmentKey {
    static let defaultValue = StudyAppearance(
        paper: Color(nsColor: .windowBackgroundColor),
        ink: .primary,
        accent: .accentColor,
        surface: Color.primary.opacity(0.06)
    )
}

public extension EnvironmentValues {
    var studyAppearance: StudyAppearance {
        get { self[StudyAppearanceKey.self] }
        set { self[StudyAppearanceKey.self] = newValue }
    }
}

/// Reader-consistent rounded glass capsule container modifier used across Listening, Writing, and Study toolbars.
/// When mounted inside LumaReader, delegates directly to `ReaderGlassSurface` via `appearance.glassRenderer`
/// so the glass translucency slider and active theme in Settings dynamically control all Study Center bars.
public struct StudyGlassCapsuleModifier: ViewModifier {
    @Environment(\.studyAppearance) private var envAppearance
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public var cornerRadius: CGFloat = 22
    public var prominent: Bool = false
    public var selected: Bool = false

    private var appearance: StudyAppearance {
        StudyAppearance.liveOverride ?? envAppearance
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        let useGlass = appearance.glassEnabled && !reduceTransparency
        let fillTint = prominent
            ? appearance.accent.opacity(appearance.isDark ? 0.88 : 0.92)
            : (selected ? appearance.selected : appearance.surface)
        let borderTint = prominent || selected
            ? appearance.accent.opacity(0.55)
            : appearance.line

        if let renderer = appearance.glassRenderer {
            renderer(AnyView(content), cornerRadius, prominent, selected, fillTint)
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(useGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(fillTint))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(fillTint.opacity(useGlass ? appearance.glassOpacity : 1.0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(appearance.isDark ? 0.22 : 0.45),
                                            borderTint
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: selected || prominent ? 1.2 : 0.8
                                )
                        )
                }
        }
    }
}

public extension View {
    func studyGlassCapsule(cornerRadius: CGFloat = 22, prominent: Bool = false, selected: Bool = false) -> some View {
        modifier(StudyGlassCapsuleModifier(cornerRadius: cornerRadius, prominent: prominent, selected: selected))
    }
}

/// Reader-consistent interactive glass capsule button style with gentle hover highlight and press spring.
public struct StudyGlassCapsuleButtonStyle: ButtonStyle {
    @Environment(\.studyAppearance) private var envAppearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    public var prominent: Bool = false
    public var selected: Bool = false
    public var horizontalPadding: CGFloat = 14
    public var height: CGFloat = 34

    private var appearance: StudyAppearance {
        StudyAppearance.liveOverride ?? envAppearance
    }

    public init(prominent: Bool = false, selected: Bool = false, horizontalPadding: CGFloat = 14, height: CGFloat = 34) {
        self.prominent = prominent
        self.selected = selected
        self.horizontalPadding = horizontalPadding
        self.height = height
    }

    public func makeBody(configuration: Configuration) -> some View {
        let scale: CGFloat = reduceMotion ? 1.0 : (configuration.isPressed ? 0.96 : (hovered ? 1.02 : 1.0))
        configuration.label
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .font(.system(size: 13, weight: prominent || selected ? .semibold : .medium))
            .foregroundStyle(prominent ? Color.white : appearance.ink)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background(
                Capsule(style: .continuous)
                    .fill(hovered ? appearance.ink.opacity(0.06) : Color.clear)
            )
            .studyGlassCapsule(cornerRadius: height / 2, prominent: prominent, selected: selected)
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(scale)
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78), value: hovered)
            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - 统一动效：放慢并使用缓入缓出，避免切换时晃眼

public enum StudyMotion {
    /// 页面切换（交叉淡入淡出）
    public static let page: Animation = .easeOut(duration: 0.20)
    /// 分段标签选中底色滑动
    public static let tab: Animation = .easeOut(duration: 0.20)
    /// 悬停高亮
    public static let hover: Animation = .easeOut(duration: 0.13)
    /// 按下反馈
    public static let press: Animation = .easeOut(duration: 0.09)
}

// MARK: - 与看书中心一致的页面骨架组件

/// 与看书中心书库页一致的尺寸规范（页边距 42、顶部 26、标题 30pt）。
public enum StudyMetrics {
    public static let pageHorizontal: CGFloat = 42
    public static let pageTop: CGFloat = 26
    public static let pageBottom: CGFloat = 40
    public static let sectionSpacing: CGFloat = 22
    public static let cardRadius: CGFloat = 14
    public static let titleSize: CGFloat = 30
}

/// 页面标题行：左侧大标题，右侧放搜索框或主操作，与看书中心「全部图书 + 搜索」一致。
public struct StudyPageHeader<Trailing: View>: View {
    @Environment(\.studyAppearance) private var appearance
    private let title: String
    private let trailing: Trailing

    public init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.system(size: StudyMetrics.titleSize, weight: .medium))
                .foregroundStyle(appearance.ink)
                .lineLimit(1)
            Spacer(minLength: 12)
            HStack(spacing: 8) { trailing }
        }
    }
}

public extension StudyPageHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// 与看书中心一致的胶囊搜索框（放大镜 + 无边框输入，高 40）。
public struct StudySearchField: View {
    @Environment(\.studyAppearance) private var appearance
    private let placeholder: String
    @Binding private var text: String
    private let width: CGFloat

    public init(_ placeholder: String, text: Binding<String>, width: CGFloat = 210) {
        self.placeholder = placeholder
        self._text = text
        self.width = width
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(appearance.ink.opacity(0.5))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(appearance.ink)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(appearance.ink.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .frame(width: width, height: 40)
        .studyGlassCapsule(cornerRadius: 20)
    }
}

/// 扁平卡片外观：与看书中心列表/卡片同样的浅底与细描边。
public struct StudyCardModifier: ViewModifier {
    @Environment(\.studyAppearance) private var appearance
    public var selected: Bool
    public var padding: CGFloat

    public func body(content: Content) -> some View {
        let fillColor: Color = selected ? appearance.selected : appearance.surface
        let strokeColor: Color = selected ? appearance.accent.opacity(0.7) : appearance.line
        let strokeWidth: CGFloat = selected ? 1.5 : 1
        let shape = RoundedRectangle(cornerRadius: StudyMetrics.cardRadius, style: .continuous)
        return content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(fillColor))
            .overlay(shape.strokeBorder(strokeColor, lineWidth: strokeWidth))
            .contentShape(shape)
    }
}

public extension View {
    func studyCard(selected: Bool = false, padding: CGFloat = 16) -> some View {
        modifier(StudyCardModifier(selected: selected, padding: padding))
    }

    /// 统一的页面内边距（42 / 26 / 40），与看书中心书库一致。
    func studyPagePadding() -> some View {
        self
            .padding(.horizontal, StudyMetrics.pageHorizontal)
            .padding(.top, StudyMetrics.pageTop)
            .padding(.bottom, StudyMetrics.pageBottom)
    }
}

/// 一个分段标签。
public struct StudyTabItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let symbol: String

    public init(id: String, title: String, symbol: String) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }
}

/// 与看书中心顶部玻璃按钮组一致的分段标签栏。
public struct StudyTabBar: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillNamespace
    @State private var hoveredID: String?
    private let items: [StudyTabItem]
    private let selectedID: String?
    private let onSelect: (StudyTabItem) -> Void

    public init(items: [StudyTabItem], selectedID: String?, onSelect: @escaping (StudyTabItem) -> Void) {
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(3)
        .studyGlassCapsule(cornerRadius: 20)
        .animation(reduceMotion ? nil : StudyMotion.tab, value: selectedID)
        .animation(reduceMotion ? nil : StudyMotion.hover, value: hoveredID)
    }

    @ViewBuilder
    private func pillBackground(isSelected: Bool, isHovered: Bool) -> some View {
        if isSelected {
            Capsule(style: .continuous)
                .fill(appearance.accent.opacity(appearance.isDark ? 0.86 : 0.92))
                .matchedGeometryEffect(id: "study.tab.pill", in: pillNamespace)
        } else if isHovered {
            Capsule(style: .continuous)
                .fill(appearance.ink.opacity(0.06))
        }
    }

    private func tabButton(_ item: StudyTabItem) -> some View {
        let isSelected: Bool = (item.id == selectedID)
        let isHovered: Bool = (item.id == hoveredID)
        let textColor: Color = isSelected ? Color.white : appearance.ink.opacity(0.82)
        return Button {
            onSelect(item)
        } label: {
            Label(item.title, systemImage: item.symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(pillBackground(isSelected: isSelected, isHovered: isHovered))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                hoveredID = item.id
            } else if hoveredID == item.id {
                hoveredID = nil
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 与看书中心「暂无图书」一致的空状态。
public struct StudyEmptyState: View {
    @Environment(\.studyAppearance) private var appearance
    private let title: String
    private let symbol: String

    public init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(appearance.ink.opacity(0.35))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(appearance.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

/// 小号分组标题（如「未完成草稿」「已提交作文」）。
public struct StudySectionLabel: View {
    @Environment(\.studyAppearance) private var appearance
    private let title: String
    private let count: Int?

    public init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(appearance.ink.opacity(0.62))
            if let count {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(appearance.ink.opacity(0.45))
            }
        }
    }
}
