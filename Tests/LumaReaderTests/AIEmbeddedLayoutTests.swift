import AppKit
import WebKit
import Testing
@testable import LumaReader

@MainActor private final class AIWebFixture: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let web: WKWebView
    let window: NSWindow
    var actions: [String] = []
    private var navigation: CheckedContinuation<Void,Error>?
    private var deadline: Task<Void,Never>?
    override init() {
        _ = NSApplication.shared
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame:NSRect(x:0,y:0,width:340,height:720),configuration:config)
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:340,height:720),styleMask:[.titled],backing:.buffered,defer:false)
        super.init()
        window.isReleasedWhenClosed = false
        window.contentView = web
        web.navigationDelegate = self
        web.configuration.userContentController.add(self,name:"lumaAI")
        window.orderFront(nil)
    }
    func load() async throws {
        func resource(_ name:String,_ ext:String) throws -> String {
            let url = try #require(AppResources.url(forResource:name,withExtension:ext))
            return try String(contentsOf:url,encoding:.utf8)
        }
        let html = try AIWebDocument.assembled(resource("AIChat","html"),css:resource("AIChat","css"),script:resource("AIChat","js"),strings:resource("AppStrings","js"),paper:"#1d231e",ink:"#eeeeee",accent:"#88ad95",dark:true)
        try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
            navigation = continuation
            web.loadHTMLString(html,baseURL:nil)
            deadline = Task { @MainActor [weak self] in
                do { try await Task.sleep(for:.seconds(20)) } catch { return }
                self?.finish(CocoaError(.fileReadUnknown))
            }
        }
    }
    private func finish(_ error:Error? = nil) {
        guard let continuation = navigation else { return }
        navigation = nil; deadline?.cancel(); deadline = nil
        if let error { continuation.resume(throwing:error) } else { continuation.resume() }
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) { finish() }
    func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error) { finish(CocoaError(.fileReadUnknown)) }
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error) { finish(CocoaError(.fileReadUnknown)) }
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
        if let value = message.body as? [String:Any], let action = value["action"] as? String { actions.append(action) }
    }
    func js(_ source:String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            web.evaluateJavaScript(source) { value,error in
                if error != nil { continuation.resume(throwing:CocoaError(.fileReadCorruptFile)) }
                else { continuation.resume(returning:value as? String ?? "") }
            }
        }
    }
    func receive(_ state:[String:Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject:state,options:.sortedKeys)
        _ = try await js("window.LumaAI.receive("+String(decoding:data,as:UTF8.self)+");'ok'")
    }
    func close() {
        deadline?.cancel(); web.stopLoading(); web.navigationDelegate = nil
        web.configuration.userContentController.removeScriptMessageHandler(forName:"lumaAI")
        window.close()
    }
    static func state() -> [String:Any] {
        ["provider":"deepseek","providers":[["id":"deepseek","title":"DeepSeek"]],"model":"fixture-model",
         "draft":"","messages":[] as [[String:String]],"includeReading":false,"pendingQuote":"","pendingImageName":"","isSending":false,
         "dark":true,"error":"","context":NSNull(),"language":"en","composerHeight":0,"glassEnabled":true,"glassOpacity":0.32,
         "reduceVisualEffects":true,"softMotion":true,"conversationID":"fixture-active","history":[] as [[String:String]],
         "colors":["paper":"#1d231e","ink":"#eeeeee","accent":"#88ad95","surface":"#263129","line":"#354137","muted":"#a0ada4"]]
    }
}

@MainActor @Suite(.serialized) struct AIEmbeddedLayoutTests {
    @Test func actualWebKitComposerIsCompactBoundedAndKeepsComposition() async throws {
        let fixture = AIWebFixture(); defer { fixture.close() }
        try await fixture.load(); try await fixture.receive(AIWebFixture.state())
        let compact = try await fixture.js("JSON.stringify([document.getElementById('draft').clientHeight,document.querySelector('.composer').getBoundingClientRect().height,document.body.scrollWidth<=document.documentElement.clientWidth,getComputedStyle(document.querySelector('header')).backgroundColor===getComputedStyle(document.body).backgroundColor])")
        let values = try #require(JSONSerialization.jsonObject(with:Data(compact.utf8)) as? [Any])
        #expect((values[0] as? Int ?? 999) <= 30)
        #expect((values[1] as? Double ?? 999) <= 60)
        #expect(values[2] as? Bool == true)
        #expect(values[3] as? Bool == true)
        let grown = try await fixture.js("var d=document.getElementById('draft');window.fixtureDraft=d;d.value=Array(12).fill('synthetic line').join('\\n');d.dispatchEvent(new Event('input',{bubbles:true}));String(d.clientHeight)")
        #expect(Int(grown) == 120)
        let shrunk = try await fixture.js("var d=document.getElementById('draft');d.value='';d.dispatchEvent(new Event('input',{bubbles:true}));String(d.clientHeight)")
        #expect(Int(shrunk) == 24)
        _ = try await fixture.js("var d=document.getElementById('draft');d.focus();d.dispatchEvent(new CompositionEvent('compositionstart'));d.value='拼';'ok'")
        try await fixture.receive(AIWebFixture.state())
        #expect(try await fixture.js("document.getElementById('draft').value") == "拼")
        #expect(try await fixture.js("String(window.fixtureDraft===document.getElementById('draft'))") == "true")
        _ = try await fixture.js("document.getElementById('draft').dispatchEvent(new CompositionEvent('compositionend'));'ok'")
    }
    @Test func historyPopoverUsesNativeBridgeAndOutsideClickDoesNotBlockInput() async throws {
        let fixture = AIWebFixture(); defer { fixture.close() }
        try await fixture.load()
        var state = AIWebFixture.state()
        state["history"] = [["id":"fixture-history","title":"Synthetic prior question","date":"11/06"]]
        try await fixture.receive(state)
        _ = try await fixture.js("document.getElementById('history').click();'ok'")
        #expect(try await fixture.js("String(!document.getElementById('history-panel').hidden)") == "true")
        _ = try await fixture.js("document.querySelector('.history-row').click();'ok'")
        try await Task.sleep(for:.milliseconds(50))
        #expect(fixture.actions.contains("conversation"))
        _ = try await fixture.js("document.getElementById('history').click();document.getElementById('new').click();'ok'")
        try await Task.sleep(for:.milliseconds(50))
        #expect(fixture.actions.contains("new"))
        _ = try await fixture.js("document.getElementById('history').click();var d=document.getElementById('draft');window.fixtureClick=new PointerEvent('pointerdown',{bubbles:true,cancelable:true});d.dispatchEvent(window.fixtureClick);d.focus();'ok'")
        #expect(try await fixture.js("String(document.getElementById('history-panel').hidden&&!window.fixtureClick.defaultPrevented&&document.activeElement===document.getElementById('draft'))") == "true")
    }
}
