import SwiftUI

public struct VocabularyImportRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var word: String
    public var meaning: String
    public var included: Bool
    public var needsConfirmation: Bool
    public var confirmationReason: String?
    public var sourceLineDescription: String

    public init(
        id: UUID = UUID(),
        word: String,
        meaning: String,
        included: Bool = true,
        needsConfirmation: Bool = false,
        confirmationReason: String? = nil,
        sourceLineDescription: String = ""
    ) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.included = included
        self.needsConfirmation = needsConfirmation
        self.confirmationReason = confirmationReason
        self.sourceLineDescription = sourceLineDescription
    }

    public var issue: String? {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        if !VocabularyImport.isValidEnglishTerm(trimmedWord) {
            return "待确认：英文词条为空、过长或包含非英文字符"
        }
        if trimmedMeaning.isEmpty {
            return confirmationReason ?? "待确认：请补充中文释义（系统不会凭空生成翻译）"
        }
        if needsConfirmation {
            return confirmationReason ?? "待确认：请核对此配对并点击「确认此条」"
        }
        return nil
    }
}

public struct VocabularyImportDraft: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let filename: String
    public var rows: [VocabularyImportRow]
    public var ignoredNonVocabularyLines: [String] = []

    public var recognizedEnglishCount: Int {
        rows.filter { VocabularyImport.isValidEnglishTerm($0.word) }.count
    }

    public var pairedMeaningCount: Int {
        rows.filter {
            VocabularyImport.isValidEnglishTerm($0.word) &&
            !$0.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.needsConfirmation
        }.count
    }

    public var unmatchedOrAmbiguousCount: Int {
        rows.filter { $0.needsConfirmation || $0.issue != nil }.count
    }

    public init(data: Data, filename: String) throws {
        guard data.count <= 2 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        self.filename = filename
        if filename.lowercased().hasSuffix(".json") {
            let items = try JSONDecoder().decode([VocabularyImport.Item].self, from: data)
            self.rows = items.map { item in
                let validEng = VocabularyImport.isValidEnglishTerm(item.word)
                let hasMeaning = !item.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                return VocabularyImportRow(
                    word: item.word,
                    meaning: item.meaning,
                    included: true,
                    needsConfirmation: !validEng || !hasMeaning,
                    confirmationReason: (!validEng || !hasMeaning) ? "待确认：词条或释义不完整" : nil
                )
            }
        } else {
            let text = try VocabularyImport.decodeText(from: data)
            let report = VocabularyImport.analyzeSmartText(text, filename: filename)
            self.ignoredNonVocabularyLines = report.ignoredNonVocabularyLines
            self.rows = report.candidates.map { cand in
                VocabularyImportRow(
                    id: cand.id,
                    word: cand.word,
                    meaning: cand.meaning,
                    included: true,
                    needsConfirmation: cand.status == .needsConfirmation,
                    confirmationReason: cand.statusReason,
                    sourceLineDescription: cand.sourceLineDescription
                )
            }
        }
        guard !rows.isEmpty, rows.count <= 20000 else { throw CocoaError(.fileReadCorruptFile) }
    }

    public mutating func confirmRow(id: UUID) {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        let trimmedWord = rows[idx].word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = rows[idx].meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        if VocabularyImport.isValidEnglishTerm(trimmedWord) && !trimmedMeaning.isEmpty {
            rows[idx].needsConfirmation = false
            rows[idx].confirmationReason = nil
        }
    }

    public mutating func removeRow(id: UUID) {
        rows.removeAll { $0.id == id }
    }

    public func confirmedWords(existing: [VocabularyWord]) throws -> [VocabularyWord] {
        let selected = rows.filter(\.included)
        guard !selected.isEmpty, selected.allSatisfy({ $0.issue == nil }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let json = try JSONSerialization.data(
            withJSONObject: selected.map { ["word": $0.word, "meaning": $0.meaning] }
        )
        let words = try VocabularyImport.parseJSONEntries(json, filename: filename)
        let ids = Set(existing.map(\.id))
        return words.filter { !ids.contains($0.id) }
    }
}

