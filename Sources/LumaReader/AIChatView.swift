import SwiftUI
import AppKit
import WebKit

struct AIChatView: View {
    @Bindable var store: LibraryStore
    var onCollapse:()->Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAPI = false
    @State private var webFailure: String?
    @State private var retryRevision = 0
    @State private var initializing = true
    var body: some View {
        AIChatWebView(store:store,state:webState,dark:colorScheme == .dark,openSettings:{ showAPI = true },onCollapse:onCollapse,onFailure:{ webFailure = $0; initializing = false },retryRevision:retryRevision)
            .frame(minWidth:340,minHeight:280)
            .background(store.paper(dark:colorScheme == .dark))
            .overlay {
                if let webFailure {
                    VStack(spacing:12) {
                        Text(L10n.text(webFailure)).font(.callout).multilineTextAlignment(.center)
                        Button(L10n.text("恢复 AI 界面")) { self.webFailure = nil; initializing = true; retryRevision += 1 }
                    }.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity).background(store.paper(dark:colorScheme == .dark))
                } else if initializing {
                    store.paper(dark:colorScheme == .dark).overlay { ProgressView().controlSize(.small) }
                }
            }
            .popover(isPresented:$showAPI,arrowEdge:.top) { AISettingsPanel(ai:store.ai,paper:store.paper(dark:colorScheme == .dark),accent:store.accent) }
    }
    private var webState:[String:Any] {
        let ai = store.ai
        let dark = colorScheme == .dark
        _ = ai.settingsRevision
        let providers = AIProvider.allCases.map { ["id":$0.rawValue,"title":$0.title] }
        let messages = ai.messages.map { ["role":$0.role,"text":$0.text,"providerTitle":$0.providerTitle ?? "阅读助手","imageName":$0.image?.filename ?? ""] }
        let colors = store.readingPalette(dark:dark).webColors
        var state:[String:Any] = [
            "provider":ai.provider.rawValue, "providers":providers, "model":ai.effectiveModel,
            "draft":ai.draft, "messages":messages, "includeReading":ai.includeReading,
            "pendingQuote":ai.pendingQuote, "pendingImageName":ai.pendingImage?.filename ?? "", "isSending":ai.isSending, "dark":dark,
            "error":ai.error ?? "", "colors":colors,
            "reduceVisualEffects":store.effectiveMotionLevel == .off,
            "softMotion":store.effectiveMotionLevel == .balanced,
            "glassEnabled":store.effectiveGlassEffectsEnabled,
            "diagnosticsEnabled":DiagnosticManager.shared.automaticDetection,"language":L10n.code,"composerHeight":UserDefaults.standard.double(forKey:"aiComposerHeight"),"glassOpacity":store.glassOpacity,"pinned":store.aiPanelPinned,"expanded":store.aiPanelExpanded
        ]
        if let reading = ai.context { state["context"] = ["title":reading.title,"chapter":reading.chapter] }
        else { state["context"] = NSNull() }
        return state
    }

}

