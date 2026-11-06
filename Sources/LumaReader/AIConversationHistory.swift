import Foundation

struct AIConversationSummary: Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var updatedAt: Date
}

struct AIConversationRecord: Codable, Sendable {
    var version = 1
    var id: UUID
    var updatedAt: Date
    var provider: AIProvider
    var model: String
    var visionModel: String
    var messages: [AIChatMessage]
    var draft: String
    var context: AIReadingContext?
    var pendingQuote: String
    var pendingImage: AIImageAttachment?
    var includeReading: Bool
    var hasContent: Bool { !messages.isEmpty || !draft.isEmpty || pendingImage != nil || !pendingQuote.isEmpty }
    var summary: AIConversationSummary {
        let text = messages.first(where: { $0.role == "user" })?.text ?? draft
        let title = text.split(whereSeparator: { $0.isWhitespace }).joined(separator:" ")
        return AIConversationSummary(id:id,title:String(title.prefix(40)),updatedAt:updatedAt)
    }
}

struct AIHistoryIndex: Codable, Sendable {
    var version = 1
    var activeID: UUID
    var conversations: [AIConversationSummary]
}

enum AIConversationDisk {
    static func readIndex(_ directory:URL) throws -> AIHistoryIndex? {
        let file = directory.appendingPathComponent("history.json")
        guard FileManager.default.fileExists(atPath:file.path) else { return nil }
        let index = try JSONDecoder().decode(AIHistoryIndex.self,from:Data(contentsOf:file))
        guard index.version == 1, Set(index.conversations.map(\.id)).count == index.conversations.count else { throw CocoaError(.fileReadCorruptFile) }
        return index
    }
    static func read(_ id:UUID,in directory:URL) throws -> AIConversationRecord {
        let record = try JSONDecoder().decode(AIConversationRecord.self,from:Data(contentsOf:directory.appendingPathComponent(id.uuidString+".json")))
        guard record.id == id, record.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        return record
    }
    static func write(_ record:AIConversationRecord,index:AIHistoryIndex,to directory:URL) -> Bool {
        do {
            let fm = FileManager.default
            try fm.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            try fm.setAttributes([.posixPermissions:0o700],ofItemAtPath:directory.path)
            if record.hasContent {
                let file = directory.appendingPathComponent(record.id.uuidString+".json")
                try JSONEncoder().encode(record).write(to:file,options:.atomic)
                try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
            }
            let file = directory.appendingPathComponent("history.json")
            try JSONEncoder().encode(index).write(to:file,options:.atomic)
            try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
            return true
        } catch { return false } // Never expose file paths or conversation contents in diagnostics.
    }
}

@MainActor extension AIChatStore {
    var historyEntries: [AIConversationSummary] {
        var entries = conversations.filter { $0.id != currentConversationID }
        let record = conversationRecord()
        if record.hasContent { entries.append(record.summary) }
        return entries.sorted { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString:$0.updatedAt > $1.updatedAt }
    }
    func conversationRecord() -> AIConversationRecord {
        AIConversationRecord(id:currentConversationID,updatedAt:conversationEditedAt,provider:provider,model:model,visionModel:visionModel,
                             messages:messages,draft:draft,context:context,pendingQuote:pendingQuote,pendingImage:pendingImage,includeReading:includeReading)
    }
    func historyDidChange() {
        guard !restoringHistory, historyWritable else { return }
        historyDirty = true
        conversationEditedAt = Date()
        historySaveTask?.cancel()
        historySaveTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for:.milliseconds(600)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.persistHistory(asynchronously:true)
        }
    }
    func flushHistory() {
        historySaveTask?.cancel(); historySaveTask = nil
        persistHistory(asynchronously:false)
    }
    private func persistHistory(asynchronously:Bool) {
        guard historyWritable, historyDirty, !restoringHistory else { return }
        let record = conversationRecord()
        guard record.hasContent || !conversations.isEmpty else { return }
        conversations = historyEntries
        let index = AIHistoryIndex(activeID:currentConversationID,conversations:conversations)
        let directory = historyDirectory
        historyWriteRevision += 1
        let revision = historyWriteRevision
        historyDirty = false
        if asynchronously {
            historyQueue.async { [weak self] in
                let success = AIConversationDisk.write(record,index:index,to:directory)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.historyWriteRevision == revision else { return }
                    if !success { self.historyDirty = true; self.error = "无法保存本地聊天记录，请检查磁盘空间。" }
                }
            }
        } else if !historyQueue.sync(execute:{ AIConversationDisk.write(record,index:index,to:directory) }) {
            historyDirty = true
            error = "无法保存本地聊天记录，请检查磁盘空间。"
        }
    }
    func restoreConversation(_ id:UUID) {
        guard !isSending, id != currentConversationID, conversations.contains(where: { $0.id == id }) else { return }
        flushHistory()
        guard !conversationRecord().hasContent || (historyWritable && !historyDirty) else { return }
        let token = UUID(); historyRestoreToken = token; isLoadingConversation = true
        let directory = historyDirectory
        historyQueue.async { [weak self] in
            let record = try? AIConversationDisk.read(id,in:directory)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.historyRestoreToken == token else { return }
                self.isLoadingConversation = false
                guard let record else { self.error = "无法读取这条聊天记录，原记录已保留。"; return }
                self.applyConversation(record)
                self.historyDirty = true
                self.flushHistory()
            }
        }
    }
    func applyConversation(_ record:AIConversationRecord) {
        restoringHistory = true
        currentConversationID = record.id; conversationEditedAt = record.updatedAt
        provider = record.provider; historyModel = record.model; historyVisionModel = record.visionModel
        messages = record.messages; draft = record.draft; context = record.context
        pendingQuote = record.pendingQuote; pendingImage = record.pendingImage; includeReading = record.includeReading
        historyContextProtected = true; error = nil
        restoringHistory = false
    }
    func incomingHistoryContext(_ incoming:AIReadingContext?) -> AIReadingContext? {
        historyContextProtected && incoming?.bookID != context?.bookID ? nil:incoming
    }
    func abortHistoryRestore() { historyRestoreToken = UUID(); isLoadingConversation = false }
}
