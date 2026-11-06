import SwiftUI

struct GearAnchorPreference: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value:inout Anchor<CGRect>?,nextValue:()->Anchor<CGRect>?) { value = nextValue() ?? value }
}
struct GearSettingsSurface<Panel:View>: ViewModifier {
    @Binding var shown:Bool
    let size:CGSize
    let paper:Color
    let accent:Color
    let panel:()->Panel
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.lumaMotionLevel) private var level
    @Environment(\.lumaGlass) private var glass
    func body(content:Content)->some View {
        content.disabled(shown).accessibilityHidden(shown)
            .overlayPreferenceValue(GearAnchorPreference.self) { anchor in
                GeometryReader { proxy in
                    let width = min(size.width,max(280,proxy.size.width-32))
                    let height = min(size.height,max(320,proxy.size.height-32))
                    let gear = anchor.map { proxy[$0] } ?? CGRect(x:max(0,proxy.size.width-80),y:16,width:44,height:44)
                    let motion = reduced || level == .off ? nil:(shown ? MotionTokens.settingsOpening:MotionTokens.settingsClosing)
                    ZStack {
                        Color.black.opacity(shown ? 0.18:0).contentShape(Rectangle())
                            .onTapGesture { shown = false }
                        panel()
                            .environment(\.lumaSurfacePolish,true)
                            .frame(width:width,height:height)
                            .opacity(shown ? 1:0)
                            .animation(reduced || level == .off ? nil:.easeOut(duration:0.12),value:shown)
                            .frame(width:reduced || level == .off || shown ? width:gear.width,
                                   height:reduced || level == .off || shown ? height:gear.height)
                            .clipped()
                            .readerGlass(radius:18,enabled:glass,tint:paper)
                            .clipShape(RoundedRectangle(cornerRadius:18,style:.continuous))
                            .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(accent.opacity(0.20)))
                            .position(x:reduced || level == .off || shown ? proxy.size.width/2:gear.midX,
                                      y:reduced || level == .off || shown ? proxy.size.height/2:gear.midY)
                            .opacity(shown ? 1:0)
                            .animation(motion,value:shown)
                            .disabled(!shown).accessibilityHidden(!shown)
                    }.allowsHitTesting(shown)
                        .onExitCommand { if shown { shown = false } }
                }
            }
    }
}