private struct AIChatWebView: NSViewRepresentable {
    var store:LibraryStore
    var state:[String:Any]
    var dark:Bool
    var openSettings:()->Void
    var onCollapse:()->Void
    var onFailure:(String?)->Void
    var retryRevision:Int
    func makeCoordinator() -> Coordinator { Coordinator(store:store,openSettings:openSettings,onCollapse:onCollapse,onFailure:onFailure) }
    func makeNSView(context:Context) -> WKWebView {
        DiagnosticManager.shared.begin(.aiBoot)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator,name:"lumaAI")
        let web = WKWebView(frame:.zero,configuration:configuration)
        web.navigationDelegate = context.coordinator; web.underPageBackgroundColor = NSColor(store.paper(dark:dark))
        web.appearance = NSAppearance(named:dark ? .darkAqua:.aqua)
        context.coordinator.web = web
        DiagnosticManager.shared.aiHealthCheck = { [weak coordinator = context.coordinator] in coordinator?.checkHealth(showFailure:false) }
        context.coordinator.update(state)
        do {
            guard let url = AppResources.url(forResource:"AIChat",withExtension:"html") else { throw ReaderFailure.message("AI 界面文件缺失。") }
            let directory = store.root.appendingPathComponent("Cache/AIInterface",isDirectory:true)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let colors = state["colors"] as? [String:String] ?? [:]
            let source = try String(contentsOf:url,encoding:.utf8)
            let resource = url.deletingLastPathComponent()
            let html = try AIWebDocument.assembled(source,css:String(contentsOf:resource.appendingPathComponent("AIChat.css"),encoding:.utf8),script:String(contentsOf:resource.appendingPathComponent("AIChat.js"),encoding:.utf8),strings:String(contentsOf:resource.appendingPathComponent("AppStrings.js"),encoding:.utf8),paper:colors["paper"] ?? "",ink:colors["ink"] ?? "",accent:colors["accent"] ?? "",dark:dark)
            let document = directory.appendingPathComponent("AIChat-"+UUID().uuidString+".html")
            try Data(html.utf8).write(to:document,options:.atomic)
            context.coordinator.documentURL = document
            context.coordinator.navigation = web.loadFileURL(document,allowingReadAccessTo:directory)
        } catch { DiagnosticManager.shared.record(.aiBootFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)]); DiagnosticManager.shared.cancel(.aiBoot); DispatchQueue.main.async { onFailure("AI 界面加载失败："+error.localizedDescription) } }
        return web
    }
    func updateNSView(_ web:WKWebView,context:Context) {
        context.coordinator.openSettings = openSettings
        context.coordinator.onCollapse = onCollapse
        context.coordinator.onFailure = onFailure
        if context.coordinator.retryRevision != retryRevision {
            context.coordinator.retryRevision = retryRevision; context.coordinator.generation = UUID(); context.coordinator.ready = false; DiagnosticManager.shared.cancel(.aiBoot); DiagnosticManager.shared.begin(.aiBoot)
            if let document = context.coordinator.documentURL { context.coordinator.navigation = web.loadFileURL(document,allowingReadAccessTo:document.deletingLastPathComponent()) }
            else { DispatchQueue.main.async { onFailure("AI 界面资源不完整，请重新安装完整程序。") } }
        }
        context.coordinator.update(state)
        let paper = NSColor(store.paper(dark:dark))
        if web.underPageBackgroundColor != paper { web.underPageBackgroundColor = paper }
        let appearance:NSAppearance.Name = dark ? .darkAqua:.aqua
        if web.appearance?.name != appearance { web.appearance = NSAppearance(named:appearance) }
    }
    static func dismantleNSView(_ web:WKWebView,coordinator:Coordinator) {
        DiagnosticManager.shared.aiHealthCheck = nil
        DiagnosticManager.shared.cancel(.aiBoot)
        web.configuration.userContentController.removeScriptMessageHandler(forName:"lumaAI")
        web.navigationDelegate = nil; web.stopLoading()
        if let document = coordinator.documentURL { try? FileManager.default.removeItem(at:document) }
    }
    @MainActor final class Coordinator:NSObject,WKScriptMessageHandler,WKNavigationDelegate {
        let store:LibraryStore
        var openSettings:()->Void
        var onCollapse:()->Void
        weak var web:WKWebView?
        var navigation:WKNavigation?
        var generation = UUID()
        var documentURL:URL?
        var onFailure:(String?)->Void
        var retryRevision = 0
        var ready = false
        private var state:[String:Any] = [:]
        private var lastData:Data?
        init(store:LibraryStore,openSettings:@escaping ()->Void,onCollapse:@escaping ()->Void,onFailure:@escaping (String?)->Void) { self.store = store; self.openSettings = openSettings; self.onCollapse = onCollapse; self.onFailure = onFailure }
        func update(_ value:[String:Any]) {
            state = value
            guard ready, let data = try? JSONSerialization.data(withJSONObject:value,options:.sortedKeys), data != lastData else { return }
            lastData = data
            let generation = generation
            web?.callAsyncJavaScript("window.LumaAI.receive(state)",arguments:["state":value],in:nil,in:.page) { [weak self] result in
                guard let self, self.generation == generation else { return }
                if case .failure = result { DiagnosticManager.shared.record(.aiScriptFailed,isError:true); self.lastData = nil; self.onFailure("AI 界面未能初始化，请恢复界面后重试。") }
            }
        }
        func checkHealth(showFailure:Bool) {
            guard let web, let url = AppResources.url(forResource:"AIHealth",withExtension:"js"), let script = try? String(contentsOf:url,encoding:.utf8) else {
                DiagnosticManager.shared.record(.aiHealthFailed,isError:true)
                if showFailure { onFailure("AI 界面资源不完整，请重新安装完整程序。") }; return
            }
            let generation = generation
            web.evaluateJavaScript(script) { [weak self] value,error in
                guard let self, self.generation == generation else { return }
                let raw = value as? [String:Any] ?? [:]
                var fields:[DiagnosticField:Double] = [:]
                for (key,value) in raw {
                    guard let field = DiagnosticField(rawValue:key), let number = value as? NSNumber else { continue }
                    fields[field] = number.doubleValue
                }
                if error != nil { fields[.bridgeReady] = 0 }
                let healthy = DiagnosticManager.shared.receiveAIHealth(fields)
                guard showFailure else { return }
                guard healthy else {
                    DiagnosticManager.shared.cancel(.aiBoot); self.ready = false
                    self.onFailure("AI 界面资源加载失败，请恢复界面或重新安装。"); return
                }
                self.ready = true; self.lastData = nil; DiagnosticManager.shared.finish(.aiBoot); self.onFailure(nil); self.update(self.state)
            }
        }
        func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
            guard navigation === self.navigation else { return }; checkHealth(showFailure:true)
        }
        private func navigationFailed(_ navigation:WKNavigation?,error:Error) {
            guard navigation === self.navigation, (error as NSError).code != NSURLErrorCancelled else { return }
            DiagnosticManager.shared.record(.aiNavigationFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)])
            DiagnosticManager.shared.cancel(.aiBoot); ready = false; onFailure("AI 界面加载失败："+error.localizedDescription)
        }
        func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error) { navigationFailed(navigation,error:error) }
        func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error) { navigationFailed(navigation,error:error) }
        func webViewWebContentProcessDidTerminate(_ webView:WKWebView) { DiagnosticManager.shared.record(.aiProcessTerminated,isError:true); DiagnosticManager.shared.cancel(.aiBoot); generation = UUID(); ready = false; lastData = nil; onFailure("AI 界面进程已停止。对话仍保留，可恢复界面。") }
        func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping (WKNavigationActionPolicy)->Void) {
            decisionHandler(navigationAction.targetFrame?.isMainFrame == true && navigationAction.request.url == documentURL ? .allow:.cancel)
        }
        func userContentController(_ controller:WKUserContentController,didReceive message:WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.frameInfo.request.url == documentURL,
                  let body = message.body as? [String:Any], let action = body["action"] as? String else { return }
            let ai = store.ai
            switch action {
            case "diagnostic":
                guard ["script","promise","csp"].contains(body["kind"] as? String ?? "") else { return }
                DiagnosticManager.shared.record(body["kind"] as? String == "csp" ? .aiContentPolicyFailed:body["kind"] as? String == "promise" ? .aiPromiseFailed:.aiScriptFailed,isError:true)
            case "ready": break // didFinish validates DOM/CSS before marking ready
            case "collapse": onCollapse()
            case "composerHeight":
                if let value = body["value"] as? Double,value.isFinite { UserDefaults.standard.set(value == 0 ? 0:min(360,max(66,value)),forKey:"aiComposerHeight") }
            case "pin": store.aiPanelPinned.toggle()
            case "expand": store.aiPanelExpanded.toggle()
            case "stop": ai.cancel()
            case "draft": if !ai.isSending { ai.draft = String((body["value"] as? String ?? "").prefix(12000)) }
            case "provider": if let provider = AIProvider(rawValue:body["value"] as? String ?? "") { ai.selectProvider(provider) }
            case "include": if !ai.isSending { ai.includeReading = body["value"] as? Bool ?? false }
            case "new": if !ai.isSending { ai.clearConversation() }
            case "removeImage": if !ai.isSending { ai.clearImage() }
            case "removeQuote": if !ai.isSending { ai.clearQuote() }
            case "settings": if !ai.isSending { openSettings() }
            case "send":
                guard !ai.isSending else { return }
                ai.draft = String((body["value"] as? String ?? ai.draft).prefix(12000))
                ai.sendUsingContext { [weak self] done in self?.store.captureAIContext(done) }
            default: break
            }
        }
    }
}

