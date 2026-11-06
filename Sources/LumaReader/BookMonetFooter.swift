import SwiftUI

struct BookMonetFooter: ViewModifier {
    let book:Book
    let root:URL
    @State private var palette:MonetPalettePair?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lumaGlass) private var glass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content:Content)->some View {
        let roles = scheme == .dark ? palette?.dark:palette?.light
        content
            .background((roles?.paper ?? Color(nsColor:.windowBackgroundColor)).opacity(reduceTransparency || !glass ? 1:0.82),in:RoundedRectangle(cornerRadius:12))
            .monetLiquidGlass(tint:roles?.accent ?? Color.accentColor,cornerRadius:12)
            .foregroundStyle(roles?.ink ?? Color.primary)
            .task(id:book.coverFilename) {
                guard let filename = book.coverFilename else { palette = nil; return }
                let url = root.appendingPathComponent("Covers").appendingPathComponent(filename)
                guard let seed = await CoverColorExtractor.shared.seed(from:url,cacheURL:root.appendingPathComponent("cover-monet-cache.json")),!Task.isCancelled else { return }
                let generated = await Task.detached(priority:.utility) { MonetPalettePair.make(seed:seed,style:.tonalSpot) }.value
                guard !Task.isCancelled else { return }; palette = generated
            }
    }
}
