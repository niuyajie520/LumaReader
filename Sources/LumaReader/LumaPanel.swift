import SwiftUI
import AppKit

/// A click-away panel stays inside the existing window, preserving the reader underneath.
private struct LumaDismissiblePanel<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    let size: CGSize
    let paper: Color
    let accent: Color
    @Environment(\.lumaGlass) private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    let panel: () -> Panel
    func body(content: Content) -> some View {
        content.disabled(isPresented).accessibilityHidden(isPresented)
            .overlay {
                if isPresented {
                    GeometryReader { geometry in
                        ZStack {
                            Button { isPresented = false } label: {
                                Rectangle().fill(.black.opacity(0.18)).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(L10n.text("关闭面板，返回原界面")).transition(.opacity)
                            panel()
                                .environment(\.lumaSurfacePolish,true)
                                .frame(width:min(size.width,max(280,geometry.size.width-32)),height:min(size.height,max(320,geometry.size.height-32)))
                                .readerGlass(radius:18,enabled:glass,tint:paper)
                                .clipShape(RoundedRectangle(cornerRadius:18,style:.continuous))
                                .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(accent.opacity(0.18)))
                                .shadow(color:.black.opacity(0.22),radius:24,y:10)
                                .contentShape(Rectangle())
                                .onTapGesture { } // Absorb clicks on the panel's own padding.
                                .tint(accent).accentColor(accent)
                                .toggleStyle(LumaThemeSwitchStyle(accent:accent))
                                .transition(reduceMotion || motionLevel == .off ? .opacity:.opacity.combined(with:.scale(scale:0.97,anchor:.center)))
                                .position(x:geometry.size.width/2,y:geometry.size.height/2)
                        }.frame(maxWidth:.infinity,maxHeight:.infinity)
                    }
                    .onExitCommand { isPresented = false }
                    .onReceive(NotificationCenter.default.publisher(for:NSApplication.didResignActiveNotification)) { _ in isPresented = false }
                }
            }
            .animation(reduceMotion || motionLevel == .off ? nil:SurfaceMotion.popover,value:isPresented)
    }
}
extension View {
    @ViewBuilder func lumaPanel<Panel: View>(isPresented: Binding<Bool>,size: CGSize,paper: Color,accent: Color,fromGear:Bool = false,@ViewBuilder content: @escaping () -> Panel) -> some View {
        if fromGear { modifier(GearSettingsSurface(shown:isPresented,size:size,paper:paper,accent:accent,panel:content)) }
        else { modifier(LumaDismissiblePanel(isPresented:isPresented,size:size,paper:paper,accent:accent,panel:content)) }
    }
}

/// The label, whitespace and track are one target, with no native fixed-blue switch.
struct LumaThemeSwitchStyle: ToggleStyle {
    var accent: Color
    @Environment(\.lumaInk) private var ink
    @Environment(\.lumaGlass) private var glass
    @Environment(\.isEnabled) private var enabled
    @Environment(\.lumaMotionLevel) private var motionLevel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing:12) {
                configuration.label.frame(maxWidth:.infinity,alignment:.leading)
                Capsule().fill(configuration.isOn ? accent:ink.opacity(0.22))
                    .overlay {
                        if glass {
                            Capsule().fill(LinearGradient(colors:[.white.opacity(0.22),.clear,accent.opacity(0.12)],startPoint:.top,endPoint:.bottom))
                                .overlay(Capsule().strokeBorder(accent.opacity(0.25),lineWidth:0.7))
                        }
                    }
                    .overlay(alignment:configuration.isOn ? .trailing:.leading) {
                        Circle().fill(configuration.isOn ? accent.lumaContrastingInk:ink.opacity(0.8))
                            .frame(width:18,height:18).padding(3)
                    }.frame(width:40,height:24)
                    .accessibilityHidden(true)
            }.frame(maxWidth:.infinity,minHeight:36).contentShape(Rectangle())
        }.buttonStyle(.plain).opacity(enabled ? 1:0.45)
            .accessibilityValue(L10n.text(configuration.isOn ? "开启":"关闭"))
            .animation(reduceMotion || motionLevel == .off ? nil:.easeOut(duration:0.14),value:configuration.isOn)
    }
}
extension Color {
    var lumaContrastingInk: Color {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return .white }
        func channel(_ c: CGFloat) -> Double {
            let value = Double(c)
            return value <= 0.04045 ? value/12.92:pow((value+0.055)/1.055,2.4)
        }
        let y = 0.2126*channel(rgb.redComponent)+0.7152*channel(rgb.greenComponent)+0.0722*channel(rgb.blueComponent)
        return y > 0.179 ? Color(hex:"171717"):.white
    }
}