struct AISettingsPanel:View {
    @Bindable var ai:AIChatStore
    var paper:Color = Color(nsColor:.windowBackgroundColor)
    var accent:Color = .accentColor
    @Environment(\.lumaGlass) private var glass
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(spacing:0) {
            HStack { Text(L10n.text("设置 API")).font(.headline); Spacer(); Button(L10n.text("完成")) { dismiss() }.buttonStyle(LumaTactileButtonStyle(prominent:true,accent:accent)).keyboardShortcut(.defaultAction) }.padding(20)
            Form { AIAPISettings(ai:ai) }.formStyle(.grouped).scrollContentBackground(.hidden)
        }.frame(width:510,height:520).readerGlass(radius:16,enabled:glass,tint:paper).tint(accent).accentColor(accent).toggleStyle(LumaThemeSwitchStyle(accent:accent))
    }
}

struct AIAPISettings: View {
    @Environment(\.lumaSurface) private var surface
    @Environment(\.lumaMuted) private var muted
    @Bindable var ai: AIChatStore
    @State private var key = ""
    @State private var hasKey = false
    @State private var status: String?
    var body: some View {
        Section(L10n.text("AI 服务")) {
            Picker(L10n.text("服务商"),selection:Binding(get:{ ai.provider },set:{ ai.selectProvider($0) })) {
                ForEach(AIProvider.allCases) { provider in Text(L10n.text(provider.title)).tag(provider) }
            }.disabled(ai.isSending)
            TextField(L10n.text("API 地址"),text:$ai.baseURL).lumaInputSurface().disabled(ai.isSending)
            TextField(L10n.text("文字模型"),text:$ai.model).lumaInputSurface().disabled(ai.isSending)
            if ai.provider.supportsImages { TextField(L10n.text("图片模型"),text:$ai.visionModel).lumaInputSurface().disabled(ai.isSending) }
            SecureField(L10n.text(hasKey ? "密钥已保存，输入可替换":"API Key"),text:$key).lumaInputSurface().disabled(ai.isSending)
            HStack {
                Button(L10n.text("保存密钥")) {
                    do { _ = try AIClient.endpoint(ai.baseURL,provider:ai.provider); try AIKeychain.save(key,provider:ai.provider); key = ""; hasKey = true; status = "已存入 macOS 钥匙串" }
                    catch { status = error.localizedDescription }
                }.disabled(key.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || ai.isSending)
                Button(L10n.text("移除密钥")) {
                    do { try AIKeychain.remove(provider:ai.provider); key = ""; hasKey = false; status = "密钥已移除" }
                    catch { status = error.localizedDescription }
                }.disabled(!hasKey || ai.isSending)
            }
            if let status { Text(status).font(.caption).foregroundStyle(muted) }
            if ai.provider == .qwen { Text(L10n.text("千问地址需与密钥所属地域一致；可填写百炼控制台提供的北京、新加坡或其他地域地址。")).font(.caption).foregroundStyle(muted) }
            Text(L10n.text("每家单独保存密钥与模型。切换会将本次对话历史发送给所选服务；关闭“附带当前阅读”可排除书籍上下文。仅发送时调用 API，对话不写入云存档。"))
                .font(.caption).foregroundStyle(muted)
        }.listRowBackground(surface.opacity(0.72)).onAppear { refreshKey() }.listRowBackground(surface.opacity(0.72)).onChange(of:ai.provider) { _,_ in key = ""; status = nil; refreshKey() }.listRowBackground(surface.opacity(0.72))
    }
    private func refreshKey() {
        do { hasKey = try AIKeychain.read(provider:ai.provider) != nil }
        catch { hasKey = false; status = error.localizedDescription }
    }
}

