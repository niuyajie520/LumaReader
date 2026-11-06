import Foundation
import Observation

@MainActor @Observable
final class AIChatStore {
    var provider = AIProvider(rawValue:UserDefaults.standard.string(forKey:"aiProvider") ?? "") ?? .deepseek {
        didSet { UserDefaults.standard.set(provider.rawValue,forKey:"aiProvider"); historyDidChange() }
    }
    var baseURL: String {
        get { _ = settingsRevision; return UserDefaults.standard.string(forKey:"ai.\(provider.rawValue).base") ?? (provider == .deepseek ? UserDefaults.standard.string(forKey:"aiBaseURL"):nil) ?? provider.baseURL }
        set { UserDefaults.standard.set(newValue,forKey:"ai.\(provider.rawValue).base"); settingsRevision += 1 }
    }
    var model: String {
        get { _ = settingsRevision; return historyModel ?? UserDefaults.standard.string(forKey:"ai.\(provider.rawValue).model") ?? (provider == .deepseek ? UserDefaults.standard.string(forKey:"aiModel"):nil) ?? provider.model }
        set { historyModel = nil; UserDefaults.standard.set(newValue,forKey:"ai.\(provider.rawValue).model"); settingsRevision += 1; historyDidChange() }
    }
    var visionModel:String {
        get { _ = settingsRevision; return historyVisionModel ?? UserDefaults.standard.string(forKey:"ai.\(provider.rawValue).visionModel") ?? provider.imageModel }
        set { historyVisionModel = nil; UserDefaults.standard.set(newValue,forKey:"ai.\(provider.rawValue).visionModel"); settingsRevision += 1; historyDidChange() }
    }
    var effectiveModel:String { (pendingImage != nil || messages.suffix(20).contains(where:{ $0.image != nil })) && provider.supportsImages ? visionModel:model }
    var pendingImage:AIImageAttachment? { didSet { historyDidChange() } }
    func clearImage() { pendingImage = nil }
    var settingsRevision = 0
    func selectProvider(_ selected:AIProvider) {
        guard !isSending, !isLoadingConversation else { return }
        historyModel = nil; historyVisionModel = nil; provider = selected; error = nil
    }
    var includeReading = UserDefaults.standard.object(forKey:"aiIncludeReading") as? Bool ?? true { didSet { UserDefaults.standard.set(includeReading,forKey:"aiIncludeReading"); if !restoringHistory { historyContextProtected = false }; historyDidChange() } }
    var draft = "" { didSet { historyDidChange() } }
    var messages: [AIChatMessage] = [] { didSet { historyDidChange() } }
    var context: AIReadingContext? { didSet { historyDidChange() } }
    var pendingQuote = "" { didSet { historyDidChange() } }
    var isSending = false
    var error: String?
    @ObservationIgnored private var requestTask: Task<Void,Never>?
    @ObservationIgnored private var generation = UUID()
    var currentConversationID = UUID()
    var conversations: [AIConversationSummary] = []
    var isLoadingConversation = false
    var historyModel: String?
    var historyVisionModel: String?
    @ObservationIgnored var historyDirectory: URL
    @ObservationIgnored var restoringHistory = true
    @ObservationIgnored var historyWritable = true
    @ObservationIgnored var historyDirty = false
    @ObservationIgnored var historyContextProtected = false
    @ObservationIgnored var conversationEditedAt = Date()
    @ObservationIgnored var historySaveTask: Task<Void,Never>?
    @ObservationIgnored var historyRestoreToken = UUID()
    @ObservationIgnored var historyWriteRevision = 0
    @ObservationIgnored let historyQueue = DispatchQueue(label:"app.luma.private-ai-history",qos:.utility)

    init(historyDirectory:URL? = nil) {
        self.historyDirectory = historyDirectory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("LumaReader/PrivateAI/History",isDirectory:true)
        do {
            if let index = try AIConversationDisk.readIndex(self.historyDirectory) {
                conversations = index.conversations
                if conversations.contains(where: { $0.id == index.activeID }) {
                    applyConversation(try AIConversationDisk.read(index.activeID,in:self.historyDirectory))
                }
            }
        } catch {
            historyWritable = false
            error = "无法读取本地聊天记录，原文件已保留。"
        }
        restoringHistory = false
        historyDirty = false
    }

    func prepare(_ context:AIReadingContext?,image:AIImageAttachment? = nil) {
        abortHistoryRestore(); historyContextProtected = false
        pendingImage = image
        self.context = context; pendingQuote = context?.selectedText ?? ""
    }
    func clearQuote() { pendingQuote = ""; context?.selectedText = "" }
    func clearConversation() {
        flushHistory()
        guard !conversationRecord().hasContent || (historyWritable && !historyDirty) else { return }
        abortHistoryRestore(); cancel()
        restoringHistory = true
        currentConversationID = UUID(); conversationEditedAt = Date()
        messages = []; draft = ""; context = nil; pendingQuote = ""; pendingImage = nil; error = nil
        historyModel = nil; historyVisionModel = nil; historyContextProtected = false
        restoringHistory = false; historyDirty = true; flushHistory()
    }
    func cancel() { generation = UUID(); requestTask?.cancel(); requestTask = nil; isSending = false }
    func sendUsingContext(_ provider: (@escaping (AIReadingContext?) -> Void) -> Void) {
        guard !isSending, !isLoadingConversation, !draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        isSending = true; let token = UUID(); generation = token
        provider { [weak self] context in
            guard let self, self.generation == token else { return }
            self.isSending = false; self.send(with:self.incomingHistoryContext(context))
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
                    // Keep the complete local conversation; AIClient still bounds the wire context.
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
