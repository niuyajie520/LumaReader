import SwiftUI

private struct LumaTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

public extension EnvironmentValues {
    var lumaTextScale: CGFloat {
        get { self[LumaTextScaleKey.self] }
        set { self[LumaTextScaleKey.self] = newValue }
    }
}

private struct LumaScaledFont: ViewModifier {
    @Environment(\.lumaTextScale) private var scale
    let size: CGFloat
    let weight: Font.Weight?
    let design: Font.Design?
    let monospacedDigits: Bool

    func body(content: Content) -> some View {
        let font = Font.system(size: size * scale, weight: weight ?? .regular, design: design ?? .default)
        content.font(monospacedDigits ? font.monospacedDigit() : font)
    }
}

public extension View {
    func lumaFont(size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil,
                  monospacedDigits: Bool = false) -> some View {
        modifier(LumaScaledFont(size: size, weight: weight, design: design, monospacedDigits: monospacedDigits))
    }
}
