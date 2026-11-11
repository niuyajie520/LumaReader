import SwiftUI
import AppKit

/// Finder uses the bundled ICNS; this preference updates the running app's Dock icon.
struct LumaAppIconAppearance: ViewModifier {
    @AppStorage("appIconStyle") private var style = "glass"
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.onAppear { apply() }
            .onChange(of:style) { _,_ in apply() }
            .onChange(of:colorScheme) { _,_ in apply() }
    }
    @MainActor private func apply() {
        let selected = style == "system" ? (colorScheme == .dark ? "Dark":"Light"):
            (style == "light" ? "Light":style == "dark" ? "Dark":"Glass")
        guard let url = Bundle.main.url(forResource:"LumaReader-"+selected,withExtension:"png"),
              let image = NSImage(contentsOf:url) else { return }
        NSApplication.shared.applicationIconImage = image
    }
}
