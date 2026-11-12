import Testing
@testable import LumaReader

/// 1.8.0 主题重设计：每个主题拥有自己的布局档案，并新增废土终端主题。
struct ThemeLayoutTests {
    @Test func wastelandPalettesAreValidAndPhosphorPresetsStayDark() {
        for preset in WastelandTerminalPreset.allCases {
            for dark in [false, true] {
                let p = WastelandThemePaletteGenerator.makePalette(preset: preset, dark: dark)
                for hex in [p.paperHex, p.inkHex, p.mutedHex, p.accentHex, p.chromeHex, p.outlineHex] {
                    #expect(LumaThemeValidation.hex(hex) != nil)
                }
            }
        }
        #expect(WastelandTerminalPreset.phosphorGreen.forcesDark)
        #expect(WastelandTerminalPreset.amberTerminal.forcesDark)
        #expect(!WastelandTerminalPreset.bunkerDaylight.forcesDark)
        #expect(WastelandThemePaletteGenerator.makePalette(preset: .phosphorGreen, dark: false).accentHex == "1BFF80")
    }

    @Test func nierOvergrownCityIsGreen() {
        let p = NierThemePaletteGenerator.makePalette(preset: .overgrownCity, dark: false)
        #expect(p.accentHex == "5E6F45")
        #expect(NierYorhaPreset.allCases.first == .overgrownCity)
    }

    @Test func everyThemeHasALayoutAndLayoutsAreNotAllTheSame() {
        var signatures = Set<String>()
        for system in LumaVisualThemeSystem.allCases where system != .monet {
            let l = LumaThemeLayout.resolve(system: system, classic: .paper, monetEnabled: false)
            signatures.insert("\(l.sidebarOnTrailing)|\(l.readerHeader)|\(l.libraryHeader)|\(l.ornament)")
        }
        for classic in ReaderTheme.allCases {
            let l = LumaThemeLayout.resolve(system: .monet, classic: classic, monetEnabled: false)
            signatures.insert("\(l.sidebarOnTrailing)|\(l.readerHeader)|\(l.libraryHeader)|\(l.ornament)")
        }
        // 14 independent worlds + 5 classic palettes; every combination should be distinct.
        #expect(signatures.count == 19)
    }

    @Test func galleryCountsMatchCases() {
        #expect(LumaVisualThemeSystem.allCases.count == 15)
        #expect(LumaVisualThemeSystem.allCases.filter { ThemeGalleryCategory.gameLegends.includes($0) }.count == 3)
    }
}
