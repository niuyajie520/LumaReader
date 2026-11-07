import SwiftUI

public struct StudyAppearance: Equatable, Sendable {
    public var paper: Color
    public var ink: Color
    public var accent: Color
    public var surface: Color
    public var glassEnabled: Bool
    public var isDark: Bool

    public init(
        paper: Color,
        ink: Color,
        accent: Color,
        surface: Color,
        glassEnabled: Bool = true,
        isDark: Bool = false
    ) {
        self.paper = paper
        self.ink = ink
        self.accent = accent
        self.surface = surface
        self.glassEnabled = glassEnabled
        self.isDark = isDark
    }

    public var line: Color { ink.opacity(isDark ? 0.16 : 0.12) }
    public var selected: Color { accent.opacity(isDark ? 0.24 : 0.16) }
    public var primaryGradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(isDark ? 0.30 : 0.22), surface], startPoint: .topLeading, endPoint: .bottomTrailing)
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
public struct StudyGlassCapsuleModifier: ViewModifier {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public var cornerRadius: CGFloat = 22
    public var prominent: Bool = false
    public var selected: Bool = false

    public func body(content: Content) -> some View {
        let useGlass = appearance.glassEnabled && !reduceTransparency
        let fillTint = prominent
            ? appearance.accent.opacity(appearance.isDark ? 0.86 : 0.90)
            : (selected ? appearance.selected : appearance.surface)
        let borderTint = prominent || selected
            ? appearance.accent.opacity(0.55)
            : appearance.line

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(useGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(fillTint))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(fillTint.opacity(useGlass ? 0.72 : 1.0))
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
                    .shadow(color: Color.black.opacity(appearance.isDark ? 0.22 : 0.06), radius: 8, x: 0, y: 3)
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
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    public var prominent: Bool = false
    public var selected: Bool = false
    public var horizontalPadding: CGFloat = 14
    public var height: CGFloat = 34

    public init(prominent: Bool = false, selected: Bool = false, horizontalPadding: CGFloat = 14, height: CGFloat = 34) {
        self.prominent = prominent
        self.selected = selected
        self.horizontalPadding = horizontalPadding
        self.height = height
    }

    public func makeBody(configuration: Configuration) -> some View {
        let scale: CGFloat = reduceMotion ? 1.0 : (configuration.isPressed ? 0.96 : (hovered ? 1.02 : 1.0))
        configuration.label
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
