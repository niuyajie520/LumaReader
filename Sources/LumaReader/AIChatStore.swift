import Foundation
import Observation

@MainActor @Observable
final class AIChatStore {
    var provider = AIProvider(rawValue:UserDefaults.standard.string(forKey:"aiProvider") ?? "") ?? .deepseek {
        didSet { UserDefaults.standard.set(provider.rawValue,forKey:"aiProvider") }
    }
    var baseURL: String {
        get { _ = settingsRevision; return UserDefaults.standard.string(forKey:"ai.\(provider.rawValue).base") ?? (provider == .deepseek ? UserDefaults.standard.string(forKey:"aiBaseURL"):nil) ?? provider.baseURL }
        set { UserDefaults.standard.set(newValue,forKey:"ai.\(provider.rawValue).base"); settingsRevision += 1 }
    }
    var model: String {
        get { _ = settingsRevision; return UserDefaults.standard.string(forKey:"ai.\(provider.rawValue).model") ?? (provider == .deepseek ? UserDefaults.standard.string(forKey:"aiModel"):nil) ?? provider.model }
        set { UserDefaults.standard.set(newValue,forKey:"ai.\(provider.rawValue).model"); settingsRevision += 1 }
    }
    var visionModel:String {
        get { _ = settingsRevision; return UserDefaults.standard.string(forKey:"ai.\(provider.rawValue).visionModel") ?? provider.imageModel }
        set { UserDefaults.standard.set(newValue,forKey:"ai.\(provider.rawValue).visionModel"); settingsRevision += 1 }
    }
    var effectiveModel:String { (pendingImage != nil || messages.suffix(20).contains(where:{ $0.image != nil })) && provider.supportsImages ? visionModel:model }
    var pendingImage:AIImageAttachment?
    func clearImage() { pendingImage = nil }
    var settingsRevision = 0
    func selectProvider(_ selected:AIProvider) {
        guard !isSending else { return }
        provider = selected; error = nil
    }
    var includeReading = UserDefaults.standard.object(forKey:"aiIncludeReading") as? Bool ?? true { didSet { UserDefaults.standard.set(includeReading,forKey:"aiIncludeReading") } }
    var draft = ""
    var messages: [AIChatMessage] = []
    var context: AIReadingContext?
    var pendingQuote = ""
    var isSending = false
    var error: String?
    @ObservationIgnored private var requestTask: Task<Void,Never>?
    @ObservationIgnored private var generation = UUID()

    func prepare(_ context:AIReadingContext?,image:AIImageAttachment? = nil) {
        pendingImage = image
        self.context = context; pendingQuote = context?.selectedText ?? ""
    }
    func clearQuote() { pendingQuote = ""; context?.selectedText = "" }
    func clearConversation() { cancel(); messages = []; draft = ""; error = nil; clearQuote(); clearImage() }
    func cancel() { generation = UUID(); requestTask?.cancel(); requestTask = nil; isSending = false }
    func sendUsingContext(_ provider: (@escaping (AIReadingContext?) -> Void) -> Void) {
        guard !isSending, !draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        isSending = true; let token = UUID(); generation = token
        provider { [weak self] context in
            guard let self, self.generation == token else { return }
            self.isSending = false; self.send(with:context)
        }
    }
    private func send(with context:AIReadingContext?) {
        guard !isSending else { return }
        let question = draft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        do {
            if !provider.supportsImages && (pendingImage != nil || messages.suffix(20).contains(where:{ $0.image != nil })) { throw AIClientError.unsupportedImage }
            guard let key = try AIKeychain.read(provider:provider), !key.isEmpty else { throw AIClientError.missingKey }
            _ = try AIClient.endpoint(baseURL,provider:provider)
            var attached = context ?? (!pendingQuote.isEmpty ? self.context:nil)
            attached?.selectedText = pendingQuote
            self.context = attached
            let message = AIChatMessage(role:"user",text:String(question.prefix(12000)),context:includeReading ? attached:nil,image:pendingImage)
            let history = messages + [message]
            let endpoint = baseURL, model = effectiveModel, include = includeReading, selectedProvider = provider
            isSending = true; error = nil
            let token = UUID(); generation = token
            requestTask = Task { [weak self] in
                do {
                    let answer = try await AIClient.answer(base:endpoint,model:model,key:key,history:history,includeContext:include,provider:selectedProvider)
                    guard !Task.isCancelled, let self, self.generation == token else { return }
                    self.messages.append(message)
                    self.messages.append(AIChatMessage(role:"assistant",text:answer,providerTitle:selectedProvider.title))
                    if self.messages.count > 200 { self.messages.removeFirst(self.messages.count-200) }
                    var images = 0
                    for index in self.messages.indices.reversed() where self.messages[index].image != nil {
                        images += 1; if images > 3 { self.messages[index].image = nil }
                    }
                    self.pendingImage = nil
                    self.draft = ""; self.clearQuote(); self.isSending = false; self.requestTask = nil
                } catch {
                    guard !Task.isCancelled, let self, self.generation == token else { return }
                    self.error = (error as? AIClientError)?.localizedDescription ?? "连接 AI 服务失败，请检查网络与 API 设置后重试。"
                    self.isSending = false; self.requestTask = nil
                }
            }
        } catch { self.error = error.localizedDescription }
    }
}

extension Notification.Name {
    static let lumaAskAI = Notification.Name("LumaReader.AskAI")
}
