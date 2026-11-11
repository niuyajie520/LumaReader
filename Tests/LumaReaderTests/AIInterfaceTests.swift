import Foundation
import Testing
@testable import LumaReader

struct AIInterfaceTests {
    @Test func quotePreviewKeepsBeginningEndAndWholeGraphemes() {
        let value = "这是完全虚构的测试段落，只用于检查引用预览与文本选择，不对应任何真实图书、私人笔记或聊天记录。"
        let preview = AIQuotePreview.compact(value)
        #expect(preview == String(value.prefix(12))+"…"+String(value.suffix(12)))
        #expect(AIQuotePreview.compact("  简短\n 句子 ") == "简短 句子")
        let family = "👩‍👩‍👧‍👦"
        #expect(AIQuotePreview.compact(String(repeating:family,count:30)) == String(repeating:family,count:12)+"…"+String(repeating:family,count:12))
    }
    @Test func initialDarkDocumentHasThemeBeforeBodyAndPreservesCSP() {
        let source = "<html><head><meta content=\"style-src 'self'; connect-src 'none'\"></head><body>Reading</body></html>"
        let html = AIWebDocument.themed(source,paper:"#000000",ink:"#EEEEEE",accent:"#AAAAAA",dark:true)
        #expect(html.contains("--paper:#000000")); #expect(html.contains("color-scheme:dark"))
        #expect(html.contains("connect-src 'none'")); #expect(html.contains("style-src 'self' 'nonce-"))
        #expect(html.range(of:"--paper:")!.lowerBound < html.range(of:"<body>")!.lowerBound)
    }
    @Test func initialDocumentRejectsCSSInjectionAndSupportsLightTheme() {
        let html = AIWebDocument.themed("<html><head></head><body></body></html>",paper:"</style><script>bad</script>",ink:"no",accent:"bad",dark:false)
        #expect(!html.contains("<script>")); #expect(html.contains("--paper:#FAF8F3")); #expect(html.contains("color-scheme:light"))
    }
    @Test func bundledAIHasValidStylesAndNoExternalRuntimeAssets() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/LumaReader/Resources")
        func resource(_ name:String) throws -> String { try String(contentsOf:root.appendingPathComponent(name),encoding:.utf8) }
        let css = try resource("AIChat.css")
        #expect(!css.contains("import SwiftUI")); #expect(css.contains(".symbols{display:none}"))
        let html = try AIWebDocument.assembled(resource("AIChat.html"),css:css,script:resource("AIChat.js"),strings:resource("AppStrings.js"),paper:"#161c19",ink:"#eeeeee",accent:"#81a58a",dark:true)
        #expect(!html.contains("src=\"AIChat.js\"")); #expect(!html.contains("href=\"AIChat.css\""))
        #expect(html.contains("window.LumaAI=")); #expect(html.contains("window.LumaStrings="))
        #expect(html.contains("--paper:#161c19")); #expect(!html.contains("'unsafe-inline'"))
        let expression = try NSRegularExpression(pattern:"nonce=\"([^\"]+)\"")
        let matches = expression.matches(in:html,range:NSRange(html.startIndex...,in:html))
        let nonces = Set(matches.compactMap { Range($0.range(at:1),in:html).map { String(html[$0]) } })
        #expect(nonces.count == 1)
    }
}