struct VocabularyImportReview: View {
    @State var draft: VocabularyImportDraft
    let existing: [VocabularyWord]
    let onConfirm: @MainActor ([VocabularyWord]) -> String?
    @State private var error = ""
    @State private var filterMode: String = "all"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.studyAppearance) private var appearance

    private var warnings: [UUID: String] {
        var result: [UUID: String] = [:], seen = Set<String>()
        let deckWords = Set(
            existing
                .filter { $0.deckID == VocabularyImport.deckIdentifier(for: draft.filename) }
                .map { $0.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        for row in draft.rows where row.included {
            let key = row.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let issue = row.issue {
                result[row.id] = issue
            } else if deckWords.contains(key) || !seen.insert(key).inserted {
                result[row.id] = "重复词 · 保留已有词条与错词进度，不重复覆盖"
            }
        }
        return result
    }

    var body: some View {
        let notices = warnings
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TXT / 词库中英文智能识别预览")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                    Text("\(draft.filename) · 确认前绝不修改或覆盖现有词库与学习进度")
                        .font(.caption)
                        .foregroundStyle(appearance.ink.opacity(0.68))
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle())
            }

            // Summary Metrics Capsules (Section 一.2)
            HStack(spacing: 12) {
                metricPill(title: "识别英文词汇", count: draft.recognizedEnglishCount, tint: appearance.accent)
                metricPill(title: "成功配对释义", count: draft.pairedMeaningCount, tint: .green)
                metricPill(title: "待确认 / 歧义", count: draft.unmatchedOrAmbiguousCount, tint: draft.unmatchedOrAmbiguousCount > 0 ? .orange : appearance.ink.opacity(0.6))
                if !draft.ignoredNonVocabularyLines.isEmpty {
                    metricPill(title: "已过滤标题/例句", count: draft.ignoredNonVocabularyLines.count, tint: appearance.ink.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 6) {
                    filterChip("全部 (\(draft.rows.count))", id: "all")
                    filterChip("已配对 (\(draft.pairedMeaningCount))", id: "paired")
                    filterChip("待确认 (\(draft.unmatchedOrAmbiguousCount))", id: "pending")
                }
            }

            List {
                ForEach($draft.rows) { $row in
                    let showRow = filterMode == "all" ||
                        (filterMode == "paired" && row.issue == nil) ||
                        (filterMode == "pending" && row.issue != nil)
                    if showRow {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Toggle("导入", isOn: $row.included)
                                    .labelsHidden()
                                if !row.sourceLineDescription.isEmpty {
                                    Text(row.sourceLineDescription)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(appearance.ink.opacity(0.5))
                                        .frame(width: 72, alignment: .leading)
                                }
                                TextField("英文单词或短语", text: $row.word)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 190)
                                    .onChange(of: row.word) { _, _ in
                                        if VocabularyImport.isValidEnglishTerm(row.word) && !row.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            row.needsConfirmation = false
                                        }
                                    }

                                TextField("中文释义（未识别请手动补全）", text: $row.meaning)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 220)
                                    .onChange(of: row.meaning) { _, _ in
                                        if VocabularyImport.isValidEnglishTerm(row.word) && !row.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            row.needsConfirmation = false
                                        }
                                    }

                                if row.issue != nil {
                                    Text("待确认")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                                    if VocabularyImport.isValidEnglishTerm(row.word) && !row.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Button("确认此条") {
                                            draft.confirmRow(id: row.id)
                                        }
                                        .buttonStyle(StudyGlassCapsuleButtonStyle(height: 28))
                                    }
                                } else {
                                    Text("✓ 已配对")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.green.opacity(0.14)))
                                }

                                Button(role: .destructive) {
                                    draft.removeRow(id: row.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.borderless)
                                .help("删除此条")
                            }
                            if let notice = notices[row.id] {
                                Text(notice)
                                    .font(.caption)
                                    .foregroundStyle(row.issue == nil ? appearance.ink.opacity(0.6) : .orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(appearance.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(appearance.line, lineWidth: 1))
            )

            if !error.isEmpty {
                Text(error).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Text("提示：勾选项中若仍有「待确认」词条，请先补全释义、点击「确认此条」或取消勾选/删除。")
                    .font(.caption)
                    .foregroundStyle(appearance.ink.opacity(0.65))
                Spacer()
                Button("确认导入并应用到听写 (\(draft.rows.filter { $0.included && $0.issue == nil }.count) 词)") {
                    do {
                        let words = try draft.confirmedWords(existing: existing)
                        if let issue = onConfirm(words) {
                            error = issue
                        } else {
                            dismiss()
                        }
                    } catch {
                        self.error = "请先修正、确认或取消勾选标为「待确认」的词条；现有词库未更改。"
                    }
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 20, height: 38))
                .disabled(
                    !draft.rows.contains(where: { $0.included }) ||
                    draft.rows.contains(where: { $0.included && $0.issue != nil })
                )
            }
        }
        .padding(24)
        .frame(minWidth: 820, minHeight: 560)
        .background(appearance.paper)
        .foregroundStyle(appearance.ink)
    }

    private func metricPill(title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(appearance.ink.opacity(0.75))
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .studyGlassCapsule(cornerRadius: 16)
    }

    private func filterChip(_ label: String, id: String) -> some View {
        Button {
            filterMode = id
        } label: {
            Text(label)
        }
        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: filterMode == id, horizontalPadding: 12, height: 30))
    }
}
