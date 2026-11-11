import Foundation
import Testing
@testable import LumaReader

struct MonetThemeTests {
    private func luminance(_ hex: String) -> Double {
        let n = Int(hex,radix:16) ?? 0
        func linear(_ component: Int) -> Double {
            let value = Double(component)/255
            return value <= 0.04045 ? value/12.92:pow((value+0.055)/1.055,2.4)
        }
        return 0.2126*linear((n>>16)&255)+0.7152*linear((n>>8)&255)+0.0722*linear(n&255)
    }
    @Test(arguments:[0xFF000000,0xFFFFFFFF,0xFFFF0000,0xFF00FF00,0xFF0000FF,0xFF8C7862])
    func semanticRolesRemainReadable(seed: Int) {
        for style in MonetStyle.allCases {
            let pair = MonetPalettePair.make(seed:seed,style:style)
            for p in [pair.light,pair.dark] {
                let a = luminance(p.paperHex), b = luminance(p.inkHex)
                #expect((max(a,b)+0.05)/(min(a,b)+0.05) >= 4.5)
                #expect(p.webColors["paper"] == "#"+p.paperHex)
                #expect(p.webColors["ink"] == "#"+p.inkHex)
                #expect(p.webColors["accent"] == "#"+p.accentHex)
            }
        }
    }
    @Test func seedChangesProduceDifferentSchemes() {
        let a = MonetPalettePair.make(seed:0xFF2462A8,style:.tonalSpot)
        let b = MonetPalettePair.make(seed:0xFF9B392A,style:.tonalSpot)
        #expect(a != b)
        #expect(a.light != a.dark)
    }
    @Test func concurrentPaletteRequestsMatchSerialResults() async {
        let seeds = [0xFF000000,0xFFFFFFFF,0xFFFF0000,0xFF00FF00,0xFF0000FF,0xFF8C7862]
        let count = seeds.count * MonetStyle.allCases.count
        let expected = (0..<count).map { index in
            MonetPalettePair.make(seed:seeds[index % seeds.count],style:MonetStyle.allCases[index / seeds.count])
        }
        await withTaskGroup(of:Bool.self) { group in
            for job in 0..<(count * 4) {
                group.addTask {
                    let index = job % count
                    let actual = MonetPalettePair.make(seed:seeds[index % seeds.count],style:MonetStyle.allCases[index / seeds.count])
                    return actual == expected[index]
                }
            }
            for await matches in group { #expect(matches) }
        }
    }

}
