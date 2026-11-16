import SwiftUI

/// 手机端的配色：沿用阅读纸张色，深色模式下自动换成深纸张。
enum LumaTheme {
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.09, green: 0.09, blue: 0.10) : Color(red: 0.98, green: 0.97, blue: 0.95)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color.white
    }

    static let accent = Color(red: 0.16, green: 0.44, blue: 0.62)
    static let positive = Color(red: 0.18, green: 0.55, blue: 0.36)
    static let warning = Color(red: 0.72, green: 0.42, blue: 0.12)
}

extension Color {
    static var lumaPaper: Color { Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1) : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
    }) }

    static var lumaSurface: Color { Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1) : UIColor.white
    }) }

    static var lumaAccent: Color { LumaTheme.accent }
    static var lumaPositive: Color { LumaTheme.positive }
    static var lumaWarning: Color { LumaTheme.warning }
}

/// 主按钮：实心，按下 0.97，无回弹。
struct LumaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? Color.lumaAccent : Color.lumaAccent.opacity(0.35))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

/// 次按钮：描边。
struct LumaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

/// 行内小按钮（工具条用），点击区至少 44pt。
struct LumaIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .frame(width: 44, height: 44)
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}
