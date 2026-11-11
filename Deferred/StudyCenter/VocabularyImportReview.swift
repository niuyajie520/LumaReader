import SwiftUI
import AppKit

public struct VocabularyImportReview: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.studyAppearance) private var envAppearance
    @State public var draft: VocabularyImportDraft
    @State private var error: String?
    @State private var filterMode: String = "all"
    @State private var filteredRowIDs: Set<UUID>?
    @State private var pendingRemoval: UUID?
    @State private var lastRemovedRow: VocabularyImportRow?
    @State private var lastRemovedIndex = 0
    public let existing: [VocabularyWord]
    public let onConfirm: ([VocabularyWord]) -> String?

    private var appearance: StudyAppearance {
        StudyAppearance.liveOverride ?? StudyAppearance.current
    }

    public init(draft: VocabularyImportDraft, existing: [VocabularyWord], onConfirm: @escaping ([VocabularyWord]) -> String?) {
        var initial = draft
        initial.applyDefaultSelection(existing: existing)
        _draft = State(initialValue: initial)
        self.existing = existing
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部栏：标题 + 词库名称输入
            HStack(spacing: 12) {
                Text("导入词库")
                    .lumaFont(size: 19, weight: .semibold)
                    .foregroundStyle(appearance.ink)

                Spacer()

                HStack(spacing: 8) {
                    Text("词库名称")
                        .lumaFont(size: 12)
                        .foregroundStyle(appearance.ink.opacity(0.65))
                    TextField("词库名称", text: $draft.deckTitle)
                        .textFieldStyle(.plain)
                        .lumaFont(size: 13)
                        .foregroundStyle(appearance.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(width: 210)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(appearance.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(appearance.line, lineWidth: 1)
                                )
                        )
                }
            }

            // 简洁筛选与自主补全控制条（默认严格使用文件自带中文；仅无中文词条留给用户自主决定是否用词典补全）
            let plan = draft.importPlan(existing: existing)
            let kinds = draft.duplicateKinds(existing: existing)
            let exactRows = draft.rows.filter { kinds[$0.id] == .exactDuplicate }
            let otherRows = draft.rows.filter { kinds[$0.id] == .sameWordOtherMeaning }
            HStack(spacing: 8) {
                filterPill("全部 (\(draft.rows.count))", id: "all")
                if draft.unmatchedOrAmbiguousCount > 0 { filterPill("需要检查 (\(draft.unmatchedOrAmbiguousCount))", id: "pending") }
                if !draft.ignoredNonVocabularyLines.isEmpty { filterPill("未识别 (\(draft.ignoredNonVocabularyLines.count))", id: "ignored") }
                Spacer()
                Menu("更多") {
                    Button("查看完全重复的行 (\(exactRows.count))") { chooseFilter("exact") }
                    Button("查看重复英文、不同中文 (\(otherRows.count))") { chooseFilter("other") }
                    Button(draft.mergeSameWordMeanings ? "恢复每行单独保留" : "将重复英文的中文合并到一条") { draft.mergeSameWordMeanings.toggle() }
                    if draft.pureEnglishDictionaryFillableCount > 0 {
                        Button(draft.useBuiltInDictionaryMode ? "撤回词典补全" : "用词典补全缺少的中文") { draft.applyTranslationSource(useDictionary: !draft.useBuiltInDictionaryMode, overwriteBuiltIn: false) }
                    }
                }.menuStyle(.borderlessButton).fixedSize()
            }
            Text("默认采用你文件中的中文，不与词典比较或自动改写。")
                .font(.caption).foregroundStyle(appearance.ink.opacity(0.65))

            // 数量说明：文件有多少条、真正会导入多少、各被跳过/保留了多少，避免「预览数」和「导入数」对不上
            Text(importSummaryText(plan))
                .lumaFont(size: 12)
                .foregroundStyle(appearance.ink.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let error, !error.isEmpty {
                Text(error)
                    .lumaFont(size: 12.5, weight: .medium)
                    .foregroundStyle(appearance.accent)
            }

            // 词条预览列表（纯正莫奈背景与圆角卡片，无水平溢出裁切）
            ScrollView {
                LazyVStack(spacing: 6) {
                    if filterMode == "ignored" {
                        HStack {
                            Text("这些行没有被自动识别为单词。你可以自己决定要不要加入：")
                                .lumaFont(size: 12)
                                .foregroundStyle(appearance.ink.opacity(0.7))
                            Spacer()
                            Button("全部加入 (\(draft.ignoredNonVocabularyLines.count))") {
                                draft.restoreAllIgnoredLines()
                                filterMode = "all"
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 28))
                        }
                        .padding(.horizontal, 6)
                        ForEach(Array(draft.ignoredNonVocabularyLines.enumerated()), id: \.offset) { offset, line in
                            HStack(spacing: 10) {
                                Text(line)
                                    .lumaFont(size: 13)
                                    .foregroundStyle(appearance.ink.opacity(0.75))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button("加入") {
                                    draft.restoreIgnoredLine(at: offset)
                                    if draft.ignoredNonVocabularyLines.isEmpty { filterMode = "all" }
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: true, horizontalPadding: 12, height: 26))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(appearance.surface)
                            )
                        }
                    }
                    if filterMode == "exact" || filterMode == "other" {
                        let targets = filterMode == "exact" ? exactRows : otherRows
                        HStack {
                            Text(filterMode == "exact"
                                 ? "这些行的英文和释义都和前面某一行（或词库里已有的词）完全一样，默认没有勾选："
                                 : "这些行英文相同、释义不同，默认已勾选：")
                                .lumaFont(size: 12)
                                .foregroundStyle(appearance.ink.opacity(0.7))
                            Spacer()
                            Button("全部加入 (\(targets.count))") {
                                let ids = Set(targets.map(\.id))
                                for idx in draft.rows.indices where ids.contains(draft.rows[idx].id) { draft.rows[idx].included = true }
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 28))
                            Button("全部不加") {
                                let ids = Set(targets.map(\.id))
                                for idx in draft.rows.indices where ids.contains(draft.rows[idx].id) { draft.rows[idx].included = false }
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 28))
                        }
                        .padding(.horizontal, 6)
                    }
                    ForEach($draft.rows) { $row in
                        let showRow = filterMode != "ignored" && (filterMode == "all" || filteredRowIDs?.contains(row.id) == true)
                        if showRow {
                            HStack(spacing: 10) {
                                Toggle("", isOn: $row.included)
                                    .labelsHidden()
                                    .toggleStyle(.checkbox)

                                Text("\(row.lineNumber)")
                                    .lumaFont(size: 11, design: .monospaced)
                                    .foregroundStyle(appearance.ink.opacity(0.45))
                                    .frame(width: 34, alignment: .trailing)

                                if let kind = kinds[row.id], kind == .exactDuplicate {
                                    Text("重复行")
                                        .lumaFont(size: 10.5, weight: .medium)
                                        .foregroundStyle(appearance.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().strokeBorder(appearance.accent.opacity(0.7), lineWidth: 0.8))
                                }

                                ImportPreviewTextField("英文单词或短语", text: $row.word, ink: appearance.ink)
                                    .textFieldStyle(.plain)
                                    .lumaFont(size: 13.5, weight: .medium)
                                    .foregroundStyle(appearance.ink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(width: 210)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(appearance.paper.opacity(0.55))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                    .strokeBorder(appearance.line, lineWidth: 0.8)
                                            )
                                    )
                                    .onChange(of: row.word) { _, updatedWord in
                                        row.dictionaryMeaning = BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: updatedWord)
                                        if VocabularyImport.isValidEnglishTerm(updatedWord) && !row.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            row.needsConfirmation = false
                                        }
                                    }

                                ImportPreviewTextField("文件中的中文释义", text: $row.meaning, ink: appearance.ink)
                                    .textFieldStyle(.plain)
                                    .lumaFont(size: 13.5)
                                    .foregroundStyle(appearance.ink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(appearance.paper.opacity(0.55))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                    .strokeBorder(row.issue != nil ? appearance.accent.opacity(0.75) : appearance.line, lineWidth: 0.8)
                                            )
                                    )
                                    .onChange(of: row.meaning) { _, newValue in
                                        if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            row.needsConfirmation = false
                                        }
                                    }

                                // 仅当文件里实在没有中文（或用户想手动切换该词）时，才提供词典按钮由用户自己决定
                                if row.builtInMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                   let dictZH = row.dictionaryMeaning, !dictZH.isEmpty {
                                    if row.meaning != dictZH {
                                        Button("词典补全") {
                                            row.meaning = dictZH
                                            row.isUsingDictionaryMeaning = true
                                            row.needsConfirmation = false
                                        }
                                        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: true, horizontalPadding: 10, height: 26))
                                    } else {
                                        Button("清空") {
                                            row.meaning = ""
                                            row.isUsingDictionaryMeaning = false
                                            row.needsConfirmation = true
                                        }
                                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 8, height: 26))
                                    }
                                }

                                Button {
                                    pendingRemoval = row.id
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(appearance.ink.opacity(0.45))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                .help("移除此条")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(appearance.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(appearance.line.opacity(0.7), lineWidth: 0.8)
                                    )
                            )
                        }
                    }
                }
                .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appearance.paper.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(appearance.line, lineWidth: 1)
                    )
            )

            // 底部操作栏
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 18, height: 36))

                Spacer()

                if let removed = lastRemovedRow {
                    Button("撤销移除") {
                        draft.rows.insert(removed, at: min(lastRemovedIndex, draft.rows.count))
                        lastRemovedRow = nil
                    }
                }

                let validCount = draft.rows.filter { $0.included && $0.issue == nil }.count
                Button("确认导入 (\(plan.words.count) 词)") {
                    do {
                        let words = try draft.confirmedWords(existing: existing)
                        if let message = onConfirm(words) {
                            error = message
                        } else {
                            dismiss()
                        }
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 20, height: 36))
                .disabled(validCount == 0 || draft.rows.contains(where: { $0.included && $0.issue != nil }))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 720, height: 540)
        .background(appearance.paper)
        .foregroundStyle(appearance.ink)
        .alert("移除这一整行？", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })) {
            Button("移除整行", role: .destructive) {
                if let id = pendingRemoval, let index = draft.rows.firstIndex(where: { $0.id == id }) {
                    lastRemovedRow = draft.rows[index]; lastRemovedIndex = index
                    draft.removeRow(id: id)
                }
                pendingRemoval = nil
            }
            Button("取消", role: .cancel) { pendingRemoval = nil }
        }
    }

    private func chooseFilter(_ id: String) {
        filterMode = id
        let kinds = draft.duplicateKinds(existing: existing)
        switch id {
        case "exact": filteredRowIDs = Set(draft.rows.filter { kinds[$0.id] == .exactDuplicate }.map(\.id))
        case "other": filteredRowIDs = Set(draft.rows.filter { kinds[$0.id] == .sameWordOtherMeaning }.map(\.id))
        case "pending": filteredRowIDs = Set(draft.rows.filter { $0.issue != nil }.map(\.id))
        default: filteredRowIDs = nil
        }
    }

    private func importSummaryText(_ plan: VocabularyImportPlan) -> String {
        var parts = ["将导入 \(plan.words.count) 词（只导入你勾选的行，不会自动跳过）"]
        if plan.exactDuplicates > 0 { parts.append("其中完全重复 \(plan.exactDuplicates)") }
        if plan.keptAsSeparate > 0 { parts.append("重复英文按原中文保留 \(plan.keptAsSeparate)") }
        if plan.mergedIntoOne > 0 { parts.append("已合并 \(plan.mergedIntoOne)") }
        let excluded = draft.rows.filter { !$0.included }.count
        if excluded > 0 { parts.append("未勾选 \(excluded)") }
        if !draft.ignoredNonVocabularyLines.isEmpty { parts.append("未识别 \(draft.ignoredNonVocabularyLines.count) 行（在「已忽略」里选择加入）") }
        return parts.joined(separator: " · ")
    }

    private func filterPill(_ label: String, id: String) -> some View {
        Button {
            chooseFilter(id)
        } label: {
            Text(label)
        }
        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: filterMode == id, horizontalPadding: 12, height: 28))
    }
}

private struct ImportPreviewTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let ink: Color
    init(_ placeholder: String, text: Binding<String>, ink: Color) {
        self.placeholder = placeholder; _text = text; self.ink = ink
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.isBezeled = false; field.drawsBackground = false
        field.isEditable = true; field.isSelectable = true
        field.focusRingType = .none; field.usesSingleLineMode = true
        field.font = .systemFont(ofSize: 13.5)
        field.delegate = context.coordinator
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = placeholder; field.textColor = NSColor(ink)
        if field.currentEditor() == nil && field.stringValue != text { field.stringValue = text }
    }
    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ImportPreviewTextField
        init(_ parent: ImportPreviewTextField) { self.parent = parent }
        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField, let editor = field.currentEditor() as? NSTextView else { return }
            let count = editor.string.utf16.count
            if count > 0 && editor.selectedRange().length == count { editor.setSelectedRange(NSRange(location: count, length: 0)) }
        }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}
