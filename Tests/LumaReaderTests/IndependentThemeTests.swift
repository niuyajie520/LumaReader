import Testing
@testable import LumaReader

struct IndependentThemeTests {
    @Test func malformedColorsDoNotReachPaletteRoles() {
        for value in ["GGGGGG", "#123", "1234567", "１２３４５６", "12345Z", "##123456"] {
            #expect(LumaThemeValidation.hex(value) == nil)
            let palette = SpaceThemePaletteGenerator.makePalette(preset:.customCosmic,customHex:value)
            #expect(palette.accentHex == SpaceCosmicPreset.nebulaViolet.accentHex)
        }
        #expect(LumaThemeValidation.hex("  #a78bfa  ") == "A78BFA")
    }
    @Test func nonFiniteAndOutOfRangePreferencesStayBounded() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            #expect(LumaThemeValidation.clamp(value,0.35...0.95,fallback:0.76) == 0.76)
        }
        #expect(LumaThemeValidation.clamp(-4,0.35...0.95,fallback:0.76) == 0.35)
        #expect(LumaThemeValidation.clamp(2,0.35...0.95,fallback:0.76) == 0.95)
    }
    @Test func mangaRolesStayMonochromeAndDoNotInheritCosmicAccents() {
        let allowed: Set<String> = ["FFFFFF","0A0A0A","F5F5F5","777777","D7D7D7"]
        for white in [true,false] {
            let palette = MangaThemePaletteGenerator.makePalette(pureWhitePaper:white)
            #expect(Set(palette.webColors.values.map { String($0.dropFirst()) }).isSubset(of:allowed))
        }
    }
    @Test func cosmicPresetsRetainDarkCanvas() {
        for preset in SpaceCosmicPreset.allCases {
            let palette = SpaceThemePaletteGenerator.makePalette(preset:preset,customHex:"C6CAD9")
            #expect(palette.paperHex == "080B17")
            #expect(palette.inkHex == "EEF1FA")
            #expect(palette.chromeHex == "111629")
        }
    }
    @Test func freshMangaAndGameThemesProduceDistinctValidHexPalettes() {
        let ocean = MangaOceanThemePaletteGenerator.makePalette(preset: .kamakuraCoast, dark: false)
        let city = MangaCityThemePaletteGenerator.makePalette(preset: .shibuyaSunset, dark: true)
        let forest = MangaForestThemePaletteGenerator.makePalette(preset: .komorebiCanopy, dark: false)
        let nier = NierThemePaletteGenerator.makePalette(preset: .yorhaBunker, dark: false)
        let zelda = ZeldaThemePaletteGenerator.makePalette(preset: .sheikahSlate, dark: true)

        for pal in [ocean, city, forest, nier, zelda] {
            #expect(LumaThemeValidation.hex(pal.paperHex) != nil)
            #expect(LumaThemeValidation.hex(pal.inkHex) != nil)
            #expect(LumaThemeValidation.hex(pal.accentHex) != nil)
            #expect(LumaThemeValidation.hex(pal.chromeHex) != nil)
        }
        #expect(nier.paperHex == "DAD4BB")
        #expect(nier.inkHex == "454138")
        #expect(zelda.accentHex == "3CD3FC")
        #expect(zelda.paperHex == "0A1428")
        #expect(Set([ocean.accentHex, city.accentHex, forest.accentHex, nier.accentHex, zelda.accentHex]).count == 5)
    }
}
