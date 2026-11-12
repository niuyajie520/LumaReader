import Testing
import SwiftUI
@testable import LumaReaderStudyKit

/// 1.8.0 主题主视觉：路径数据可解析、每个主题都有场景。
struct HeroSceneTests {
    @Test func everyHeroSceneParsesToNonEmptyPaths() {
        #expect(HeroScenes.sources.count == 14)
        for (key, shapes) in HeroScenes.parsed {
            #expect(shapes.count > 10, "\(key) should have a substantial scene")
            #expect(shapes.contains { !$0.path.isEmpty })
        }
    }
    @Test func pathParserHandlesCommands() {
        let p = HeroScenes.parsePath("M0 0 L10 0 Q15 5 10 10 C5 15 0 15 0 10 Z")
        #expect(!p.isEmpty)
        let box = p.boundingRect
        #expect(box.maxX >= 10 && box.maxY >= 10)
    }

    @Test func clipMarkersAreBalanced() {
        // clip balance: 每个开始裁剪(1)后必须有结束裁剪(2)
        for (key, shapes) in HeroScenes.sources {
            let begins = shapes.filter { $0.clip == 1 }.count
            let ends = shapes.filter { $0.clip == 2 }.count
            #expect(begins == ends, "\(key) clip markers unbalanced")
        }
    }

    @Test func heroImageSettingsDefaultsAndRoundTrip() throws {
        let d = HeroImageSettings()
        #expect(d.file == nil && d.opacity == 0.55 && d.scale == 1.0 && d.veil == 0)
        var s = d; s.file = "a.png"; s.opacity = 0.3; s.fill = true
        let back = try JSONDecoder().decode(HeroImageSettings.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}
