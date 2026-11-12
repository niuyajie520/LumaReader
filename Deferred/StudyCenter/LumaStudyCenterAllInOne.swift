//
//  ExamEnglishInputModule.swift
//  LumaReaderStudyKit
//
//  Implements Section 五.A: Pure English, Zero-Autocorrect Exam Answer Editor
//  Targets: IELTS Task 1 / Task 2 Writing Practice, 60-Min Full Mock Exam,
//           and IELTS Reading Comprehension Answer Editors ONLY.
//  Does NOT alter global macOS input sources or affect book annotations, search, or AI chat.
//
//  Apple Native References:
//  - allowedInputSourceLocales: https://developer.apple.com/documentation/appkit/nstextview/allowedinputsourcelocales
//  - NSAllRomanInputSourcesLocaleIdentifier: https://developer.apple.com/documentation/appkit/nsallromaninputsourceslocaleidentifier
//  - NSTextView: https://developer.apple.com/documentation/appkit/nstextview
//  - textView(_:shouldChangeTextInRanges:replacementStrings:): https://developer.apple.com/documentation/appkit/nstextviewdelegate/textview(_:shouldchangetextinranges:replacementstrings:)
//  - NSWritingToolsBehavior.none: https://developer.apple.com/documentation/appkit/nswritingtoolsbehavior/none
//  - isAutomaticTextCompletionEnabled: https://developer.apple.com/documentation/appkit/nstextview/isautomatictextcompletionenabled
//

import Foundation
#if canImport(AppKit)
import AppKit
import SwiftUI
import Charts
#endif

// MARK: - 1. ExamScope (Trigger Boundary)

/// Defines the editor contexts in LumaReader to ensure strict English-only exam lock
/// applies exclusively to IELTS exam/practice answer editors.
public enum EditorInputScope: String, Sendable, Codable, CaseIterable {
    case ieltsWritingTask1Practice
    case ieltsWritingTask2Practice
    case ieltsWritingFullMockExam
    case ieltsReadingAnswerField
    // Unrestricted scopes (normal IME, spellcheck, Chinese input preserved):
    case bookReaderAnnotation
    case bookshelfSearch
    case bookshelfRename
    case cloudDriveSearch
    case aiCompanionChat

    public var requiresStrictExamEnglishMode: Bool {
        switch self {
        case .ieltsWritingTask1Practice,
             .ieltsWritingTask2Practice,
             .ieltsWritingFullMockExam,
             .ieltsReadingAnswerField:
            return true
        case .bookReaderAnnotation,
             .bookshelfSearch,
             .bookshelfRename,
             .cloudDriveSearch,
             .aiCompanionChat:
            return false
        }
    }
}

// MARK: - 2. ExamEnglishInputPolicy (Pure Value Type, Testable on Any Platform)

/// Validation decision returned by `ExamEnglishInputPolicy`.
public enum ExamInputValidationDecision: Equatable, Sendable {
    /// Replacement is permitted verbatim (including misspelled English like "teh", "enviroment", "I dont know").
    case allowVerbatim
    /// Replacement is rejected in its entirety; original draft remains untouched.
    case rejectEntirely(reason: RejectionReason, userBannerMessage: String)

    public enum RejectionReason: String, Equatable, Sendable {
        case containsCJKCharacters
        case containsFullWidthPunctuation
        case containsNonASCIIOrDisallowedScript
        case containsEmojiOrSymbol
    }
}

/// Legacy draft compatibility check result when opening an older draft in strict exam mode.
public struct LegacyDraftCompatibilityReport: Equatable, Sendable {
    public let containsLegacyNonEnglishCharacters: Bool
    public let offendingCharacterSamples: [String]
    public let warningBannerMessage: String?
}

/// Independent, stateless, unit-testable policy enforcing IELTS computer-delivered English input rules.
public nonisolated struct ExamEnglishInputPolicy: Sendable {

    public init() {}

    /// Permitted ASCII punctuation in IELTS computer-based writing/reading answers:
    /// `. , ; : ? ! ' " - ( ) [ ] / % & $ # @ + = * _ ~`
    private static let allowedPunctuationScalars: Set<Unicode.Scalar> = Set(
        #".,;:?!'"-()[]/%&$#@+=*_~`<>\|{}"#.unicodeScalars
    )

    /// Evaluates a single candidate replacement string (from typing, IME commit, paste, drag-drop, dictation, or undo/redo).
    /// - Important: Never strips Chinese characters silently to concatenate English, and never alters misspelled English.
    public func validateReplacement(_ replacement: String) -> ExamInputValidationDecision {
        // Deletions (empty replacement string) are always allowed
        if replacement.isEmpty {
            return .allowVerbatim
        }

        for scalar in replacement.unicodeScalars {
            // 1. Check CJK Unified Ideographs, Radicals, Pinyin/Bopomofo, Hangul, Kana
            if Self.isCJKScalar(scalar) {
                return .rejectEntirely(
                    reason: .containsCJKCharacters,
                    userBannerMessage: "当前为雅思纯英文答题模式，仅接收英文与半角标点，中文输入未写入草稿。"
                )
            }

            // 2. Check CJK / Full-width punctuation (e.g. ， 。 ； ： ？ ！ “ ” ‘ ’ （ ） 【 】 — … 、)
            if Self.isFullWidthOrCJKPunctuation(scalar) {
                return .rejectEntirely(
                    reason: .containsFullWidthPunctuation,
                    userBannerMessage: #"请使用英文半角标点（如 , . ; : ? ! ' " -），全角标点未写入草稿。"#
                )
            }

            // 3. Check Emoji or pictographic scalars
            if Self.isEmojiScalar(scalar) {
                return .rejectEntirely(
                    reason: .containsEmojiOrSymbol,
                    userBannerMessage: "考试答题区不支持表情符号或特殊图标。"
                )
            }

            // 4. Strict whitelist check: A-Z, a-z, 0-9, space, tab, newline/CR, or allowed half-width punctuation
            if !Self.isAllowedEnglishExamScalar(scalar) {
                return .rejectEntirely(
                    reason: .containsNonASCIIOrDisallowedScript,
                    userBannerMessage: "当前为雅思纯英文答题模式，非英文字符未写入草稿。"
                )
            }
        }

        return .allowVerbatim
    }

    /// Evaluates a batch of replacement strings (corresponding to `NSTextViewDelegate.textView(_:shouldChangeTextInRanges:replacementStrings:)`).
    /// If ANY replacement in a multi-cursor edit violates the policy, the entire edit operation is rejected atomically.
    public func validateBatchReplacements(_ replacements: [String]) -> ExamInputValidationDecision {
        for item in replacements {
            let decision = validateReplacement(item)
            if case .rejectEntirely = decision {
                return decision
            }
        }
        return .allowVerbatim
    }

    /// Inspects an existing saved draft without deleting or mutating any characters (Section 五.A.7 Data Compatibility).
    public func inspectLegacyDraft(_ draftText: String) -> LegacyDraftCompatibilityReport {
        var samples: [String] = []
        for scalar in draftText.unicodeScalars {
            if !Self.isAllowedEnglishExamScalar(scalar) {
                let s = String(scalar)
                if !samples.contains(s) && samples.count < 8 {
                    samples.append(s)
                }
            }
        }
        if samples.isEmpty {
            return LegacyDraftCompatibilityReport(
                containsLegacyNonEnglishCharacters: false,
                offendingCharacterSamples: [],
                warningBannerMessage: nil
            )
        } else {
            let sampleList = samples.joined(separator: " ")
            return LegacyDraftCompatibilityReport(
                containsLegacyNonEnglishCharacters: true,
                offendingCharacterSamples: samples,
                warningBannerMessage: "历史草稿包含非英文字符（\(sampleList)）。系统已为您完整保留原文与备份副本，请在交卷前手动修改或清理。"
            )
        }
    }

    /// Official IELTS word counter: counts whitespace-delimited tokens containing at least one alphanumeric character.
    /// Hyphenated words (e.g., "well-equipped") and contractions (e.g., "don't", "dont") count as 1 word.
    public func countIELTSWords(in text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        var count = 0
        for token in components where !token.isEmpty {
            if token.unicodeScalars.contains(where: { Self.isASCIIAlphanumeric($0) }) {
                count += 1
            }
        }
        return count
    }

    // MARK: - Scalar Classification Helpers

    public static func isASCIIAlphanumeric(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 0x30 && v <= 0x39) // 0-9
            || (v >= 0x41 && v <= 0x5A) // A-Z
            || (v >= 0x61 && v <= 0x7A) // a-z
    }

    public static func isAllowedEnglishExamScalar(_ s: Unicode.Scalar) -> Bool {
        if isASCIIAlphanumeric(s) { return true }
        // Standard whitespace: space (0x20), tab (0x09), newline (0x0A), carriage return (0x0D)
        if s.value == 0x20 || s.value == 0x09 || s.value == 0x0A || s.value == 0x0D {
            return true
        }
        return allowedPunctuationScalars.contains(s)
    }

    public static func isCJKScalar(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 0x4E00 && v <= 0x9FFF)   // CJK Unified Ideographs
            || (v >= 0x3400 && v <= 0x4DBF)   // CJK Unified Ideographs Extension A
            || (v >= 0x20000 && v <= 0x2CEAF) // CJK Extensions B-F
            || (v >= 0xF900 && v <= 0xFAFF)   // CJK Compatibility Ideographs
            || (v >= 0x2E80 && v <= 0x2FDF)   // CJK Radicals / Kangxi
            || (v >= 0x3100 && v <= 0x312F)   // Bopomofo
            || (v >= 0x3040 && v <= 0x30FF)   // Hiragana / Katakana
            || (v >= 0xAC00 && v <= 0xD7AF)   // Hangul Syllables
    }

    public static func isFullWidthOrCJKPunctuation(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 0x3000 && v <= 0x303F)   // CJK Symbols and Punctuation (。 ， 、 【 】)
            || (v >= 0xFF01 && v <= 0xFF60)   // Fullwidth ASCII variants (！ ， ． ： ； ？ （ ）)
            || (v >= 0xFE10 && v <= 0xFE6F)   // CJK Compatibility Forms / Small Form Variants
            || v == 0x2014                    // Em dash —
            || v == 0x2026                    // Horizontal ellipsis …
            || v == 0x2018 || v == 0x2019     // Curly single quotes ‘ ’
            || v == 0x201C || v == 0x201D     // Curly double quotes “ ”
    }

    public static func isEmojiScalar(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 0x1F300 && v <= 0x1FAFF)
            || (v >= 0x2600 && v <= 0x27BF)
            || v == 0xFE0F
    }
}

#if canImport(AppKit)

// MARK: - 3. ExamNSTextView (Controlled AppKit NSTextView Subclass)

/// Controlled AppKit `NSTextView` subclass that enforces Exam Mode:
/// 1. Restricts `allowedInputSourceLocales` to `[NSAllRomanInputSourcesLocaleIdentifier]` on focus and input context changes.
/// 2. Disables all spellchecking, grammar checking, auto-correction, smart quotes/dashes, completion, inline prediction, and Apple Writing Tools.
/// 3. Strips spellcheck/Writing Tools/Service items from the context menu and Touch Bar.
/// 4. Intercepts paste, drag-drop, dictation, and IME commit paths via `ExamEnglishInputPolicy`.
@MainActor
public final class ExamNSTextView: NSTextView {

    public var isExamModeEnabled: Bool = true {
        didSet {
            applyExamModeConfiguration()
        }
    }

    public let inputPolicy = ExamEnglishInputPolicy()

    /// Callback fired when non-English input is rejected so the parent view can show a non-intrusive toast.
    public var onInputRejected: ((String) -> Void)?

    /// Callback fired when the editor first gains focus in Exam Mode.
    public var onExamInputActivated: (() -> Void)?

    private var hasAnnouncedActivation = false

    public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        applyExamModeConfiguration()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyExamModeConfiguration()
    }

    /// Applies all documented AppKit lockdown settings for IELTS Exam Mode.
    public func applyExamModeConfiguration() {
        guard isExamModeEnabled else {
            allowedInputSourceLocales = nil
            return
        }

        // 1. Restrict input sources to Roman locales only (First line of defense)
        // Reference: https://developer.apple.com/documentation/appkit/nstextview/allowedinputsourcelocales
        allowedInputSourceLocales = [NSAllRomanInputSourcesLocaleIdentifier]

        // 2. Completely disable spelling, grammar, substitutions, and completions
        // Reference: https://developer.apple.com/documentation/appkit/nstextview
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        smartInsertDeleteEnabled = false
        isRichText = false
        importsGraphics = false
        allowsImageEditing = false
        usesFontPanel = false
        usesRuler = false
        usesInspectorBar = false
        allowsCharacterPickerTouchBarItem = false
        enabledTextCheckingTypes = 0

        // 3. Disable Apple Writing Tools & Inline Predictions (macOS 15+ / macOS 27 SDK)
        // Reference: https://developer.apple.com/documentation/appkit/nswritingtoolsbehavior/none
        if #available(macOS 15.0, *) {
            writingToolsBehavior = .none
            inlinePredictionType = .no
            mathExpressionCompletionType = .no
        }

        // 4. Clear any existing red spelling underline states in the layout manager
        if let storage = textStorage, storage.length > 0 {
            let fullRange = NSRange(location: 0, length: storage.length)
            setSpellingState(0, range: fullRange)
        }
    }

    // MARK: Focus & Input Context Restoration

    public override var acceptsFirstResponder: Bool {
        return isEditable
    }

    public override func mouseDown(with event: NSEvent) {
        if !isEditable {
            onInputRejected?("当前处于暂停状态，点击右上角时间按钮继续计时后方可打字。")
            return
        }
        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }
        super.mouseDown(with: event)
    }

    public override func keyDown(with event: NSEvent) {
        if !isEditable {
            onInputRejected?("当前处于暂停状态，点击右上角时间按钮继续计时后方可打字。")
            return
        }
        super.keyDown(with: event)
    }

    public override func becomeFirstResponder() -> Bool {
        guard isEditable else { return false }
        let became = super.becomeFirstResponder()
        if became && isExamModeEnabled {
            applyExamModeConfiguration()
            inputContext?.invalidateCharacterCoordinates()
            if !hasAnnouncedActivation {
                hasAnnouncedActivation = true
                onExamInputActivated?()
            }
        }
        return became
    }

    public override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned && isExamModeEnabled {
            // Safely discard any uncommitted IME marked text without altering committed essay text
            if hasMarkedText() {
                unmarkText()
            }
        }
        return resigned
    }

    /// Normalizes harmless macOS IME pre-edit separators (such as U+2006 Six-Per-Em Space inserted by macOS Simplified Pinyin
    /// between English syllables before pressing Return, or U+00A0 non-breaking space) so English typing never gets blocked
    /// even when the user's system input source is still on Pinyin.
    private func normalizeHarmlessIMESeparators(_ raw: String) -> String {
        guard !raw.isEmpty else { return raw }
        let hasCJK = raw.unicodeScalars.contains { ExamEnglishInputPolicy.isCJKScalar($0) }
        guard !hasCJK else { return raw }
        var out = ""
        out.reserveCapacity(raw.count)
        for scalar in raw.unicodeScalars {
            switch scalar.value {
            case 0x2006, 0x200B, 0xFEFF:
                // Strip macOS Pinyin syllable separator (U+2006) & zero-width spaces in English letter pre-edit
                continue
            case 0x00A0, 0x2000...0x2005, 0x2007...0x200A, 0x202F, 0x205F:
                out.append(" ")
            case 0x2018, 0x2019:
                out.append("'")
            case 0x201C, 0x201D:
                out.append("\"")
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    // MARK: IME Marked Text & Direct Insertion Interception

    /// Handles IME composition state (`NSTextInputClient`).
    /// Never deletes the existing essay during composition; blocks non-Roman IME pre-edit or discards invalid marked text safely.
    public override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        guard isEditable else {
            unmarkText()
            onInputRejected?("当前处于暂停状态，点击右上角时间按钮继续计时后方可打字。")
            return
        }
        guard isExamModeEnabled else {
            super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
            return
        }

        let rawPlain: String
        if let attr = string as? NSAttributedString {
            rawPlain = attr.string
        } else if let str = string as? String {
            rawPlain = str
        } else {
            rawPlain = ""
        }
        let plain = normalizeHarmlessIMESeparators(rawPlain)

        // If an IME attempts to place CJK or full-width characters into marked text, reject and unmark immediately
        let decision = inputPolicy.validateReplacement(plain)
        if case .rejectEntirely(_, let message) = decision {
            unmarkText()
            onInputRejected?(message)
            return
        }

        super.setMarkedText(plain, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    public override func insertText(_ string: Any, replacementRange: NSRange) {
        guard isEditable else {
            if hasMarkedText() { unmarkText() }
            onInputRejected?("当前处于暂停状态，点击右上角时间按钮继续计时后方可打字。")
            return
        }
        guard isExamModeEnabled else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        let rawPlain: String
        if let attr = string as? NSAttributedString {
            rawPlain = attr.string
        } else if let str = string as? String {
            rawPlain = str
        } else {
            return
        }
        let plain = normalizeHarmlessIMESeparators(rawPlain)

        let decision = inputPolicy.validateReplacement(plain)
        switch decision {
        case .allowVerbatim:
            super.insertText(plain, replacementRange: replacementRange)
        case .rejectEntirely(_, let message):
            if hasMarkedText() {
                unmarkText()
            }
            onInputRejected?(message)
        }
    }

    // MARK: Pasteboard, Completion, Spellcheck & Context Menu Lockdown

    public override func paste(_ sender: Any?) {
        guard isEditable else {
            onInputRejected?("当前处于暂停状态，点击右上角时间按钮继续计时后方可打字。")
            return
        }
        guard isExamModeEnabled else {
            super.paste(sender)
            return
        }
        guard let pasted = NSPasteboard.general.string(forType: .string) else { return }
        let normalized = normalizeHarmlessIMESeparators(pasted)
        let decision = inputPolicy.validateReplacement(normalized)
        switch decision {
        case .allowVerbatim:
            super.insertText(normalized, replacementRange: selectedRange())
        case .rejectEntirely(_, let message):
            onInputRejected?(message)
        }
    }

    public override func pasteAsRichText(_ sender: Any?) {
        // Force plain-text paste validation in Exam Mode
        paste(sender)
    }

    public override func complete(_ sender: Any?) {
        // Block word-completion popups in Exam Mode
        if isExamModeEnabled { return }
        super.complete(sender)
    }

    public override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
        if isExamModeEnabled { return nil }
        return super.completions(forPartialWordRange: charRange, indexOfSelectedItem: index)
    }

    public override func checkTextInDocument(_ sender: Any?) {
        if isExamModeEnabled { return }
        super.checkTextInDocument(sender)
    }

    public override func checkTextInSelection(_ sender: Any?) {
        if isExamModeEnabled { return }
        super.checkTextInSelection(sender)
    }

    public override func showGuessPanel(_ sender: Any?) {
        if isExamModeEnabled { return }
        super.showGuessPanel(sender)
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        guard let baseMenu = super.menu(for: event), isExamModeEnabled else {
            return super.menu(for: event)
        }
        // Only keep Cut, Copy, Paste, Select All, Undo, Redo in Exam Mode; remove Spelling, Substitutions, Writing Tools, Services, Look Up
        let allowedSelectors: Set<Selector> = [
            #selector(cut(_:)),
            #selector(copy(_:)),
            #selector(paste(_:)),
            #selector(pasteAsPlainText(_:)),
            #selector(selectAll(_:)),
            Selector(("undo:")),
            Selector(("redo:"))
        ]
        let filteredMenu = NSMenu(title: "Exam Editor")
        for item in baseMenu.items {
            if let action = item.action, allowedSelectors.contains(action) {
                if let copied = item.copy() as? NSMenuItem {
                    filteredMenu.addItem(copied)
                }
            }
        }
        return filteredMenu
    }
}

// MARK: - 4. ExamEnglishTextEditor (SwiftUI NSViewRepresentable Bridge)

/// SwiftUI wrapper embedding `ExamNSTextView` with `NSTextViewDelegate` enforcement.
public struct ExamEnglishTextEditor: NSViewRepresentable {
    @Environment(\.lumaTextScale) private var textScale
    private var scaledFont: NSFont { NSFont(name: "Georgia", size: fontSize * textScale) ?? NSFont.systemFont(ofSize: fontSize * textScale) }
    @Environment(\.studyAppearance) private var appearance
    @Binding public var text: String
    public var scope: EditorInputScope
    public var isEditable: Bool
    public var fontSize: CGFloat
    public var onInputRejected: ((String) -> Void)?
    public var onExamInputActivated: (() -> Void)?

    public init(
        text: Binding<String>,
        scope: EditorInputScope = .ieltsWritingFullMockExam,
        isEditable: Bool = true,
        fontSize: CGFloat = 15.0,
        onInputRejected: ((String) -> Void)? = nil,
        onExamInputActivated: (() -> Void)? = nil
    ) {
        self._text = text
        self.scope = scope
        self.isEditable = isEditable
        self.fontSize = fontSize
        self.onInputRejected = onInputRejected
        self.onExamInputActivated = onExamInputActivated
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let initialRect = NSRect(x: 0, y: 0, width: 560, height: 640)
        let scrollView = NSScrollView(frame: initialRect)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = NSSize(
            width: max(320, scrollView.contentSize.width),
            height: max(360, scrollView.contentSize.height)
        )
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = ExamNSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 260, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.font = scaledFont
        textView.textColor = NSColor(appearance.ink)
        textView.insertionPointColor = NSColor(appearance.accent)
        textView.allowsUndo = true
        textView.isSelectable = true
        textView.isEditable = isEditable
        textView.isExamModeEnabled = scope.requiresStrictExamEnglishMode
        textView.delegate = context.coordinator
        textView.onInputRejected = onInputRejected
        textView.onExamInputActivated = onExamInputActivated
        textView.string = text
        textView.applyExamModeConfiguration()

        scrollView.documentView = textView

        if isEditable {
            DispatchQueue.main.async {
                if let win = textView.window, win.firstResponder !== textView {
                    win.makeFirstResponder(textView)
                }
            }
        }
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? ExamNSTextView else { return }
        if textView.font != scaledFont { textView.font = scaledFont }

        let targetWidth = max(260, scrollView.contentSize.width)
        let targetHeight = max(260, scrollView.contentSize.height)
        if abs(textView.frame.width - targetWidth) > 1 {
            var f = textView.frame
            f.size.width = targetWidth
            if f.size.height < targetHeight { f.size.height = targetHeight }
            textView.frame = f
            textView.textContainer?.containerSize = NSSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
        }

        if textView.isExamModeEnabled != scope.requiresStrictExamEnglishMode {
            textView.isExamModeEnabled = scope.requiresStrictExamEnglishMode
        }
        let wasEditable = textView.isEditable
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
            if !isEditable {
                if textView.hasMarkedText() { textView.unmarkText() }
                if textView.window?.firstResponder === textView {
                    textView.window?.makeFirstResponder(nil)
                }
            } else if !wasEditable && isEditable {
                DispatchQueue.main.async {
                    textView.window?.makeFirstResponder(textView)
                }
            }
        }
        textView.onInputRejected = onInputRejected
        textView.onExamInputActivated = onExamInputActivated
        textView.textColor = NSColor(appearance.ink)
        textView.insertionPointColor = NSColor(appearance.accent)

        // Re-assert Exam Mode settings across Part toggles, pause/resume, or draft restoration
        if scope.requiresStrictExamEnglishMode {
            textView.applyExamModeConfiguration()
        }

        if textView.string != text && !textView.hasMarkedText() {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ExamEnglishTextEditor
        let policy = ExamEnglishInputPolicy()

        init(parent: ExamEnglishTextEditor) {
            self.parent = parent
        }

        /// Final editing boundary check:
        /// Reference: https://developer.apple.com/documentation/appkit/nstextviewdelegate/textview(_:shouldchangetextinranges:replacementstrings:)
        public func textView(
            _ textView: NSTextView,
            shouldChangeTextInRanges affectedRanges: [NSValue],
            replacementStrings: [String]?
        ) -> Bool {
            guard parent.isEditable else {
                parent.onInputRejected?("当前处于暂停状态，点击右上角时间按钮继续计时后方可打字。")
                return false
            }
            guard parent.scope.requiresStrictExamEnglishMode,
                  let replacements = replacementStrings else {
                return true
            }

            let decision = policy.validateBatchReplacements(replacements)
            switch decision {
            case .allowVerbatim:
                return true
            case .rejectEntirely(_, let bannerMessage):
                parent.onInputRejected?(bannerMessage)
                return false
            }
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if !textView.hasMarkedText() {
                parent.text = textView.string
            }
        }
    }
}
#endif


//
//  StudyModelsAndPersistence.swift
//  LumaReaderStudyKit
//
//  Forward-compatible persistence models, automatic backup before migration,
//  and non-destructive schema evolution (Section 一.4, 四.5-6, 五, 六, 七).
//

import Foundation

// MARK: - Schema Version & Migration Manifest

public enum StudySchemaVersion: Int, Codable, Comparable, Sendable {
    case v1_initial = 1
    case v2_examEnglishAndStubbornWords = 2

    public static let current: StudySchemaVersion = .v2_examEnglishAndStubbornWords

    public static func < (lhs: StudySchemaVersion, rhs: StudySchemaVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Sidebar Navigation State (Section 三)

public struct SidebarExpansionState: Codable, Equatable, Sendable {
    public var isBookshelfExpanded: Bool
    public var isBookshelfCategoriesExpanded: Bool
    public var isStudyExpanded: Bool
    public var isListeningSubgroupExpanded: Bool
    public var isWritingSubgroupExpanded: Bool
    public var isCloudDriveExpanded: Bool
    public var selectedDestination: SidebarDestination

    public init(
        isBookshelfExpanded: Bool = true,
        isBookshelfCategoriesExpanded: Bool = true,
        isStudyExpanded: Bool = true,
        isListeningSubgroupExpanded: Bool = false,
        isWritingSubgroupExpanded: Bool = true,
        isCloudDriveExpanded: Bool = false,
        selectedDestination: SidebarDestination = .bookshelfAll
    ) {
        self.isBookshelfExpanded = isBookshelfExpanded
        self.isBookshelfCategoriesExpanded = isBookshelfCategoriesExpanded
        self.isStudyExpanded = isStudyExpanded
        self.isListeningSubgroupExpanded = isListeningSubgroupExpanded
        self.isWritingSubgroupExpanded = isWritingSubgroupExpanded
        self.isCloudDriveExpanded = isCloudDriveExpanded
        self.selectedDestination = selectedDestination
    }
}

public enum SidebarDestination: String, Codable, CaseIterable, Sendable {
    // 1. 书架 (Bookshelf - integrates former "阅读/继续阅读" entry)
    case bookshelfAll
    case bookshelfReadingNow
    case bookshelfFinished
    case bookshelfAnnotations
    case bookshelfReadingStats
    // 2. 学习 - 听力 (Study -> Listening)
    case listeningHome
    case listeningTodayPlan
    case listeningMyDecks
    case listeningWrongWordsReview
    case listeningStubbornWords
    case listeningRecords
    // 2. 学习 - 写作 (Study -> Writing)
    case writingMockExam
    case writingTask1Bank
    case writingTask2Bank
    case writingHistory
    case writingScoringFeedback
    // 2. 学习 - 学习统计 (Study -> Statistics)
    case studyStatistics
    // 3. 云盘 (Cloud Drive)
    case cloudDriveHome
}

// MARK: - Listening & Vocabulary Models (Section 四)

public enum DictationSessionMode: String, Codable, Sendable {
    case newTask = "new_task"
    case wrongWordReview = "wrong_word_review"
    case stubbornWordReview = "stubborn_word_review"
    case slowReactionReview = "slow_reaction_review"
}

/// 听写反应时长追踪记录：虽然拼写正确但从语音播完到敲下回车犹豫超过 5.0 秒的「慢反应词」
public struct SlowReactionWordRecord: Codable, Equatable, Identifiable, Sendable {
    public static let slowThresholdSeconds: Double = 5.0
    public var id: String { wordID }
    public let wordID: String
    public let word: String
    public var definitionZH: String
    public let sourceDeckID: String
    public let sourceDeckTitle: String
    public var lastReactionSeconds: Double
    public var maxReactionSeconds: Double
    public var bestReactionSeconds: Double?
    public var slowCount: Int
    public var dateString: String
    public var updatedAt: Date

    public init(
        wordID: String,
        word: String,
        definitionZH: String,
        sourceDeckID: String,
        sourceDeckTitle: String,
        lastReactionSeconds: Double,
        maxReactionSeconds: Double? = nil,
        bestReactionSeconds: Double? = nil,
        slowCount: Int = 1,
        dateString: String,
        updatedAt: Date = Date()
    ) {
        self.wordID = wordID
        self.word = word
        self.definitionZH = definitionZH
        self.sourceDeckID = sourceDeckID
        self.sourceDeckTitle = sourceDeckTitle
        self.lastReactionSeconds = lastReactionSeconds
        self.maxReactionSeconds = maxReactionSeconds ?? lastReactionSeconds
        self.bestReactionSeconds = bestReactionSeconds
        self.slowCount = slowCount
        self.dateString = dateString
        self.updatedAt = updatedAt
    }
}

public struct VocabularyWord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let word: String
    public let phoneticUK: String
    public let phoneticUS: String
    public let partOfSpeech: String
    public let definitionZH: String
    public let exampleSentence: String
    public let deckID: String
    public let deckTitle: String
    /// Optional explicit three-level folder path (e.g. 剑桥20/第5章/5.3-2).
    /// Imported datasets can preserve their original workbook hierarchy without
    /// depending on the deck-title heuristic.
    public var folderPath: [String]? = nil

    public init(
        id: String,
        word: String,
        phoneticUK: String = "",
        phoneticUS: String = "",
        partOfSpeech: String = "",
        definitionZH: String,
        exampleSentence: String = "",
        deckID: String,
        deckTitle: String,
        folderPath: [String]? = nil
    ) {
        self.id = id
        self.word = word
        self.phoneticUK = phoneticUK
        self.phoneticUS = phoneticUS
        self.partOfSpeech = partOfSpeech
        self.definitionZH = definitionZH
        self.exampleSentence = exampleSentence
        self.deckID = deckID
        self.deckTitle = deckTitle
        self.folderPath = folderPath
    }
}

public struct StubbornWordRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(wordID)_\(dateString)" }
    public let wordID: String
    public let word: String
    public let sourceDeckID: String
    public let sourceDeckTitle: String
    public let dateString: String // YYYY-MM-DD in local timezone
    public var errorCount: Int
    public let triggeringSessionID: UUID

    public init(
        wordID: String,
        word: String,
        sourceDeckID: String,
        sourceDeckTitle: String,
        dateString: String,
        errorCount: Int,
        triggeringSessionID: UUID
    ) {
        self.wordID = wordID
        self.word = word
        self.sourceDeckID = sourceDeckID
        self.sourceDeckTitle = sourceDeckTitle
        self.dateString = dateString
        self.errorCount = errorCount
        self.triggeringSessionID = triggeringSessionID
    }
}

public struct DictationAttemptLog: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let mode: DictationSessionMode
    public let wordID: String
    public let word: String
    public let deckID: String
    public let userTyped: String
    public let isCorrect: Bool
    public let isFirstAttemptInSession: Bool
    public let sessionErrorCountForWord: Int
    public let timestamp: Date
    public let dateString: String // YYYY-MM-DD
    public let durationSeconds: Double
    public var isSlowReaction: Bool {
        isCorrect && durationSeconds > SlowReactionWordRecord.slowThresholdSeconds
    }
}

// MARK: - IELTS Task 1 & Task 2 Question Bank Models (Section 六)

public enum Task1ChartCategory: String, Codable, CaseIterable, Sendable {
    case all = "全部"
    case lineGraph = "折线图"
    case barChart = "柱状图"
    case pieChart = "饼图"
    case table = "表格"
    case map = "地图"
    case processDiagram = "流程图"
    case mixedChart = "组合图"

    /// Filter bar order on Task 1 Home (strictly matches Section 三 requirement)
    public static let homeFilterBarCategories: [Task1ChartCategory] = [
        .all, .lineGraph, .barChart, .pieChart, .table, .map, .processDiagram
    ]
}

public enum QuestionLicenseStatus: String, Codable, Sendable {
    /// Original question & self-authored chart created specifically for LumaReader (100% redistributable offline)
    case originalSelfAuthored = "original_self_authored"
    /// Verified open license allowing offline redistribution
    case verifiedOpenRedistribution = "verified_open_redistribution"
    /// Candidate topic index only (unverified copyright or paywalled details; hidden from user practice grid)
    case pendingVerification = "pending_verification"

    public var isReadyForUserPractice: Bool {
        switch self {
        case .originalSelfAuthored, .verifiedOpenRedistribution:
            return true
        case .pendingVerification:
            return false
        }
    }
}

public struct ChartSeries: Codable, Equatable, Sendable {
    public let name: String
    public let unit: String
    public let values: [Double]

    public init(name: String, unit: String, values: [Double]) {
        self.name = name
        self.unit = unit
        self.values = values
    }
}

public struct MapStageFeature: Codable, Equatable, Sendable {
    public let label: String
    public let region: String // e.g. "North", "Center", "West", "South", "East"
    public let status: String // e.g. "retained", "added", "removed", "expanded"
}

public struct MapComparisonPayload: Codable, Equatable, Sendable {
    public let beforeYearLabel: String
    public let afterYearLabel: String
    public let beforeFeatures: [MapStageFeature]
    public let afterFeatures: [MapStageFeature]
}

public struct ProcessStepPayload: Codable, Equatable, Sendable {
    public let stepNumber: Int
    public let title: String
    public let detail: String
    public let nextStepNumber: Int?
}

public struct Task1ChartDataset: Codable, Equatable, Sendable {
    public let xAxisLabels: [String] // Ordered time points or categories
    public let series: [ChartSeries]
    public let pieSlicePercentages: [String: Double]? // Sum must equal 100.0 (±0.1)
    public let tableRowTotals: [Double]?
    public let mapComparison: MapComparisonPayload?
    public let processSteps: [ProcessStepPayload]?
}

public struct Task1QuestionItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let shortTitle: String
    public let category: Task1ChartCategory
    public let difficultyBand: String
    public let promptText: String
    public let minimumWords: Int
    public let recommendedMinutes: Int
    public let sourceName: String
    public let sourceURL: String
    public let licenseStatus: QuestionLicenseStatus
    public let chartDataset: Task1ChartDataset?
    public let companionTask2ID: String?
    public let companionTask2Prompt: String?
    public let notes: String?

    /// A card may only appear on the user's Task 1 practice grid if it has a valid license,
    /// non-empty prompt text, and a verified chart dataset.
    public var isPracticeableOnUserGrid: Bool {
        guard licenseStatus.isReadyForUserPractice else { return false }
        guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let dataset = chartDataset else { return false }
        return QuestionBankGatekeeper.validateDataset(dataset, for: category).isValid
    }
}

public enum LumaTask1DefaultDataset {
    public static func make(for category: Task1ChartCategory) -> Task1ChartDataset {
        switch category {
        case .pieChart:
            return Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: ["Category A": 40, "Category B": 35, "Category C": 25],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            )
        case .map:
            return Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeYearLabel: "Before",
                    afterYearLabel: "After",
                    beforeFeatures: [MapStageFeature(label: "Original zone", region: "Center", status: "retained")],
                    afterFeatures: [MapStageFeature(label: "New facility", region: "North", status: "added")]
                ),
                processSteps: nil
            )
        case .processDiagram:
            return Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Stage 1", detail: "Initial preparation and input collection.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Stage 2", detail: "Main processing and transformation.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Stage 3", detail: "Final quality check and distribution.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Stage 4", detail: "Commercial delivery.", nextStepNumber: nil)
                ]
            )
        default:
            return Task1ChartDataset(
                xAxisLabels: ["2015", "2020", "2025"],
                series: [
                    ChartSeries(name: "Group A", unit: "%", values: [25, 42, 58]),
                    ChartSeries(name: "Group B", unit: "%", values: [48, 39, 31])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            )
        }
    }
}

public struct LumaTask2TopicItem: Codable, Equatable, Identifiable, Hashable, Sendable {
    public var id: String
    public var shortTitle: String
    /// 八大核心主题（教育 / 科技 / 环境 / 社会 / 政府 / 媒体 / 文化 / 工作）或用户自定义分类
    public var category: String
    /// 细分主题标签
    public var subCategory: String
    public var promptText: String
    public var positivePoints: [String]
    public var negativePoints: [String]
    public var examDate: String?
    public var notes: String?
    public var isUserCreated: Bool

    public static let eightMajorCategories: [String] = [
        "教育", "科技", "环境", "社会", "政府", "媒体", "文化", "工作"
    ]

    public static func symbolName(for category: String) -> String {
        switch category {
        case "全部": return "square.grid.2x2"
        case "教育": return "graduationcap"
        case "科技": return "cpu"
        case "环境": return "leaf"
        case "社会": return "person.3"
        case "政府": return "building.columns"
        case "媒体": return "newspaper"
        case "文化": return "theatermasks"
        case "工作": return "briefcase"
        case "健康": return "heart.text.square"
        case "犯罪": return "shield.lefthalf.filled"
        case "国际": return "globe.asia.australia"
        case "旅游": return "airplane"
        default: return "tag"
        }
    }

    public init(
        id: String,
        shortTitle: String,
        category: String,
        subCategory: String = "",
        promptText: String,
        positivePoints: [String] = [],
        negativePoints: [String] = [],
        examDate: String? = nil,
        notes: String? = nil,
        isUserCreated: Bool = false
    ) {
        self.id = id
        self.shortTitle = shortTitle
        self.category = category
        self.subCategory = subCategory.isEmpty ? category : subCategory
        self.promptText = promptText
        self.positivePoints = positivePoints
        self.negativePoints = negativePoints
        self.examDate = examDate
        self.notes = notes
        self.isUserCreated = isUserCreated
    }

    public var formattedReferenceNotes: String? {
        var sections: [String] = []
        if !positivePoints.isEmpty {
            sections.append("【正面 / 支持论点搭配】\n" + positivePoints.map { "• " + $0 }.joined(separator: "\n"))
        }
        if !negativePoints.isEmpty {
            sections.append("【负面 / 反对论点搭配】\n" + negativePoints.map { "• " + $0 }.joined(separator: "\n"))
        }
        if let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("【写作备注】\n" + notes)
        }
        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    public func asExamQuestionItem(fallbackTask1: Task1QuestionItem) -> Task1QuestionItem {
        Task1QuestionItem(
            id: id,
            shortTitle: shortTitle,
            category: fallbackTask1.category,
            difficultyBand: "Band 6.5-8.0",
            promptText: fallbackTask1.promptText,
            minimumWords: 250,
            recommendedMinutes: 40,
            sourceName: isUserCreated ? "Luma 自定义题库" : "雅思大作文 200 题机经与专属搭配库",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: fallbackTask1.chartDataset,
            companionTask2ID: id,
            companionTask2Prompt: promptText,
            notes: formattedReferenceNotes
        )
    }
}

// MARK: - Writing Draft, Submission & AI Feedback Models (Section 五)

public enum ExamPart: Int, Codable, CaseIterable, Sendable {
    case part1 = 1
    case part2 = 2
}

public struct WritingExamDraftState: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let questionID: String
    public let examTitle: String
    public var activePart: ExamPart
    public var part1EssayText: String
    public var part2EssayText: String
    public var remainingSeconds: Int // Global 60-minute (3600s) countdown
    public var elapsedSeconds: Int
    public var isPaused: Bool
    public var isSingleTaskMode: Bool
    public var lastSavedAt: Date
    public var containsLegacyNonEnglishNotice: Bool
    public var promptHighlights: [Int: [StudyTextHighlight]]? = nil
}

public struct IELTSFourCriteriaEstimate: Codable, Equatable, Sendable {
    public let taskAchievementOrResponse: Double
    public let coherenceAndCohesion: Double
    public let lexicalResource: Double
    public let grammaticalRangeAndAccuracy: Double
    public let overallEstimatedBand: Double
    public let officialDisclaimer: String
    public let sentenceCorrections: [SentenceCorrectionItem]

    public struct SentenceCorrectionItem: Codable, Equatable, Sendable {
        public let originalSentence: String
        public let correctedSentence: String
        public let explanationZH: String
        public let upgradedExpression: String
        public var kind: String? = nil
    }
}

public struct WritingSubmissionRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let draftSessionID: UUID
    public let questionID: String
    public let examTitle: String
    public let part1EssayText: String
    public let part2EssayText: String
    public let part1WordCount: Int
    public let part2WordCount: Int
    public let durationSeconds: Int
    public let submittedAt: Date
    public let dateString: String // YYYY-MM-DD
    public var aiEvaluation: IELTSFourCriteriaEstimate?
}

// MARK: - Forward-Compatible Store Container & Migration Manager (Section 一.4)

public struct StudyStoreSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: StudySchemaVersion
    public var sidebarState: SidebarExpansionState
    public var selectedVoiceIdentifier: String?
    public var preferredAccent: String // "en-GB" or "en-US"
    public var preferredSpeechRate: Float // 0.85 ... 1.80 (1.0x default)
    public var speechRepeatCount: Int?
    public var speechInterval: Double?
    public var dictationLogs: [DictationAttemptLog]
    public var stubbornWords: [StubbornWordRecord]
    public var activeWritingDrafts: [String: WritingExamDraftState]
    public var legacyDraftBackups: [String: String]
    public var writingSubmissions: [WritingSubmissionRecord]
    public var importedWords: [VocabularyWord]?
    public var installedVocabularyPackIDs: [String]?
    public var reviewSchedule: [String: WordReviewProgress]?
    public var writingRevisions: [WritingRevision]?
    public var speechService: SpeechServiceSettings?
    public var workspace: StudyWorkspaceState?
    public var dictationSession: DictationSessionStateMachine?
    public var dictationSessions: [String: DictationSessionStateMachine]?
    public var slowReactionWords: [SlowReactionWordRecord]?
    public var dailyReadingSeconds: [String: Int]?
    public var customTask2Topics: [LumaTask2TopicItem]?
    public var deletedTask2TopicIDs: [String]?
    public var customTask2Categories: [String]?
    public var customTask1Questions: [Task1QuestionItem]?
    public var deletedTask1QuestionIDs: [String]?

    public init(
        schemaVersion: StudySchemaVersion = .current,
        sidebarState: SidebarExpansionState = SidebarExpansionState(),
        selectedVoiceIdentifier: String? = nil,
        preferredAccent: String = "en-GB",
        preferredSpeechRate: Float = 1.0,
        speechRepeatCount: Int? = 1,
        speechInterval: Double? = 0.5,
        dictationLogs: [DictationAttemptLog] = [],
        stubbornWords: [StubbornWordRecord] = [],
        activeWritingDrafts: [String: WritingExamDraftState] = [:],
        legacyDraftBackups: [String: String] = [:],
        writingSubmissions: [WritingSubmissionRecord] = [],
        importedWords: [VocabularyWord]? = nil,
        installedVocabularyPackIDs: [String]? = nil,
        reviewSchedule: [String: WordReviewProgress]? = nil,
        writingRevisions: [WritingRevision]? = nil,
        speechService: SpeechServiceSettings? = nil,
        workspace: StudyWorkspaceState? = nil,
        dictationSession: DictationSessionStateMachine? = nil,
        dictationSessions: [String: DictationSessionStateMachine]? = nil,
        slowReactionWords: [SlowReactionWordRecord]? = nil,
        dailyReadingSeconds: [String: Int]? = nil,
        customTask2Topics: [LumaTask2TopicItem]? = nil,
        deletedTask2TopicIDs: [String]? = nil,
        customTask2Categories: [String]? = nil,
        customTask1Questions: [Task1QuestionItem]? = nil,
        deletedTask1QuestionIDs: [String]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.sidebarState = sidebarState
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
        self.preferredAccent = preferredAccent
        self.preferredSpeechRate = preferredSpeechRate
        self.speechRepeatCount = speechRepeatCount
        self.speechInterval = speechInterval
        self.dictationLogs = dictationLogs
        self.stubbornWords = stubbornWords
        self.activeWritingDrafts = activeWritingDrafts
        self.legacyDraftBackups = legacyDraftBackups
        self.writingSubmissions = writingSubmissions
        self.importedWords = importedWords
        self.installedVocabularyPackIDs = installedVocabularyPackIDs
        self.reviewSchedule = reviewSchedule
        self.writingRevisions = writingRevisions
        self.speechService = speechService
        self.workspace = workspace
        self.dictationSession = dictationSession
        self.dictationSessions = dictationSessions
        self.slowReactionWords = slowReactionWords
        self.dailyReadingSeconds = dailyReadingSeconds
        self.customTask2Topics = customTask2Topics
        self.deletedTask2TopicIDs = deletedTask2TopicIDs
        self.customTask2Categories = customTask2Categories
        self.customTask1Questions = customTask1Questions
        self.deletedTask1QuestionIDs = deletedTask1QuestionIDs
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, sidebarState, selectedVoiceIdentifier, preferredAccent, preferredSpeechRate, speechRepeatCount, speechInterval, dictationLogs, stubbornWords, activeWritingDrafts, legacyDraftBackups, writingSubmissions, importedWords, installedVocabularyPackIDs, reviewSchedule, writingRevisions, speechService, workspace, dictationSession, dictationSessions, slowReactionWords, dailyReadingSeconds, customTask2Topics, deletedTask2TopicIDs, customTask2Categories, customTask1Questions, deletedTask1QuestionIDs }
    public init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        self.init(
            schemaVersion: try c.decodeIfPresent(StudySchemaVersion.self, forKey:.schemaVersion) ?? .v1_initial,
            sidebarState: try c.decodeIfPresent(SidebarExpansionState.self, forKey:.sidebarState) ?? SidebarExpansionState(),
            selectedVoiceIdentifier: try c.decodeIfPresent(String.self, forKey:.selectedVoiceIdentifier),
            preferredAccent: try c.decodeIfPresent(String.self, forKey:.preferredAccent) ?? "en-GB",
            preferredSpeechRate: try c.decodeIfPresent(Float.self, forKey:.preferredSpeechRate) ?? 1.0,
            speechRepeatCount: try c.decodeIfPresent(Int.self, forKey:.speechRepeatCount),
            speechInterval: try c.decodeIfPresent(Double.self, forKey:.speechInterval),
            dictationLogs: try c.decodeIfPresent([DictationAttemptLog].self, forKey:.dictationLogs) ?? [],
            stubbornWords: try c.decodeIfPresent([StubbornWordRecord].self, forKey:.stubbornWords) ?? [],
            activeWritingDrafts: try c.decodeIfPresent([String:WritingExamDraftState].self, forKey:.activeWritingDrafts) ?? [:],
            legacyDraftBackups: try c.decodeIfPresent([String:String].self, forKey:.legacyDraftBackups) ?? [:],
            writingSubmissions: try c.decodeIfPresent([WritingSubmissionRecord].self, forKey:.writingSubmissions) ?? [],
            importedWords: try c.decodeIfPresent([VocabularyWord].self, forKey:.importedWords),
            installedVocabularyPackIDs: try c.decodeIfPresent([String].self, forKey:.installedVocabularyPackIDs),
            reviewSchedule: try c.decodeIfPresent([String:WordReviewProgress].self, forKey:.reviewSchedule),
            writingRevisions: try c.decodeIfPresent([WritingRevision].self, forKey:.writingRevisions),
            speechService: try c.decodeIfPresent(SpeechServiceSettings.self, forKey:.speechService),
            workspace: try c.decodeIfPresent(StudyWorkspaceState.self, forKey:.workspace),
            dictationSession: try c.decodeIfPresent(DictationSessionStateMachine.self, forKey:.dictationSession),
            dictationSessions: try c.decodeIfPresent([String:DictationSessionStateMachine].self, forKey:.dictationSessions),
            slowReactionWords: try c.decodeIfPresent([SlowReactionWordRecord].self, forKey:.slowReactionWords),
            dailyReadingSeconds: try c.decodeIfPresent([String:Int].self, forKey:.dailyReadingSeconds),
            customTask2Topics: try c.decodeIfPresent([LumaTask2TopicItem].self, forKey:.customTask2Topics),
            deletedTask2TopicIDs: try c.decodeIfPresent([String].self, forKey:.deletedTask2TopicIDs),
            customTask2Categories: try c.decodeIfPresent([String].self, forKey:.customTask2Categories),
            customTask1Questions: try c.decodeIfPresent([Task1QuestionItem].self, forKey:.customTask1Questions),
            deletedTask1QuestionIDs: try c.decodeIfPresent([String].self, forKey:.deletedTask1QuestionIDs)
        )
    }

}

//
//  ListeningAndTTSEngine.swift
//  LumaReaderStudyKit
//
//  Implements Section 四:
//  - Female-first natural voice selection & pluggable TTS engine (System Premium / Kokoro-82M / Fallback at 1.0x)
//  - 5-strike wrong-word spaced insertion loop & stubborn-word quarantine
//  - Strict per-session (`session_id` / `mode`) error counting
//

import Foundation
#if canImport(AVFAudio)
import AVFAudio
#endif

// MARK: - 1. Pluggable TTS Engine Protocol & Female-First Voice Selector

public enum TTSVoiceAccent: String, Codable, CaseIterable, Sendable {
    case british = "en-GB"
    case american = "en-US"
}

public enum TTSEngineTier: String, Codable, Sendable {
    case localNeuralKokoro = "kokoro_local_neural"
    case applePremiumOrEnhanced = "apple_premium_enhanced"
    case appleStandardMechanicalFallback = "apple_standard_fallback"
}

public struct TTSVoiceDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let localeIdentifier: String
    public let isFemale: Bool
    public let tier: TTSEngineTier
}

public protocol SpeechSynthesisEngine: Sendable {
    func availableVoices(for accent: TTSVoiceAccent) -> [TTSVoiceDescriptor]
    func selectBestFemaleVoice(preferredVoiceID: String?, accent: TTSVoiceAccent) -> TTSVoiceDescriptor
    @MainActor func speak(text: String, voice: TTSVoiceDescriptor, requestedRate: Float)
    @MainActor func stop()
}

/// Default macOS Speech Synthesis Engine prioritizing natural female voices and full playback speed control:
/// 1. Prioritizes installed Apple Premium / Enhanced female voices; no bundled neural model is claimed.
/// 2. Falls back across English locales (`en-GB` <-> `en-US`) if the user's Mac only has one English locale installed, preventing false "没有已安装的英语女声" errors.
/// 3. Honours all user playback speed multipliers (`0.85x`, `1.0x`, `1.15x`, `1.5x`, `1.8x`) across all voice tiers.
public final class MacOSSpeechSynthesisManager: SpeechSynthesisEngine, @unchecked Sendable {

    /// Known natural female voice names in macOS (`en-GB`, `en-US`, `en-AU`, `en-IE`, `en-IN`, `en-ZA`)
    public static let knownFemaleVoiceNames: Set<String> = [
        "Serena", "Kate", "Stephanie", "Martha", "Fiona",
        "Samantha", "Ava", "Allison", "Susan", "Zoe", "Nicky", "Victoria",
        "Karen", "Moira", "Tessa", "Veena", "Flo", "Shelley", "Sandy", "Kathy", "Ellen",
        "Af_Heart", "Af_Bella", "Af_Sarah", "Bf_Emma", "Bf_Isabella"
    ]

    /// Novelty/mechanical voices that should never be selected as a female English voice
    public static let noveltyVoiceNames: Set<String> = [
        "Fred", "Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles",
        "Cellos", "Deranged", "Good News", "Hysterical", "Junior", "Organ",
        "Superstar", "Ralph", "Trinoids", "Whisper", "Wobble", "Zarvox", "Jester"
    ]

    public init() {}

    public func availableVoices(for accent: TTSVoiceAccent) -> [TTSVoiceDescriptor] {
        #if canImport(AVFAudio)
        let allSystemVoices = AVSpeechSynthesisVoice.speechVoices()
        var allEnglishFemale: [TTSVoiceDescriptor] = []
        for v in allSystemVoices where v.language.lowercased().hasPrefix("en") {
            if Self.noveltyVoiceNames.contains(where: { v.name.localizedCaseInsensitiveContains($0) }) {
                continue
            }
            if v.gender == .male {
                continue
            }
            let isKokoro = false // No verified Kokoro inference engine is integrated.
            let isKnownFemaleName = Self.knownFemaleVoiceNames.contains(where: { v.name.localizedCaseInsensitiveContains($0) })
            let isFemale = (v.gender == .female) || isKnownFemaleName
            guard isFemale else { continue }

            let tier: TTSEngineTier
            if isKokoro {
                tier = .localNeuralKokoro
            } else if v.quality == .premium || v.quality == .enhanced {
                tier = .applePremiumOrEnhanced
            } else {
                tier = .appleStandardMechanicalFallback
            }
            allEnglishFemale.append(
                TTSVoiceDescriptor(
                    id: v.identifier,
                    displayName: v.name,
                    localeIdentifier: v.language,
                    isFemale: true,
                    tier: tier
                )
            )
        }
        if !allEnglishFemale.isEmpty {
            let exactAccent = allEnglishFemale.filter {
                $0.localeIdentifier.lowercased().hasPrefix(accent.rawValue.lowercased())
            }
            if !exactAccent.isEmpty {
                return exactAccent + allEnglishFemale.filter {
                    !$0.localeIdentifier.lowercased().hasPrefix(accent.rawValue.lowercased())
                }
            }
            return allEnglishFemale
        }
        #endif

        return []
    }

    public static let defaultVoiceCatalog: [TTSVoiceDescriptor] = [
        TTSVoiceDescriptor(
            id: "com.apple.voice.premium.en-GB.Serena",
            displayName: "Serena (Premium UK Female)",
            localeIdentifier: "en-GB",
            isFemale: true,
            tier: .applePremiumOrEnhanced
        ),
        TTSVoiceDescriptor(
            id: "com.apple.voice.premium.en-US.Ava",
            displayName: "Ava (Premium US Female)",
            localeIdentifier: "en-US",
            isFemale: true,
            tier: .applePremiumOrEnhanced
        ),
        TTSVoiceDescriptor(
            id: "com.apple.speech.synthesis.voice.samantha",
            displayName: "Samantha (Standard US Female)",
            localeIdentifier: "en-US",
            isFemale: true,
            tier: .appleStandardMechanicalFallback
        )
    ]

    static func preferredFemaleVoice(in voices:[TTSVoiceDescriptor],preferredVoiceID:String?,accent:TTSVoiceAccent)->TTSVoiceDescriptor? {
        let pool=voices.filter{$0.isFemale && $0.localeIdentifier==accent.rawValue}.sorted{$0.id<$1.id}
        if let preferredVoiceID,let saved=pool.first(where:{$0.id==preferredVoiceID}){return saved}
        return pool.first(where:{$0.tier == .applePremiumOrEnhanced}) ?? pool.first
    }
    public func selectBestFemaleVoice(preferredVoiceID: String?, accent: TTSVoiceAccent) -> TTSVoiceDescriptor {
        let voices = availableVoices(for: accent)
        let femaleVoices = voices.filter(\.isFemale)

        if let preferredID = preferredVoiceID,
           !preferredID.isEmpty,
           let matched = femaleVoices.first(where: { $0.id == preferredID }) {
            return matched
        }

        let accentMatched = femaleVoices.filter {
            $0.localeIdentifier.lowercased().hasPrefix(accent.rawValue.lowercased())
        }
        let pool = accentMatched.isEmpty ? femaleVoices : accentMatched

        if let neural = pool.first(where: { $0.tier == .localNeuralKokoro }) {
            return neural
        }
        if let premium = pool.first(where: { $0.tier == .applePremiumOrEnhanced }) {
            return premium
        }
        if let fallback = pool.first {
            return fallback
        }

        return Self.defaultVoiceCatalog[0]
    }

    /// Maps user speed multiplier (`0.85x`, `1.0x`, `1.15x`, `1.5x`, `1.8x`) to `AVSpeechUtterance.rate`.
    /// Fixes the bug where `.appleStandardMechanicalFallback` locked rate to `0.5` and ignored user multipliers.
    public func effectivePlaybackRate(for voice: TTSVoiceDescriptor, userMultiplier: Float) -> Float {
        let clampedMultiplier = min(max(userMultiplier, 0.70), 2.0)
        let baseRate: Float = 0.5 // AVSpeechUtteranceDefaultSpeechRate on macOS
        if abs(clampedMultiplier - 1.0) < 0.001 {
            return baseRate
        } else if clampedMultiplier < 1.0 {
            // e.g. 0.85x -> 0.425
            return max(0.30, baseRate * clampedMultiplier)
        } else {
            // e.g. 1.15x -> 0.54, 1.5x -> 0.635, 1.8x -> 0.715
            return min(0.76, baseRate + (clampedMultiplier - 1.0) * 0.27)
        }
    }

    #if canImport(AVFAudio)
    @MainActor private lazy var synthesizer = AVSpeechSynthesizer()
    #endif
    @MainActor private var finishNotificationTask: Task<Void, Never>?

    @MainActor public var repeatCount = 1
    @MainActor public var repeatInterval = 0.5

    @MainActor
    public func speak(text: String, voice: TTSVoiceDescriptor, requestedRate: Float) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        #if canImport(AVFAudio)
        finishNotificationTask?.cancel()
        finishNotificationTask = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer = AVSpeechSynthesizer()
        }
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let normLocale = voice.localeIdentifier.lowercased().replacingOccurrences(of: "_", with: "-")
        let installed: AVSpeechSynthesisVoice? =
            AVSpeechSynthesisVoice(identifier: voice.id)
            ?? allVoices.first(where: { $0.identifier == voice.id })
            ?? allVoices.first(where: {
                $0.name.localizedCaseInsensitiveContains(voice.displayName) &&
                $0.language.lowercased().replacingOccurrences(of: "_", with: "-").hasPrefix(normLocale.prefix(5))
            })
            ?? allVoices.first(where: {
                $0.gender == .female &&
                $0.language.lowercased().replacingOccurrences(of: "_", with: "-").hasPrefix(normLocale.prefix(5))
            })
            ?? AVSpeechSynthesisVoice(language: voice.localeIdentifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
            ?? allVoices.first(where: { $0.language.lowercased().hasPrefix("en") })

        let totalRepeats = min(5, max(1, repeatCount))
        let pauseDelay = min(5.0, max(0.0, repeatInterval))
        let rate = effectivePlaybackRate(for: voice, userMultiplier: requestedRate)
        for index in 0..<totalRepeats {
            let utterance = AVSpeechUtterance(string: trimmed)
            if let installed {
                utterance.voice = installed
            }
            utterance.rate = rate
            utterance.pitchMultiplier = 1.0
            utterance.postUtteranceDelay = index < totalRepeats - 1 ? pauseDelay : 0
            synthesizer.speak(utterance)
        }
        let singleEst = max(0.45, Double(max(4, trimmed.count)) * 0.082 / Double(max(0.7, requestedRate)))
        let totalEst = singleEst * Double(totalRepeats) + Double(max(0, totalRepeats - 1)) * pauseDelay
        finishNotificationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(Int(totalEst * 1000)))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(
                name: Notification.Name("LumaReader.DictationAudioFinished"),
                object: nil,
                userInfo: ["text": trimmed]
            )
        }
        #endif
    }

    @MainActor
    public func stop() {
        finishNotificationTask?.cancel()
        finishNotificationTask = nil
        #if canImport(AVFAudio)
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        #endif
    }
}

//
//  QuestionBankGatekeeper.swift
//  LumaReaderStudyKit
//
//  Implements Section 六:
//  - Strict separation between verified/original practice questions and candidate index leads
//  - Automated consistency checks for pie chart sums (100%), table row totals,
//    line graph chronological order, process diagram step connectivity, and map before/after stages.
//

import Foundation

public struct DatasetValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let errors: [String]
}

public struct QuestionBankAuditReport: Equatable, Sendable {
    /// 1. 已发现候选链接/主题数 (Discovered candidate topic leads)
    public let discoveredCandidateCount: Int
    /// 2. 已完成版权审核数 (Completed copyright/license review count)
    public let copyrightAuditedCount: Int
    /// 3. 已导入且可练习完整题数 (Imported & verified ready-to-practice exams)
    public let practiceableExamCount: Int
    /// Breakdown by chart category for practiceable items
    public let practiceableByCategory: [Task1ChartCategory: Int]
}

public nonisolated struct QuestionBankGatekeeper: Sendable {

    public static func validateDataset(
        _ dataset: Task1ChartDataset,
        for category: Task1ChartCategory
    ) -> DatasetValidationResult {
        var errors: [String] = []

        switch category {
        case .lineGraph:
            if dataset.xAxisLabels.count < 3 {
                errors.append("Line graph must have at least 3 ordered time points.")
            }
            // Verify chronological order if labels are integer years
            let years = dataset.xAxisLabels.compactMap { Int($0) }
            if years.count == dataset.xAxisLabels.count {
                for i in 1..<years.count where years[i] <= years[i - 1] {
                    errors.append("Line graph time points are not strictly chronological: \(years[i - 1]) -> \(years[i]).")
                }
            }
            if dataset.series.isEmpty {
                errors.append("Line graph must contain at least 1 data series.")
            }
            for s in dataset.series where s.values.count != dataset.xAxisLabels.count {
                errors.append("Series '\(s.name)' count (\(s.values.count)) does not match xAxisLabels (\(dataset.xAxisLabels.count)).")
            }

        case .barChart:
            if dataset.xAxisLabels.isEmpty || dataset.series.isEmpty {
                errors.append("Bar chart requires non-empty categories and series.")
            }
            for s in dataset.series where s.values.count != dataset.xAxisLabels.count {
                errors.append("Bar series '\(s.name)' length mismatch.")
            }

        case .pieChart:
            guard let slices = dataset.pieSlicePercentages, !slices.isEmpty else {
                errors.append("Pie chart requires pieSlicePercentages.")
                break
            }
            let sum = slices.values.reduce(0.0, +)
            if abs(sum - 100.0) > 0.15 {
                errors.append(String(format: "Pie chart percentages sum to %.2f%% instead of 100.0%%.", sum))
            }

        case .table:
            if dataset.series.isEmpty || dataset.xAxisLabels.isEmpty {
                errors.append("Table requires rows and columns.")
            }
            if let expectedTotals = dataset.tableRowTotals {
                if expectedTotals.count != dataset.xAxisLabels.count {
                    errors.append("Table row totals count does not match row count.")
                } else {
                    for rowIdx in 0..<dataset.xAxisLabels.count {
                        let computed = dataset.series.reduce(0.0) { acc, s in
                            acc + (rowIdx < s.values.count ? s.values[rowIdx] : 0.0)
                        }
                        if abs(computed - expectedTotals[rowIdx]) > 0.15 {
                            errors.append("Table row \(rowIdx) total mismatch: computed \(computed) vs declared \(expectedTotals[rowIdx]).")
                        }
                    }
                }
            }

        case .map:
            guard let map = dataset.mapComparison else {
                errors.append("Map task requires before/after MapComparisonPayload.")
                break
            }
            if map.beforeFeatures.isEmpty || map.afterFeatures.isEmpty {
                errors.append("Map comparison requires non-empty before and after features.")
            }

        case .processDiagram:
            guard let steps = dataset.processSteps, steps.count >= 4 else {
                errors.append("Process diagram requires at least 4 ordered steps.")
                break
            }
            for i in 0..<(steps.count - 1) {
                if steps[i].nextStepNumber != steps[i + 1].stepNumber {
                    errors.append("Broken arrow connectivity between step \(steps[i].stepNumber) and \(steps[i + 1].stepNumber).")
                }
            }

        case .mixedChart, .all:
            if dataset.series.isEmpty && dataset.pieSlicePercentages == nil {
                errors.append("Mixed chart requires both primary series and secondary distribution.")
            }
        }

        return DatasetValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    /// Filters a combined catalog of items so that ONLY fully licensed, chart-verified exams
    /// appear on the user's Task 1 Home Grid (Section 三 & 六).
    public static func userVisiblePracticeItems(
        from allItems: [Task1QuestionItem],
        category: Task1ChartCategory = .all,
        searchQuery: String = ""
    ) -> [Task1QuestionItem] {
        let verified = allItems.filter(\.isPracticeableOnUserGrid)
        let categoryFiltered: [Task1QuestionItem]
        if category == .all {
            categoryFiltered = verified
        } else {
            categoryFiltered = verified.filter { $0.category == category }
        }
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return categoryFiltered }
        return categoryFiltered.filter {
            $0.shortTitle.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.promptText.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.category.rawValue.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    public static func auditCatalog(_ allItems: [Task1QuestionItem]) -> QuestionBankAuditReport {
        let candidateLeads = allItems.filter { $0.licenseStatus == .pendingVerification }
        let practiceable = allItems.filter(\.isPracticeableOnUserGrid)
        var byCat: [Task1ChartCategory: Int] = [:]
        for item in practiceable {
            byCat[item.category, default: 0] += 1
        }
        return QuestionBankAuditReport(
            discoveredCandidateCount: candidateLeads.count,
            copyrightAuditedCount: allItems.count,
            practiceableExamCount: practiceable.count,
            practiceableByCategory: byCat
        )
    }
}


//
//  StudyStatisticsCalculator.swift
//  LumaReaderStudyKit
//
//  Implements Section 七:
//  - Three filter modes: 全部 (All) | 听力 (Listening) | 写作 (Writing)
//  - Four time windows: 今天 (Today) | 7 天 (7 Days) | 30 天 (30 Days) | 全部时间 (All Time)
//  - Strictly separates duration/time composition from unit counts (never adds word count + essay count!)
//  - Returns honest empty-state indicators when no records exist.
//

import Foundation

public enum StudyStatisticsScope: String, Codable, CaseIterable, Sendable {
    case all = "全部"
    case listening = "听力"
    case writing = "写作"
}

public enum StudyStatsTimeWindow: String, Codable, CaseIterable, Sendable {
    case today = "今天"
    case last7Days = "7 天"
    case last30Days = "30 天"
    case allTime = "全部时间"
}

public struct OverviewStatsSummary: Equatable, Sendable {
    public let isEmpty: Bool
    public let totalStudySeconds: Int
    public let listeningStudySeconds: Int
    public let writingStudySeconds: Int
    public let streakDays: Int
    public let dailyDurationTrend: [(dateString: String, listeningSeconds: Int, writingSeconds: Int)]

    public static func == (lhs: OverviewStatsSummary, rhs: OverviewStatsSummary) -> Bool {
        lhs.isEmpty == rhs.isEmpty
            && lhs.totalStudySeconds == rhs.totalStudySeconds
            && lhs.listeningStudySeconds == rhs.listeningStudySeconds
            && lhs.writingStudySeconds == rhs.writingStudySeconds
            && lhs.streakDays == rhs.streakDays
            && lhs.dailyDurationTrend.count == rhs.dailyDurationTrend.count
    }
}

public struct ListeningStatsSummary: Equatable, Sendable {
    public let isEmpty: Bool
    public let completedUniqueWordsCount: Int
    public let firstAttemptAccuracyPercent: Double
    public let totalErrorCount: Int
    public let stubbornWordsCount: Int
    public let topErrorWords: [(word: String, errorCount: Int)]

    public static func == (lhs: ListeningStatsSummary, rhs: ListeningStatsSummary) -> Bool {
        lhs.isEmpty == rhs.isEmpty
            && lhs.completedUniqueWordsCount == rhs.completedUniqueWordsCount
            && abs(lhs.firstAttemptAccuracyPercent - rhs.firstAttemptAccuracyPercent) < 0.001
            && lhs.totalErrorCount == rhs.totalErrorCount
            && lhs.stubbornWordsCount == rhs.stubbornWordsCount
    }
}

public struct WritingStatsSummary: Equatable, Sendable {
    public let isEmpty: Bool
    public let totalSubmissionsCount: Int
    public let task1Count: Int
    public let task2Count: Int
    public let totalDurationSeconds: Int
    public let averageWordCount: Int
    public let averageEstimatedBand: Double?
}

/// 年度学习热力图（GitHub 打卡墙）每日单元格数据
public struct StudyHeatmapDayCell: Identifiable, Equatable, Sendable {
    public var id: String { dateString }
    public let date: Date
    public let dateString: String
    public let weekIndex: Int // 0..<53
    public let weekdayIndex: Int // 0 = 周一 ... 6 = 周日
    public let readingSeconds: Int
    public let listeningSeconds: Int
    public let writingSeconds: Int

    public var totalSeconds: Int {
        readingSeconds + listeningSeconds + writingSeconds
    }

    public var totalMinutes: Int {
        totalSeconds == 0 ? 0 : max(1, (totalSeconds + 30) / 60)
    }

    public var readingMinutes: Int {
        readingSeconds == 0 ? 0 : max(1, (readingSeconds + 30) / 60)
    }

    public var listeningMinutes: Int {
        listeningSeconds == 0 ? 0 : max(1, (listeningSeconds + 30) / 60)
    }

    public var writingMinutes: Int {
        writingSeconds == 0 ? 0 : max(1, (writingSeconds + 30) / 60)
    }

    /// 0: 无学习, 1: 1-14 分钟, 2: 15-29 分钟, 3: 30-59 分钟, 4: ≥60 分钟
    public var intensityLevel: Int {
        guard totalSeconds > 0 else { return 0 }
        let mins = Double(totalSeconds) / 60.0
        if mins < 15.0 { return 1 }
        if mins < 30.0 { return 2 }
        if mins < 60.0 { return 3 }
        return 4
    }
}

public struct AnnualStudyHeatmapSummary: Equatable, Sendable {
    public let cells: [StudyHeatmapDayCell]
    public let weekCount: Int
    public let currentStreakDays: Int
    public let longestStreakDays: Int
    public let activeDaysCount: Int
    public let totalReadingSeconds: Int
    public let totalListeningSeconds: Int
    public let totalWritingSeconds: Int

    public var totalStudySeconds: Int {
        totalReadingSeconds + totalListeningSeconds + totalWritingSeconds
    }
}

/// 写作四维能力折线图单点数据（支持小作文 TA/CC/LR/GRA 与大作文 TR/CC/LR/GRA）
public struct WritingDimensionPoint: Identifiable, Equatable, Sendable {
    public var id: String { "\(submissionID.uuidString)_\(criterionCode)" }
    public let submissionID: UUID
    public let orderIndex: Int
    public let shortAttemptLabel: String
    public let examTitle: String
    public let dateString: String
    public let criterionCode: String
    public let criterionDisplayName: String
    public let score: Double
}

/// 写作单科（Task 1 或 Task 2）四维能力走势与近期卡分点诊断
public struct WritingTaskCompetencyDiagnostic: Equatable, Sendable {
    public let isTask1: Bool
    public let submissionCount: Int
    public let points: [WritingDimensionPoint]
    public let averageFirstCriterion: Double
    public let averageCC: Double
    public let averageLR: Double
    public let averageGRA: Double
    public let averageOverall: Double
    public let bottleneckCriterionCode: String
    public let bottleneckCriterionTitle: String
    public let bottleneckAverageScore: Double
    public let bottleneckDiagnosisZH: String
    public let actionableAdviceZH: String
}

public nonisolated struct StudyStatisticsCalculator: Sendable {

    public static func computeOverview(
        dictationLogs: [DictationAttemptLog],
        writingSubmissions: [WritingSubmissionRecord],
        readingSecondsByDate: [String: Int] = [:],
        allowedDates: Set<String>? = nil
    ) -> OverviewStatsSummary {
        let filteredDictation = dictationLogs.filter { allowedDates?.contains($0.dateString) ?? true }
        let filteredWriting = writingSubmissions.filter { allowedDates?.contains($0.dateString) ?? true }
        let filteredReading = readingSecondsByDate.filter { allowedDates?.contains($0.key) ?? true }

        let readingSecs = filteredReading.values.reduce(0, +)
        if filteredDictation.isEmpty && filteredWriting.isEmpty && readingSecs == 0 {
            return OverviewStatsSummary(
                isEmpty: true,
                totalStudySeconds: 0,
                listeningStudySeconds: 0,
                writingStudySeconds: 0,
                streakDays: 0,
                dailyDurationTrend: []
            )
        }

        let listeningSecs = Int(filteredDictation.reduce(0.0) { $0 + $1.durationSeconds }.rounded())
        let writingSecs = filteredWriting.reduce(0) { $0 + $1.durationSeconds }
        let totalSecs = readingSecs + listeningSecs + writingSecs

        var dailyMap: [String: (l: Int, w: Int, r: Int)] = [:]
        for (d, rSec) in filteredReading where rSec > 0 {
            var cur = dailyMap[d, default: (0, 0, 0)]
            cur.r += rSec
            dailyMap[d] = cur
        }
        for log in filteredDictation {
            var cur = dailyMap[log.dateString, default: (0, 0, 0)]
            cur.l += max(1, Int(log.durationSeconds.rounded()))
            dailyMap[log.dateString] = cur
        }
        for sub in filteredWriting {
            var cur = dailyMap[sub.dateString, default: (0, 0, 0)]
            cur.w += sub.durationSeconds
            dailyMap[sub.dateString] = cur
        }

        let sortedDates = dailyMap.keys.sorted()
        let trend = sortedDates.map { d in
            (dateString: d, listeningSeconds: dailyMap[d]!.l, writingSeconds: dailyMap[d]!.w)
        }

        return OverviewStatsSummary(
            isEmpty: false,
            totalStudySeconds: totalSecs,
            listeningStudySeconds: listeningSecs,
            writingStudySeconds: writingSecs,
            streakDays: sortedDates.count,
            dailyDurationTrend: trend
        )
    }

    /// 计算过去 52 周（364 天 + 本周）GitHub 风格年度学习热力图与连续打卡天数
    public static func computeAnnualHeatmap(
        readingByDate: [String: Int],
        dictationLogs: [DictationAttemptLog],
        writingSubmissions: [WritingSubmissionRecord],
        referenceDate: Date = Date()
    ) -> AnnualStudyHeatmapSummary {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 周一为每周第一天
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var listeningByDate: [String: Double] = [:]
        for log in dictationLogs {
            listeningByDate[log.dateString, default: 0.0] += max(1.0, log.durationSeconds)
        }
        var writingByDate: [String: Int] = [:]
        for sub in writingSubmissions {
            writingByDate[sub.dateString, default: 0] += max(60, sub.durationSeconds)
        }

        let todayStart = cal.startOfDay(for: referenceDate)
        let weekdayComponent = cal.component(.weekday, from: todayStart) // 1 = Sun, 2 = Mon ... 7 = Sat
        let mondayZeroBased = (weekdayComponent + 5) % 7 // 0 = Mon ... 6 = Sun
        let currentWeekMonday = cal.date(byAdding: .day, value: -mondayZeroBased, to: todayStart) ?? todayStart
        let numWeeks = 52
        let firstMonday = cal.date(byAdding: .day, value: -(numWeeks - 1) * 7, to: currentWeekMonday) ?? todayStart

        var cells: [StudyHeatmapDayCell] = []
        var totalReading = 0
        var totalListening = 0
        var totalWriting = 0
        var activeDays = 0
        var longestStreak = 0
        var runningStreak = 0

        for w in 0..<numWeeks {
            for d in 0..<7 {
                let offsetDays = w * 7 + d
                guard let cellDate = cal.date(byAdding: .day, value: offsetDays, to: firstMonday) else { continue }
                if cellDate > todayStart { continue }
                let dStr = formatter.string(from: cellDate)
                let rSec = max(0, readingByDate[dStr, default: 0])
                let lSec = Int((listeningByDate[dStr, default: 0.0]).rounded())
                let wSec = max(0, writingByDate[dStr, default: 0])
                let cell = StudyHeatmapDayCell(
                    date: cellDate,
                    dateString: dStr,
                    weekIndex: w,
                    weekdayIndex: d,
                    readingSeconds: rSec,
                    listeningSeconds: lSec,
                    writingSeconds: wSec
                )
                cells.append(cell)
                totalReading += rSec
                totalListening += lSec
                totalWriting += wSec
                if cell.totalSeconds > 0 {
                    activeDays += 1
                    runningStreak += 1
                    longestStreak = max(longestStreak, runningStreak)
                } else {
                    runningStreak = 0
                }
            }
        }

        // Compute current consecutive streak ending today (or yesterday if today hasn't been logged yet)
        var currentStreak = 0
        let sortedCells = cells.sorted { $0.dateString > $1.dateString }
        for (idx, cell) in sortedCells.enumerated() {
            if cell.totalSeconds > 0 {
                currentStreak += 1
            } else if idx == 0 {
                // Allow streak to stay alive if today has 0 so far but yesterday was active
                continue
            } else {
                break
            }
        }

        return AnnualStudyHeatmapSummary(
            cells: cells,
            weekCount: numWeeks,
            currentStreakDays: currentStreak,
            longestStreakDays: longestStreak,
            activeDaysCount: activeDays,
            totalReadingSeconds: totalReading,
            totalListeningSeconds: totalListening,
            totalWritingSeconds: totalWriting
        )
    }

    /// 分别计算小作文 (Task 1: TA/CC/LR/GRA) 与大作文 (Task 2: TR/CC/LR/GRA) 四维能力折线图数据与近期卡分点诊断
    public static func computeWritingCompetencyDiagnostics(
        submissions: [WritingSubmissionRecord],
        questions: [Task1QuestionItem]
    ) -> (task1: WritingTaskCompetencyDiagnostic, task2: WritingTaskCompetencyDiagnostic) {
        let chronological = submissions.sorted { $0.submittedAt < $1.submittedAt }
        let fallbackQuestion = questions.first ?? Task1QuestionItem(
            id: "ORIG-001",
            shortTitle: "Default",
            category: .lineGraph,
            difficultyBand: "Band 6.5",
            promptText: "Summarise the information.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "Luma",
            sourceURL: "https://www.ielts.org",
            licenseStatus: .originalSelfAuthored,
            chartDataset: LumaTask1DefaultDataset.make(for: .lineGraph),
            companionTask2ID: "T2-001",
            companionTask2Prompt: "Discuss both views.",
            notes: nil
        )

        var t1Subs: [(sub: WritingSubmissionRecord, est: IELTSFourCriteriaEstimate)] = []
        var t2Subs: [(sub: WritingSubmissionRecord, est: IELTSFourCriteriaEstimate)] = []

        for sub in chronological {
            let matchedQ = questions.first(where: { $0.id == sub.questionID }) ?? fallbackQuestion
            let p1Trim = sub.part1EssayText.trimmingCharacters(in: .whitespacesAndNewlines)
            let p2Trim = sub.part2EssayText.trimmingCharacters(in: .whitespacesAndNewlines)

            if !p1Trim.isEmpty {
                let singleT1 = WritingSubmissionRecord(
                    id: sub.id,
                    draftSessionID: sub.draftSessionID,
                    questionID: sub.questionID,
                    examTitle: sub.examTitle,
                    part1EssayText: sub.part1EssayText,
                    part2EssayText: "",
                    part1WordCount: sub.part1WordCount,
                    part2WordCount: 0,
                    durationSeconds: sub.durationSeconds,
                    submittedAt: sub.submittedAt,
                    dateString: sub.dateString,
                    aiEvaluation: p2Trim.isEmpty ? sub.aiEvaluation : nil
                )
                let est = singleT1.aiEvaluation ?? IELTSOfficialRubricEngine.audit(record: singleT1, question: matchedQ).deterministicEstimate
                t1Subs.append((singleT1, est))
            }

            if !p2Trim.isEmpty {
                let singleT2 = WritingSubmissionRecord(
                    id: sub.id,
                    draftSessionID: sub.draftSessionID,
                    questionID: sub.questionID,
                    examTitle: sub.examTitle,
                    part1EssayText: "",
                    part2EssayText: sub.part2EssayText,
                    part1WordCount: 0,
                    part2WordCount: sub.part2WordCount,
                    durationSeconds: sub.durationSeconds,
                    submittedAt: sub.submittedAt,
                    dateString: sub.dateString,
                    aiEvaluation: p1Trim.isEmpty ? sub.aiEvaluation : nil
                )
                let est = singleT2.aiEvaluation ?? IELTSOfficialRubricEngine.audit(record: singleT2, question: matchedQ).deterministicEstimate
                t2Subs.append((singleT2, est))
            }
        }

        let diag1 = buildSingleTaskDiagnostic(isTask1: true, items: t1Subs)
        let diag2 = buildSingleTaskDiagnostic(isTask1: false, items: t2Subs)
        return (diag1, diag2)
    }

    private static func buildSingleTaskDiagnostic(
        isTask1: Bool,
        items: [(sub: WritingSubmissionRecord, est: IELTSFourCriteriaEstimate)]
    ) -> WritingTaskCompetencyDiagnostic {
        let firstCode = isTask1 ? "TA" : "TR"
        let firstTitle = isTask1 ? "TA · 任务完成度" : "TR · 任务回应度"
        guard !items.isEmpty else {
            return WritingTaskCompetencyDiagnostic(
                isTask1: isTask1,
                submissionCount: 0,
                points: [],
                averageFirstCriterion: 0,
                averageCC: 0,
                averageLR: 0,
                averageGRA: 0,
                averageOverall: 0,
                bottleneckCriterionCode: firstCode,
                bottleneckCriterionTitle: firstTitle,
                bottleneckAverageScore: 0,
                bottleneckDiagnosisZH: isTask1 ? "尚无小作文 (Task 1) 交卷记录，完成一篇图表作文后即可生成 TA/CC/LR/GRA 四维走势与卡分点诊断。" : "尚无大作文 (Task 2) 交卷记录，完成一篇议论文后即可生成 TR/CC/LR/GRA 四维走势与卡分点诊断。",
                actionableAdviceZH: "前往「写作」题库双击任一题目开始练习并交卷。"
            )
        }

        var points: [WritingDimensionPoint] = []
        for (idx, entry) in items.enumerated() {
            let shortDate = String(entry.sub.dateString.suffix(5))
            let label = "#\(idx + 1) (\(shortDate))"
            let e = entry.est
            points.append(WritingDimensionPoint(submissionID: entry.sub.id, orderIndex: idx + 1, shortAttemptLabel: label, examTitle: entry.sub.examTitle, dateString: entry.sub.dateString, criterionCode: firstCode, criterionDisplayName: firstTitle, score: e.taskAchievementOrResponse))
            points.append(WritingDimensionPoint(submissionID: entry.sub.id, orderIndex: idx + 1, shortAttemptLabel: label, examTitle: entry.sub.examTitle, dateString: entry.sub.dateString, criterionCode: "CC", criterionDisplayName: "CC · 连贯与衔接", score: e.coherenceAndCohesion))
            points.append(WritingDimensionPoint(submissionID: entry.sub.id, orderIndex: idx + 1, shortAttemptLabel: label, examTitle: entry.sub.examTitle, dateString: entry.sub.dateString, criterionCode: "LR", criterionDisplayName: "LR · 词汇丰富度", score: e.lexicalResource))
            points.append(WritingDimensionPoint(submissionID: entry.sub.id, orderIndex: idx + 1, shortAttemptLabel: label, examTitle: entry.sub.examTitle, dateString: entry.sub.dateString, criterionCode: "GRA", criterionDisplayName: "GRA · 语法多样性与准确性", score: e.grammaticalRangeAndAccuracy))
        }

        let recentWindow = Array(items.suffix(5))
        let count = Double(recentWindow.count)
        let avgFirst = recentWindow.reduce(0.0) { $0 + $1.est.taskAchievementOrResponse } / count
        let avgCC = recentWindow.reduce(0.0) { $0 + $1.est.coherenceAndCohesion } / count
        let avgLR = recentWindow.reduce(0.0) { $0 + $1.est.lexicalResource } / count
        let avgGRA = recentWindow.reduce(0.0) { $0 + $1.est.grammaticalRangeAndAccuracy } / count
        let avgOverall = recentWindow.reduce(0.0) { $0 + $1.est.overallEstimatedBand } / count

        let candidates: [(code: String, title: String, score: Double)] = [
            (firstCode, firstTitle, avgFirst),
            ("CC", "CC · 连贯与衔接", avgCC),
            ("LR", "LR · 词汇丰富度", avgLR),
            ("GRA", "GRA · 语法多样性与准确性", avgGRA)
        ]
        let lowest = candidates.min { $0.score < $1.score } ?? candidates[0]

        let diagnosis: String
        let advice: String
        switch lowest.code {
        case "TA":
            diagnosis = String(format: "近期小作文主要卡分点在【TA 任务完成度】(近 %d 篇均分 Band %.1f)，常见原因为缺少清晰的宏观总体趋势段 (Overview) 或关键极值/对比数据支撑不足。", recentWindow.count, lowest.score)
            advice = "提分处方：首段改写题目后，第二段务必使用 Overall, it is clear that... 概括 2 个宏观特征（不写琐碎数字），主体段再用具体数据做横向对比。"
        case "TR":
            diagnosis = String(format: "近期大作文主要卡分点在【TR 任务回应度】(近 %d 篇均分 Band %.1f)，论点展开深度或对题目双边/程度的回应完整度拉低了总分。", recentWindow.count, lowest.score)
            advice = "提分处方：确保首段明确给出核心立场，每个主体段遵循「中心句 -> 因果推演 -> 具体实例 -> 回扣分论点」四步展开，避免泛泛而谈。"
        case "CC":
            diagnosis = String(format: "近期主要卡分点在【CC 连贯与衔接】(近 %d 篇均分 Band %.1f)，段落推进或指代衔接词（this trend / such measures）存在机械堆砌或跳跃。", recentWindow.count, lowest.score)
            advice = "提分处方：减少机械句首连接词（如 Firstly/Secondly），多用代词指代、同义概念复现（Lexical Cohesion）和让步转折从句自然过渡。"
        case "LR":
            diagnosis = String(format: "近期主要卡分点在【LR 词汇丰富度】(近 %d 篇均分 Band %.1f)，存在基础词汇重复或固定搭配不够地道、拼写失误。", recentWindow.count, lowest.score)
            advice = "提分处方：在「历史作文」批改页点击「一键导入高分搭配与错词到听力生词本」，通过听写巩固学术同义替换与动宾固定搭配。"
        default:
            diagnosis = String(format: "近期主要卡分点在【GRA 语法多样性与准确性】(近 %d 篇均分 Band %.1f)，简单句占比较高或复合句中存在主谓一致、冠词与从句标点瑕疵。", recentWindow.count, lowest.score)
            advice = "提分处方：每段有意识融入 1-2 个非限定性定语从句（which...）、状语从句或分词结构，并在交卷前留出 3 分钟专查无错句率（Error-free sentences）。"
        }

        return WritingTaskCompetencyDiagnostic(
            isTask1: isTask1,
            submissionCount: items.count,
            points: points,
            averageFirstCriterion: avgFirst,
            averageCC: avgCC,
            averageLR: avgLR,
            averageGRA: avgGRA,
            averageOverall: avgOverall,
            bottleneckCriterionCode: lowest.code,
            bottleneckCriterionTitle: lowest.title,
            bottleneckAverageScore: lowest.score,
            bottleneckDiagnosisZH: diagnosis,
            actionableAdviceZH: advice
        )
    }

    public static func computeListening(
        dictationLogs: [DictationAttemptLog],
        stubbornWords: [StubbornWordRecord],
        allowedDates: Set<String>? = nil
    ) -> ListeningStatsSummary {
        let logs = dictationLogs.filter { allowedDates?.contains($0.dateString) ?? true }
        let stubborns = stubbornWords.filter { allowedDates?.contains($0.dateString) ?? true }

        guard !logs.isEmpty else {
            return ListeningStatsSummary(
                isEmpty: true,
                completedUniqueWordsCount: 0,
                firstAttemptAccuracyPercent: 0.0,
                totalErrorCount: 0,
                stubbornWordsCount: stubborns.count,
                topErrorWords: []
            )
        }

        let completedWords = Set(logs.filter(\.isCorrect).map(\.wordID))
        let firstAttempts = logs.filter(\.isFirstAttemptInSession)
        let firstAttemptCorrect = firstAttempts.filter(\.isCorrect).count
        let accuracy = firstAttempts.isEmpty
            ? 0.0
            : (Double(firstAttemptCorrect) / Double(firstAttempts.count)) * 100.0

        let errors = logs.filter { !$0.isCorrect }
        var errorByWord: [String: Int] = [:]
        for e in errors {
            errorByWord[e.word, default: 0] += 1
        }
        let sortedErrors = errorByWord
            .map { (word: $0.key, errorCount: $0.value) }
            .sorted { $0.errorCount != $1.errorCount ? $0.errorCount > $1.errorCount : $0.word < $1.word }

        return ListeningStatsSummary(
            isEmpty: false,
            completedUniqueWordsCount: completedWords.count,
            firstAttemptAccuracyPercent: accuracy,
            totalErrorCount: errors.count,
            stubbornWordsCount: stubborns.count,
            topErrorWords: sortedErrors
        )
    }

    public static func computeWriting(
        submissions: [WritingSubmissionRecord],
        allowedDates: Set<String>? = nil
    ) -> WritingStatsSummary {
        let subs = submissions.filter { allowedDates?.contains($0.dateString) ?? true }
        guard !subs.isEmpty else {
            return WritingStatsSummary(
                isEmpty: true,
                totalSubmissionsCount: 0,
                task1Count: 0,
                task2Count: 0,
                totalDurationSeconds: 0,
                averageWordCount: 0,
                averageEstimatedBand: nil
            )
        }

        let t1Count = subs.filter { $0.part1WordCount > 0 }.count
        let t2Count = subs.filter { $0.part2WordCount > 0 }.count
        let totalSecs = subs.reduce(0) { $0 + $1.durationSeconds }
        let totalWords = subs.reduce(0) { $0 + $1.part1WordCount + $1.part2WordCount }
        let avgWords = totalWords / subs.count

        let graded = subs.compactMap { $0.aiEvaluation?.overallEstimatedBand }
        let avgBand = graded.isEmpty ? nil : (graded.reduce(0.0, +) / Double(graded.count))

        return WritingStatsSummary(
            isEmpty: false,
            totalSubmissionsCount: subs.count,
            task1Count: t1Count,
            task2Count: t2Count,
            totalDurationSeconds: totalSecs,
            averageWordCount: avgWords,
            averageEstimatedBand: avgBand
        )
    }
}


//  LumaReaderStudyViews_MacroFree.swift
//  LumaReader
//
//  Uses `@StateObject` + `ObservableObject` (`@Published`) instead of `@State` macro
//  so it compiles cleanly even when `/Library/Developer/CommandLineTools` on macOS 26.5/27
//  is missing `libSwiftUIMacros.dylib`.
//

import Foundation
#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit
import Combine

public enum LumaTheme {
    public static var windowBackground: Color { StudyAppearance.current.paper }
    public static var sidebarPillFill: Color { StudyAppearance.current.surface }
    public static var sidebarSelectedFill: Color { StudyAppearance.current.selected }
    public static var softPinkAccent: Color { StudyAppearance.current.accent }
    public static var primaryCardGradient: LinearGradient { StudyAppearance.current.primaryGradient }
    public static var secondaryCardGradient: LinearGradient { StudyAppearance.current.secondaryGradient }
    public static var glassBorder: Color { StudyAppearance.current.line }
}

@MainActor
public final class ListeningShelfViewModel: ObservableObject {
    @Published public var searchText: String = ""
    public init() {}
}

public struct ListeningShelfHomeView: View {
    @Environment(\.studyAppearance) private var appearance
    public let todayDictatedWordCount: Int
    @StateObject private var vm = ListeningShelfViewModel()
    public var onSelectDeck: (String) -> Void

    public init(todayDictatedWordCount: Int, onSelectDeck: @escaping (String) -> Void) {
        self.todayDictatedWordCount = todayDictatedWordCount
        self.onSelectDeck = onSelectDeck
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("听力")
                    .lumaFont(size: 30, weight: .bold, design: .serif)
                    .foregroundStyle(appearance.ink)
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(appearance.ink.opacity(0.6))
                    TextField("搜索词库或练习", text: $vm.searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(appearance.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(width: 240)
                .studyGlassCapsule(cornerRadius: 18)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 10) {
                Button {
                    onSelectDeck("vocab_daily")
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("词汇练习")
                            .lumaFont(size: 24, weight: .semibold, design: .serif)
                            .foregroundStyle(appearance.ink)
                        Text("今天已听写 \(todayDictatedWordCount) 个单词")
                            .lumaFont(size: 13)
                            .foregroundStyle(appearance.ink.opacity(0.82))
                        Spacer()
                        HStack {
                            Image(systemName: "headphones")
                                .font(.system(size: 20))
                                .foregroundStyle(appearance.accent)
                            Spacer()
                            Text("继续练习")
                                .lumaFont(size: 12, weight: .semibold)
                                .foregroundStyle(appearance.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .studyGlassCapsule(cornerRadius: 12, selected: true)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12).padding(.trailing, 32)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(appearance.selected)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(appearance.line, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(StudyFluidPressStyle())

                listeningDeckCard(id: "vocab_travel", title: "旅行词汇", icon: "airplane")
                listeningDeckCard(id: "vocab_work", title: "工作词汇", icon: "briefcase")
                listeningDeckCard(id: "vocab_collocation", title: "配对词汇", icon: "link")
            }

            Spacer()
        }
        .padding(32)
        .background(appearance.paper)
    }

    private func listeningDeckCard(id: String, title: String, icon: String) -> some View {
        Button {
            onSelectDeck(id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .lumaFont(size: 22, weight: .medium, design: .serif)
                    .foregroundStyle(appearance.ink)
                Spacer()
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 19))
                        .foregroundStyle(appearance.accent)
                    Spacer()
                }
            }
            .padding(18)
            .frame(height: 245)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(appearance.secondaryGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(appearance.line, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(StudyFluidPressStyle())
    }
}

@MainActor
public final class Task1BankViewModel: ObservableObject {
    @Published public var selectedCategory: Task1ChartCategory = .all
    @Published public var searchQuery: String = ""
    @Published public var selectedQuestionID: String? = "ORIG-001"
    public init() {}
}

#if canImport(AppKit)
public struct StudyKeyboardEventMonitor: NSViewRepresentable {
    public var onKeyDown: (NSEvent) -> Bool

    public init(onKeyDown: @escaping (NSEvent) -> Bool) {
        self.onKeyDown = onKeyDown
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onKeyDown: onKeyDown)
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install()
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKeyDown = onKeyDown
    }

    public static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    public final class Coordinator {
        var onKeyDown: (NSEvent) -> Bool
        var monitor: Any?

        init(onKeyDown: @escaping (NSEvent) -> Bool) {
            self.onKeyDown = onKeyDown
        }

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if self.onKeyDown(event) {
                    return nil
                }
                return event
            }
        }

        func teardown() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            teardown()
        }
    }
}
#endif

public struct Task1QuestionBankHomeView: View {
    @Environment(\.studyAppearance) private var appearance
    public let allCatalogItems: [Task1QuestionItem]
    @StateObject private var vm = Task1BankViewModel()
    @FocusState private var searchFocused: Bool
    public var onLaunchExam: (Task1QuestionItem) -> Void
    public var onAddQuestion: (() -> Void)?
    public var onEditQuestion: ((Task1QuestionItem) -> Void)?
    public var onDeleteQuestion: ((String) -> Void)?
    public var onChangeCategory: ((Task1QuestionItem, Task1ChartCategory) -> Void)?
    public var onOpenBankManager: (() -> Void)?

    public init(
        allCatalogItems: [Task1QuestionItem],
        onLaunchExam: @escaping (Task1QuestionItem) -> Void,
        onAddQuestion: (() -> Void)? = nil,
        onEditQuestion: ((Task1QuestionItem) -> Void)? = nil,
        onDeleteQuestion: ((String) -> Void)? = nil,
        onChangeCategory: ((Task1QuestionItem, Task1ChartCategory) -> Void)? = nil,
        onOpenBankManager: (() -> Void)? = nil
    ) {
        self.allCatalogItems = allCatalogItems
        self.onLaunchExam = onLaunchExam
        self.onAddQuestion = onAddQuestion
        self.onEditQuestion = onEditQuestion
        self.onDeleteQuestion = onDeleteQuestion
        self.onChangeCategory = onChangeCategory
        self.onOpenBankManager = onOpenBankManager
    }

    private var visibleItems: [Task1QuestionItem] {
        QuestionBankGatekeeper.userVisiblePracticeItems(
            from: allCatalogItems,
            category: vm.selectedCategory,
            searchQuery: vm.searchQuery
        )
    }

    private let fiveColumnGrid = [GridItem(.flexible(), spacing: 10)]

    private func moveSelection(delta: Int, proxy: ScrollViewProxy) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let currentIdx = items.firstIndex(where: { $0.id == vm.selectedQuestionID }) ?? 0
        let nextIdx = min(max(0, currentIdx + delta), items.count - 1)
        let targetID = items[nextIdx].id
        vm.selectedQuestionID = targetID
        withAnimation(.easeOut(duration: 0.14)) {
            proxy.scrollTo(targetID, anchor: .center)
        }
    }

    private func launchSelectedQuestion() {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let chosen = items.first(where: { $0.id == vm.selectedQuestionID }) ?? items[0]
        onLaunchExam(chosen)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Task 1 题库")
                            .lumaFont(size: 30, weight: .bold, design: .serif)
                            .foregroundStyle(appearance.ink)
                        Text("支持 ↑/↓ 方向键浏览、回车 (↩) 或双击题目直接进入练习 · 右键或右侧菜单支持编辑、切换图表分类与删除")
                            .lumaFont(size: 13)
                            .foregroundStyle(appearance.ink.opacity(0.68))
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(appearance.ink.opacity(0.6))
                            TextField("搜索题目与主题", text: $vm.searchQuery)
                                .textFieldStyle(.plain)
                                .lumaFont(size: 13)
                                .focused($searchFocused)
                                .foregroundStyle(appearance.ink)
                            if !vm.searchQuery.isEmpty {
                                Button {
                                    vm.searchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(appearance.ink.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 6)
                        .frame(width: 215, height: 38)

                        Rectangle()
                            .fill(appearance.ink.opacity(0.14))
                            .frame(width: 1, height: 18)
                            .padding(.horizontal, 2)

                        Menu {
                            if let onAddQuestion {
                                Button {
                                    onAddQuestion()
                                } label: {
                                    Label("添加写作题目…", systemImage: "plus.circle")
                                }
                            }
                            if let onOpenBankManager {
                                Button {
                                    onOpenBankManager()
                                } label: {
                                    Label("管理题库与分类…", systemImage: "slider.horizontal.3")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(appearance.ink.opacity(0.88))
                                .frame(width: 38, height: 38)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .help("添加写作题目、管理题库与分类")
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .studyGlassCapsule(cornerRadius: 22)
                }

                HStack(spacing: 10) {
                    ForEach(Task1ChartCategory.homeFilterBarCategories, id: \.self) { category in
                        let isSelected = (vm.selectedCategory == category)
                        Button {
                            vm.selectedCategory = category
                            if let first = visibleItems.first {
                                vm.selectedQuestionID = first.id
                            }
                        } label: {
                            Text(category.rawValue)
                        }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: isSelected, selected: isSelected, horizontalPadding: 14, height: 32))
                    }
                }

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(visibleItems) { item in
                            let isHighlighted = (vm.selectedQuestionID == item.id)
                            Task1TopicCardView(item: item, isSelected: isHighlighted)
                                .id(item.id)
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .trailing) {
                                    if onEditQuestion != nil || onDeleteQuestion != nil {
                                        Menu {
                                            Button("开始练习") {
                                                vm.selectedQuestionID = item.id
                                                onLaunchExam(item)
                                            }
                                            if let onEditQuestion {
                                                Button("编辑题目…") {
                                                    onEditQuestion(item)
                                                }
                                            }
                                            if let onChangeCategory {
                                                Menu("移动到图表类型") {
                                                    ForEach(Task1ChartCategory.homeFilterBarCategories.filter { $0 != .all }, id: \.self) { cat in
                                                        Button {
                                                            onChangeCategory(item, cat)
                                                        } label: {
                                                            Label(cat.rawValue, systemImage: item.category == cat ? "checkmark" : "chart.bar")
                                                        }
                                                    }
                                                }
                                            }
                                            if let onDeleteQuestion {
                                                Divider()
                                                Button("删除题目", role: .destructive) {
                                                    onDeleteQuestion(item.id)
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(appearance.ink.opacity(0.6))
                                                .padding(8)
                                        }
                                        .menuStyle(.borderlessButton)
                                        .fixedSize()
                                        .padding(.trailing, 6)
                                    }
                                }
                                .contextMenu {
                                    Button("开始练习") {
                                        vm.selectedQuestionID = item.id
                                        onLaunchExam(item)
                                    }
                                    if let onEditQuestion {
                                        Button("编辑题目…") {
                                            onEditQuestion(item)
                                        }
                                    }
                                    if let onChangeCategory {
                                        Menu("移动到图表类型") {
                                            ForEach(Task1ChartCategory.homeFilterBarCategories.filter { $0 != .all }, id: \.self) { cat in
                                                Button(cat.rawValue) {
                                                    onChangeCategory(item, cat)
                                                }
                                            }
                                        }
                                    }
                                    if let onDeleteQuestion {
                                        Divider()
                                        Button("删除题目", role: .destructive) {
                                            onDeleteQuestion(item.id)
                                        }
                                    }
                                }
                                .onTapGesture(count: 2) {
                                    vm.selectedQuestionID = item.id
                                    onLaunchExam(item)
                                }
                                .onTapGesture(count: 1) {
                                    searchFocused = false
                                    vm.selectedQuestionID = item.id
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(28)
            .background(appearance.paper)
            .background(
                StudyKeyboardEventMonitor { event in
                    guard !searchFocused else { return false }
                    switch event.keyCode {
                    case 125: // Down arrow
                        moveSelection(delta: 1, proxy: proxy)
                        return true
                    case 126: // Up arrow
                        moveSelection(delta: -1, proxy: proxy)
                        return true
                    case 36, 76: // Return / Enter
                        launchSelectedQuestion()
                        return true
                    default:
                        return false
                    }
                }
            )
        }
    }
}

struct Task1TopicCardView: View {
    @Environment(\.studyAppearance) private var appearance
    let item: Task1QuestionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text("\(item.id) · \(item.shortTitle)")
                .lumaFont(size: 15, weight: .medium)
                .foregroundStyle(appearance.ink)
                .lineLimit(1)
            Spacer()
            Text(item.category.rawValue)
                .lumaFont(size: 12)
                .foregroundStyle(appearance.ink.opacity(0.68))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(appearance.paper.opacity(0.55)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .padding(.trailing, 32)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? appearance.selected : appearance.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? appearance.accent : appearance.line,
                            lineWidth: isSelected ? 1.5 : 1.0
                        )
                )
        )
    }
}

@MainActor
public final class SplitPaneExamViewModel: ObservableObject {
    @Published public var leftPaneFraction: CGFloat = 0.48
    @Published public var transientBannerMessage: String? = nil
    @Published public var showExitExamConfirmation: Bool = false
    public init() {}
}

public struct IELTSWritingExamSplitPaneView: View {
    @Environment(\.studyAppearance) private var appearance
    public let question: Task1QuestionItem
    @Binding public var draft: WritingExamDraftState
    @StateObject private var vm = SplitPaneExamViewModel()
    public var onAutoSave: (WritingExamDraftState) -> Void
    public var onSubmitExam: (WritingExamDraftState) -> Void
    public var onNavigateBack: (() -> Void)?

    private let policy = ExamEnglishInputPolicy()

    public init(
        question: Task1QuestionItem,
        draft: Binding<WritingExamDraftState>,
        onAutoSave: @escaping (WritingExamDraftState) -> Void,
        onSubmitExam: @escaping (WritingExamDraftState) -> Void,
        onNavigateBack: (() -> Void)? = nil
    ) {
        self.question = question
        self._draft = draft
        self.onAutoSave = onAutoSave
        self.onSubmitExam = onSubmitExam
        self.onNavigateBack = onNavigateBack
    }

    private var activeEssayBinding: Binding<String> {
        Binding(
            get: {
                draft.activePart == .part1 ? draft.part1EssayText : draft.part2EssayText
            },
            set: { newValue in
                if draft.activePart == .part1 {
                    draft.part1EssayText = newValue
                } else {
                    draft.part2EssayText = newValue
                }
                draft.lastSavedAt = Date()
                onAutoSave(draft)
            }
        )
    }

    private var currentWordCount: Int {
        let text = (draft.activePart == .part1) ? draft.part1EssayText : draft.part2EssayText
        return policy.countIELTSWords(in: text)
    }

    private var minimumTargetWords: Int {
        draft.activePart == .part1 ? 150 : 250
    }

    private var formattedRemainingTime: String {
        let mins = max(0, draft.remainingSeconds) / 60
        let secs = max(0, draft.remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func handleBackTap() { onNavigateBack?() }

    private func togglePause() {
        draft.isPaused.toggle()
        draft.lastSavedAt = Date()
        onAutoSave(draft)
    }

    private var isFreeWriting: Bool { draft.questionID == "FREE-WRITING" }

    private var promptPane: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                StudyPromptView(
                    text: draft.activePart == .part1 ? question.promptText : (question.companionTask2Prompt ?? "Write about the following topic."),
                    highlights: Binding(
                        get: { draft.promptHighlights?[draft.activePart.rawValue] ?? [] },
                        set: { ranges in
                            if draft.promptHighlights == nil { draft.promptHighlights = [:] }
                            draft.promptHighlights?[draft.activePart.rawValue] = ranges
                            onAutoSave(draft)
                        }
                    )
                )
                .zIndex(50)

                if draft.activePart == .part1, let dataset = question.chartDataset {
                    Task1ChartCardView(category: question.category, dataset: dataset)
                }
            }
            .padding(18)
        }
        .clipped()
        .frame(minWidth: 220, maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(appearance.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(appearance.line, lineWidth: 1))
        )
    }

    private var editorPane: some View {
        ZStack(alignment: .bottom) {
            ExamEnglishTextEditor(
                text: activeEssayBinding,
                scope: draft.isSingleTaskMode
                    ? (draft.activePart == .part1 ? .ieltsWritingTask1Practice : .ieltsWritingTask2Practice)
                    : .ieltsWritingFullMockExam,
                isEditable: !draft.isPaused,
                fontSize: 15.5,
                onInputRejected: { reasonBanner in
                    showTransientBanner(reasonBanner)
                },
                onExamInputActivated: {
                    showTransientBanner("英文考试输入已启用")
                }
            )
            .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)

            if draft.isPaused {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(appearance.accent)
                    Text("计时已暂停 · 暂停期间不可打字")
                        .lumaFont(size: 13, weight: .semibold)
                        .foregroundStyle(appearance.ink)
                    Button("继续计时") {
                        togglePause()
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 28))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .studyGlassCapsule(cornerRadius: 18, selected: true)
                .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(appearance.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(draft.isPaused ? appearance.accent.opacity(0.65) : appearance.line, lineWidth: draft.isPaused ? 1.5 : 1)
                )
        )
    }

    private func postWritingAction(_ action: String) {
        NotificationCenter.default.post(name: Notification.Name("LumaReader.WritingToolbarAction"), object: nil, userInfo: ["action": action])
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Top Glass Capsule Toolbar (with top-left < 返回 button and clickable timer capsule to pause/resume)
            HStack(spacing: 12) {
                if onNavigateBack != nil {
                    Button {
                        handleBackTap()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12.5, weight: .semibold))
                            Text("返回")
                                .lumaFont(size: 13, weight: .medium)
                        }
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                    .help("选择保存、放弃本次更改或继续编辑")
                }

                Text(draft.examTitle)
                    .lumaFont(size: 19, weight: .semibold, design: .serif)
                    .foregroundStyle(appearance.ink)
                    .lineLimit(1)

                Spacer()

                Menu {
                    Button("模拟考试…") { postWritingAction("mock") }
                    Button("自由写作（无题目）") { postWritingAction("free") }
                    Button("重新开始本篇") { postWritingAction("restart") }
                    Divider()
                    Button("草稿") { postWritingAction("drafts") }
                    Button("历史作文") { postWritingAction("history") }
                    Divider()
                    Button("同步学习数据到云盘") { postWritingAction("sync") }
                    Button("继续阅读") { postWritingAction("reading") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(appearance.ink.opacity(0.82))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(appearance.surface.opacity(0.65)))
                        .overlay(Circle().strokeBorder(appearance.line.opacity(0.55), lineWidth: 0.8))
                        .contentShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("更多：模拟考试、自由写作、草稿、历史与同步")

                Button {
                    NotificationCenter.default.post(name: Notification.Name("LumaReader.AskAIInWriting"), object: nil)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(appearance.accent)
                        Text("AI 助手")
                            .lumaFont(size: 12.5, weight: .medium)
                    }
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 34))
                .help("展开 / 收起 AI 助手（AI 已自动知晓当前写作题目、图表数据与草稿，无需重复提交题目）")

                // 点击计时器胶囊即可暂停/继续计时（暂停时锁定右侧打字）
                Button {
                    togglePause()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: draft.isPaused ? "pause.circle.fill" : "clock")
                            .foregroundStyle(draft.remainingSeconds < 300 ? Color.red : appearance.accent)
                        Text(draft.isPaused ? "\(formattedRemainingTime) · 已暂停" : formattedRemainingTime)
                            .lumaFont(size: 15, weight: .bold, design: .monospaced)
                            .foregroundStyle(draft.remainingSeconds < 300 ? Color.red : appearance.ink)
                    }
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: true, horizontalPadding: 14, height: 34))
                .help(draft.isPaused ? "点击继续计时并恢复打字" : "点击暂停计时（暂停期间不可打字）")

                Button {
                    onSubmitExam(draft)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12))
                        Text("交卷")
                    }
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 34))
            }

            // Task rubric banner
            HStack(spacing: 14) {
                Text(isFreeWriting ? "自由写作" : (draft.activePart == .part1 ? "Task 1 (20 分钟 · ≥150 词)" : "Task 2 (40 分钟 · ≥250 词)"))
                    .lumaFont(size: 14, weight: .bold, design: .serif)
                    .foregroundStyle(appearance.accent)
                Divider()
                    .frame(height: 16)
                    .background(appearance.line)
                Text(
                    isFreeWriting
                        ? "无题目自由发挥 · 完成任意长度的英文写作后即可提交"
                        : (draft.activePart == .part1
                            ? "You should spend about 20 minutes on this task. Write at least 150 words."
                            : "You should spend about 40 minutes on this task. Write at least 250 words.")
                )
                .lumaFont(size: 14, design: .serif)
                .foregroundStyle(appearance.ink.opacity(0.86))
                Spacer()
                Text("纯英文无纠错机考模式 · 草稿实时自动保存")
                    .lumaFont(size: 11.5)
                    .foregroundStyle(appearance.ink.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .studyGlassCapsule(cornerRadius: 14)

            if isFreeWriting {
                editorPane
            } else {
                HSplitView {
                    promptPane
                    editorPane
                }
                .clipped()
            }

            // Bottom Glass Bar: 单项练习 (Task 1 或 Task 2) 只显示当前任务与字数；仅当考试模拟模式 (!draft.isSingleTaskMode) 时显示 Task 1 / Task 2 切换
            HStack(spacing: 14) {
                if !draft.isSingleTaskMode {
                    HStack(spacing: 8) {
                        partSwitchButton(.part1, title: "Task 1 (20m)")
                        partSwitchButton(.part2, title: "Task 2 (40m)")
                    }

                    Divider()
                        .frame(height: 18)
                        .background(appearance.line)

                    Text("当前题号: \(draft.activePart.rawValue)")
                        .lumaFont(size: 12.5, weight: .medium)
                        .foregroundStyle(appearance.ink.opacity(0.75))
                } else {
                    Text(isFreeWriting ? "自由写作" : (draft.activePart == .part1 ? "Task 1 专项练习" : "Task 2 专项练习"))
                        .lumaFont(size: 12.5, weight: .semibold)
                        .foregroundStyle(appearance.accent)
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("实时字数")
                        .lumaFont(size: 12.5)
                        .foregroundStyle(appearance.ink.opacity(0.72))
                    Text("\(currentWordCount) / \(minimumTargetWords) 词")
                        .lumaFont(size: 13.5, weight: .bold, design: .monospaced)
                        .foregroundStyle(currentWordCount >= minimumTargetWords ? appearance.accent : appearance.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .studyGlassCapsule(cornerRadius: 16, selected: currentWordCount >= minimumTargetWords)

                if !draft.isSingleTaskMode {
                    Button {
                        draft.activePart = (draft.activePart == .part1) ? .part2 : .part1
                        draft.lastSavedAt = Date()
                        onAutoSave(draft)
                    } label: {
                        HStack(spacing: 6) {
                            Text(draft.activePart == .part1 ? "下一题 (Task 2)" : "上一题 (Task 1)")
                            Image(systemName: draft.activePart == .part1 ? "arrow.right" : "arrow.left")
                        }
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: true, horizontalPadding: 14, height: 32))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .studyGlassCapsule(cornerRadius: 16)
        }
        .padding(20)
        .background(appearance.paper)
    }

    private func partSwitchButton(_ part: ExamPart, title: String) -> some View {
        let isSelected = (draft.activePart == part)
        return Button {
            draft.activePart = part
            draft.lastSavedAt = Date()
            onAutoSave(draft)
        } label: {
            Text(title)
        }
        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: isSelected, selected: isSelected, horizontalPadding: 14, height: 30))
    }

    private func showTransientBanner(_ message: String) {
        vm.transientBannerMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            if vm.transientBannerMessage == message {
                vm.transientBannerMessage = nil
            }
        }
    }
}

struct Task1ChartCardView: View {
    @Environment(\.studyAppearance) private var appearance
    @State private var chartZoom: CGFloat = 1.0
    @State private var expanded = false
    var allowsExpansion: Bool = true
    let category: Task1ChartCategory
    let dataset: Task1ChartDataset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if allowsExpansion {
                    Button {
                        expanded = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("放大查看图表")
                        }
                        .lumaFont(size: 12, weight: .semibold)
                        .foregroundStyle(Color.black.opacity(0.82))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if !dataset.series.isEmpty && category != .table {
                    HStack(spacing: 6) {
                        Text("图表缩放")
                            .lumaFont(size: 11.5, weight: .medium)
                            .foregroundStyle(Color.black.opacity(0.72))
                        Button {
                            chartZoom = max(1.0, chartZoom - 0.25)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .frame(width: 22, height: 22)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.06)))
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(chartZoom * 100))%")
                            .lumaFont(size: 11.5, weight: .semibold, design: .monospaced)
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(width: 42)

                        Button {
                            chartZoom = min(2.25, chartZoom + 0.25)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .frame(width: 22, height: 22)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.06)))
                        }
                        .buttonStyle(.plain)

                        if chartZoom != 1.0 {
                            Button {
                                chartZoom = 1.0
                            } label: {
                                Text("重置")
                                    .lumaFont(size: 11.5, weight: .medium)
                                    .foregroundStyle(Color.black.opacity(0.82))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !dataset.series.isEmpty && category != .table {
                ScrollView([.horizontal, .vertical]) {
                    Chart {
                        ForEach(dataset.series, id: \.name) { series in
                            ForEach(Array(series.values.enumerated()), id: \.offset) { index, value in
                                if index < dataset.xAxisLabels.count {
                                    if category == .lineGraph {
                                        LineMark(x: .value("类别", dataset.xAxisLabels[index]), y: .value(series.unit, value))
                                            .foregroundStyle(by: .value("系列", series.name))
                                    } else if category == .pieChart {
                                        SectorMark(angle: .value("数值", value))
                                            .foregroundStyle(by: .value("类别", dataset.xAxisLabels[index]))
                                    } else {
                                        BarMark(x: .value("类别", dataset.xAxisLabels[index]), y: .value(series.unit, value))
                                            .foregroundStyle(by: .value("系列", series.name))
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 340 * chartZoom, height: 240 * chartZoom)
                    .padding(12)
                }
                .clipped()
                .frame(height: 280)
            }
            if let pieSlices = dataset.pieSlicePercentages, !pieSlices.isEmpty {
                let sortedSlices = pieSlices.sorted { $0.value > $1.value }
                Chart {
                    ForEach(sortedSlices, id: \.key) { item in
                        SectorMark(
                            angle: .value("占比", item.value),
                            innerRadius: .ratio(0.32),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("类别", item.key))
                    }
                }
                .frame(height: 220)
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sortedSlices, id: \.key) { item in
                        HStack {
                            Text(item.key)
                                .lumaFont(size: 12.5, weight: .medium)
                                .foregroundStyle(.black.opacity(0.85))
                            Spacer()
                            Text(String(format: "%.1f%%", item.value))
                                .lumaFont(size: 12.5, weight: .bold, design: .monospaced)
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.05)))
                    }
                }
            }
            if !dataset.series.isEmpty {
                ForEach(dataset.series, id: \.name) { series in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(series.name) (\(series.unit))")
                            .lumaFont(size: 13, weight: .semibold)
                            .foregroundStyle(.black.opacity(0.85))
                        HStack(spacing: 8) {
                            ForEach(Array(zip(dataset.xAxisLabels, series.values)), id: \.0) { label, val in
                                VStack(spacing: 2) {
                                    Text(String(format: "%.1f", val))
                                        .lumaFont(size: 11, weight: .bold, design: .monospaced)
                                        .foregroundStyle(.black)
                                    Text(label)
                                        .lumaFont(size: 10)
                                        .foregroundStyle(.black.opacity(0.7))
                                }
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
                            }
                        }
                    }
                }
            }
            if let map = dataset.mapComparison {
                StudyMapDiagram(title: map.beforeYearLabel, features: map.beforeFeatures)
                StudyMapDiagram(title: map.afterYearLabel, features: map.afterFeatures)
                DisclosureGroup("地图原始数据") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Before (\(map.beforeYearLabel)):")
                            .lumaFont(size: 13, weight: .bold)
                            .foregroundStyle(.black)
                        ForEach(map.beforeFeatures, id: \.label) { f in
                            Text("• [\(f.region)] \(f.label) (\(f.status))")
                                .lumaFont(size: 12)
                                .foregroundStyle(.black.opacity(0.85))
                        }
                        Divider()
                        Text("After (\(map.afterYearLabel)):")
                            .lumaFont(size: 13, weight: .bold)
                            .foregroundStyle(.black)
                        ForEach(map.afterFeatures, id: \.label) { f in
                            Text("• [\(f.region)] \(f.label) (\(f.status))")
                                .lumaFont(size: 12)
                                .foregroundStyle(.black.opacity(0.85))
                        }
                    }
                }
            }
            if let steps = dataset.processSteps {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(steps, id: \.stepNumber) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("Step \(step.stepNumber)")
                                .lumaFont(size: 11, weight: .bold, design: .monospaced)
                                .foregroundStyle(.black)
                            Text("\(step.title): \(step.detail)")
                                .lumaFont(size: 12)
                                .foregroundStyle(.black.opacity(0.85))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        if step.stepNumber != steps.last?.stepNumber {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(.black.opacity(0.5))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
        .clipped()
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $expanded) {
            VStack {
                HStack {
                    Text("题目图表").font(.title2)
                    Spacer()
                    Button("关闭") { expanded = false }.keyboardShortcut(.cancelAction)
                }
                ScrollView([.horizontal, .vertical]) {
                    Task1ChartCardView(allowsExpansion: false, category: category, dataset: dataset)
                        .frame(width: 860)
                }
            }
            .padding(24)
            .frame(minWidth: 800, minHeight: 600)
        }
    }
}
#endif

// MARK: - Kokoro-82M ONNX + WSOLA Neural Voice Engine Bridge & 4-Slot Settings UI

public enum KokoroVoiceSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    case usFemale = "US_Female"
    case usMale = "US_Male"
    case ukFemale = "UK_Female"
    case ukMale = "UK_Male"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .usFemale: return "美音女声"
        case .usMale: return "美音男声"
        case .ukFemale: return "英音女声"
        case .ukMale: return "英音男声"
        }
    }

    public var kittenDisplayName: String {
        switch self {
        case .usFemale: return "Kitten 女声 1"
        case .ukFemale: return "Kitten 女声 2"
        case .usMale: return "Kitten 男声 1"
        case .ukMale: return "Kitten 男声 2"
        }
    }

    fileprivate var kittenVoices: [String] {
        switch self {
        case .usFemale, .ukFemale: return ["Bella", "Luna", "Rosie", "Kiki"]
        case .usMale, .ukMale: return ["Jasper", "Bruno", "Hugo", "Leo"]
        }
    }

    public var defaultVoice: String {
        switch self {
        case .usFemale: return "af_heart"
        case .usMale: return "am_adam"
        case .ukFemale: return "bf_emma"
        case .ukMale: return "bm_george"
        }
    }

    public var accent: TTSVoiceAccent {
        switch self {
        case .ukFemale, .ukMale: return .british
        case .usFemale, .usMale: return .american
        }
    }
}

#if canImport(SwiftUI) && canImport(AppKit)
import CryptoKit

@MainActor
public final class KokoroNeuralBridge: NSObject, ObservableObject {
    public static let shared = KokoroNeuralBridge()

    public static let kittenVoiceList: [String] = ["Bella", "Jasper", "Luna", "Bruno", "Rosie", "Hugo", "Kiki", "Leo"]
    public static let kittenDefaultSlots: [KokoroVoiceSlot: String] = [
        .usFemale: "Bella",
        .usMale: "Jasper",
        .ukFemale: "Luna",
        .ukMale: "Bruno"
    ]

    @Published public var isReady: Bool = false
    @Published public var statusText: String = "正在检测本地神经语音引擎..."
    @Published public var currentSlot: KokoroVoiceSlot = {
        if let raw = UserDefaults.standard.string(forKey: "LumaReader.KokoroCurrentSlot"),
           let slot = KokoroVoiceSlot(rawValue: raw) {
            return slot
        }
        return .ukFemale
    }() {
        didSet {
            UserDefaults.standard.set(currentSlot.rawValue, forKey: "LumaReader.KokoroCurrentSlot")
            let voiceName = activeSlots[currentSlot] ?? defaultVoice(for: currentSlot, model: selectedModel)
            if isReady {
                statusText = "\(modelTitle) 已就绪 · \(voiceName)"
            }
            syncSlotsToDaemon()
        }
    }
    @Published public var activeSlots: [KokoroVoiceSlot: String] = KokoroNeuralBridge.kittenDefaultSlots

    // exclusive_models_v8
    @Published public var useAppleSystemSpeech: Bool = UserDefaults.standard.bool(forKey: "LumaReader.UseAppleSystemSpeech") {
        didSet {
            UserDefaults.standard.set(useAppleSystemSpeech, forKey: "LumaReader.UseAppleSystemSpeech")
        }
    }
    @Published public private(set) var selectedModel = "kitten-micro"
    @Published public private(set) var isSwitching = false
    @Published public private(set) var isPreparingAudio = false
    @Published public private(set) var isInstallingModels = false
    @Published public private(set) var installedModels: Set<String> = []
    private var activeSpeechRequestID: UUID?
    private var pendingRequestKey: String?
    private var pendingPlaybackIntent: (speed: Float, repeats: Int, interval: Double)?
    private var isServiceOnline = false
    private var daemonLoadFailed = false
    private var modelSwitchTask: Task<Void, Never>?

    public static func title(for model: String) -> String {
        switch model {
        case "kitten-nano": return "Kitten Nano · 15M"
        case "kitten-micro": return "Kitten Micro · 40M"
        default: return "Kitten Micro · 40M"
        }
    }

    public var modelTitle: String {
        Self.title(for: selectedModel)
    }

    public func defaultVoice(for slot: KokoroVoiceSlot, model: String? = nil) -> String {
        Self.kittenDefaultSlots[slot] ?? "Bella"
    }

    public func voicesForSlot(_ slot: KokoroVoiceSlot) -> [String] {
        slot.kittenVoices
    }

    private func validatedVoice(_ candidate: String?, for slot: KokoroVoiceSlot) -> String {
        guard let candidate, slot.kittenVoices.contains(candidate) else { return defaultVoice(for: slot) }
        return candidate
    }

    private func applyServerSlots(_ raw: [String: String]) {
        activeSlots = Dictionary(uniqueKeysWithValues: KokoroVoiceSlot.allCases.map { slot in
            (slot, validatedVoice(raw[slot.rawValue], for: slot))
        })
    }

    private func applyLocalCatalogAndSlots(for model: String) {
        let saved = loadExclusiveEngineVoices(for: model)
        activeSlots = Dictionary(uniqueKeysWithValues: KokoroVoiceSlot.allCases.map { slot in
            (slot, validatedVoice(saved[slot], for: slot))
        })
    }

    public func switchModel(_ model: String) {
        guard !isInstallingModels, !isSwitching, ["kitten-nano", "kitten-micro"].contains(model) else { return }
        useAppleSystemSpeech = false
        stop()
        modelSwitchTask?.cancel()
        isSwitching = true
        isReady = false
        selectedModel = model
        applyLocalCatalogAndSlots(for: model)
        persistExclusiveEngineConfig(model: model, slots: activeSlots)
        statusText = "正在卸载旧模型并加载 \(modelTitle)…"
        modelSwitchTask = Task { @MainActor in
            defer { isSwitching = false }
            await ensureDaemonRunning(preserveSelectedModel: true)
            guard !Task.isCancelled else { return }
            isReady = false
            do {
                guard let url = URL(string: "http://127.0.0.1:\(port)/engine") else { return }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 300
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["model": model])
                let (data, response) = try await URLSession.shared.data(for: req)
                try Task.checkCancellation()
                let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw NSError(domain: "SpeechModel", code: 1, userInfo: [NSLocalizedDescriptionKey: result?["error"] as? String ?? "模型切换失败"])
                }
                if let slots = result?["active_slots"] as? [String: String] {
                    applyServerSlots(slots)
                }
                _ = await checkStatus(preserveSelectedModel: true)
                refreshInstalledModels()
            } catch is CancellationError {
                return
            } catch {
                // A missing/corrupt model must not pretend to be active; fall back to the
                // system voice so dictation still speaks instead of silently failing.
                isReady = false
                statusText = "\(modelTitle) 启动失败：\(error.localizedDescription)"
            }
        }
    }

    public func selectVoice(_ voice: String, for slot: KokoroVoiceSlot, previewText: String? = nil) {
        guard slot.kittenVoices.contains(voice) else { return }
        useAppleSystemSpeech = false
        var updated = activeSlots
        updated[slot] = voice
        activeSlots = updated
        if currentSlot != slot {
            currentSlot = slot
        }
        saveSlots(updated)
        let currentVoice = updated[currentSlot] ?? voice
        statusText = "\(modelTitle) 已就绪 · \(currentVoice)"
        if let sample = previewText?.trimmingCharacters(in: .whitespacesAndNewlines), !sample.isEmpty {
            _ = play(text: sample, speed: 1.0, voiceOverride: voice)
        }
    }

    public var hasBundledModels: Bool {
        guard let resources = Bundle.main.resourceURL else { return false }
        return FileManager.default.fileExists(atPath: resources.appendingPathComponent("KittenSpeech/manifest.json").path)
    }

    public func refreshInstalledModels() {
        if hasBundledModels {
            installedModels = ["kitten-nano", "kitten-micro"]
            return
        }
        var found = Set<String>()
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let eng = home.appendingPathComponent("Library/Application Support/LumaReader/KokoroEngine", isDirectory: true)
        let tts = home.appendingPathComponent("Library/Application Support/LumaReader/KokoroTTS", isDirectory: true)

        for (modelKey, slug) in [
            ("kitten-micro", "models--KittenML--kitten-tts-micro-0.8"),
            ("kitten-nano", "models--KittenML--kitten-tts-nano-0.8-int8")
        ] {
            let cacheCandidates = [
                eng.appendingPathComponent("kitten-cache/\(slug)"),
                tts.appendingPathComponent("kitten-cache/\(slug)")
            ]
            if cacheCandidates.contains(where: { fm.fileExists(atPath: $0.path) }) {
                found.insert(modelKey)
            }
        }

        for instURL in [
            eng.appendingPathComponent("models-installed.json"),
            tts.appendingPathComponent("models-installed.json")
        ] {
            if let data = try? Data(contentsOf: instURL),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                for (k, pathStr) in dict where fm.fileExists(atPath: pathStr) {
                    found.insert(k)
                }
            }
        }
        installedModels = found.intersection(["kitten-micro", "kitten-nano"])
    }

    public func isModelInstalled(_ model: String) -> Bool {
        installedModels.contains(model)
    }

    public func deleteModel(_ model: String) {
        guard !hasBundledModels else { return }
        guard ["kitten-micro", "kitten-nano"].contains(model) else { return }
        stop()
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let eng = home.appendingPathComponent("Library/Application Support/LumaReader/KokoroEngine", isDirectory: true)
        let tts = home.appendingPathComponent("Library/Application Support/LumaReader/KokoroTTS", isDirectory: true)

        let slug = model == "kitten-micro" ? "models--KittenML--kitten-tts-micro-0.8" : "models--KittenML--kitten-tts-nano-0.8-int8"
        for directory in [eng.appendingPathComponent("kitten-cache"), tts.appendingPathComponent("kitten-cache")] {
            let target = directory.appendingPathComponent(slug)
            if fm.fileExists(atPath: target.path) { try? fm.removeItem(at: target) }
        }

        for instURL in [eng.appendingPathComponent("models-installed.json"), tts.appendingPathComponent("models-installed.json")] {
            if let data = try? Data(contentsOf: instURL),
               var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] {
                if let customPath = dict.removeValue(forKey: model) {
                    let candidate = URL(fileURLWithPath: customPath).resolvingSymlinksInPath().standardizedFileURL
                    let allowed = [eng, tts].map { $0.appendingPathComponent("kitten-cache/\(slug)").resolvingSymlinksInPath().standardizedFileURL }
                    if allowed.contains(where: { candidate == $0 || candidate.path.hasPrefix($0.path + "/") }) {
                        try? fm.removeItem(at: candidate)
                    }
                }
                if let updated = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) {
                    try? updated.write(to: instURL, options: .atomic)
                }
            }
        }

        Task { @MainActor in
            if let url = URL(string: "http://127.0.0.1:\(port)/delete_model") {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 10
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model])
                _ = try? await URLSession.shared.data(for: req)
            }
            refreshInstalledModels()
            let deletedTitle = Self.title(for: model)
            if selectedModel == model {
                let fallbackOrder = ["kitten-micro", "kitten-nano"].filter { $0 != model }
                if let nextInstalled = fallbackOrder.first(where: { installedModels.contains($0) }) {
                    switchModel(nextInstalled)
                    statusText = "已删除 \(deletedTitle)，已自动切换至 \(Self.title(for: nextInstalled))"
                } else {
                    useAppleSystemSpeech = true
                    statusText = "已删除 \(deletedTitle) 模型文件，已自动切换为 macOS 系统原生语音"
                }
            } else {
                statusText = "已删除 \(deletedTitle) 模型文件（释放本地磁盘空间）"
            }
        }
    }

    public func revealModelDirectoryInFinder() {
        let dir = engineDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    private var player: AVAudioPlayer?
    private var repeatTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    // cancel_speech_v3
    private var synthesisTask: Task<Void, Never>?
    private let port: Int = 18880
    private var isLaunchingDaemon = false
    private var ownedDaemon: Process?
    private var daemonLog: FileHandle?
    private var runtimeObservers: [NSObjectProtocol] = []
    private var runtimeSuspended = false
    private var backgroundReleaseTask: Task<Void, Never>?
    private var cacheTouches: [String: Date] = [:]
    private let cacheMetadataQueue = DispatchQueue(label: "luma.speech.cache-metadata", qos: .utility)
    private func releaseOwnedWorker() {
        if let process = ownedDaemon, process.isRunning { process.terminate() }
        ownedDaemon = nil
        try? daemonLog?.close(); daemonLog = nil
        isReady = false; isServiceOnline = false
    }


    private func suspendRuntime(terminateWorker: Bool) {
        runtimeSuspended = true
        modelSwitchTask?.cancel(); modelSwitchTask = nil
        stop()
        backgroundReleaseTask?.cancel(); backgroundReleaseTask = nil
        if terminateWorker { releaseOwnedWorker() }
        else {
            suspendPreload()
            backgroundReleaseTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard let self, self.runtimeSuspended else { return }
                self.releaseOwnedWorker()
            }
        }
    }


    public var engineDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let eng = home.appendingPathComponent("Library/Application Support/LumaReader/KokoroEngine", isDirectory: true)
        let tts = home.appendingPathComponent("Library/Application Support/LumaReader/KokoroTTS", isDirectory: true)
        for directory in [eng, tts] {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("models-installed.json").path) {
                return directory
            }
        }
        if FileManager.default.fileExists(atPath: eng.appendingPathComponent("kokoro_neural_daemon.py").path)
            || FileManager.default.fileExists(atPath: eng.appendingPathComponent("kokoro-v1.0.onnx").path) {
            return eng
        }
        if FileManager.default.fileExists(atPath: tts.appendingPathComponent("kokoro_neural_daemon.py").path)
            || FileManager.default.fileExists(atPath: tts.appendingPathComponent("kokoro-v1.0.onnx").path)
            || FileManager.default.fileExists(atPath: tts.appendingPathComponent("models/kokoro-v1.0.onnx").path) {
            return tts
        }
        return eng
    }

    public override init() {
        super.init()
        let center = NotificationCenter.default
        for name in [Notification.Name("LumaReader.AppDidResignActive"), NSApplication.willTerminateNotification] {
            runtimeObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                // Notification.userInfo is not Sendable. Extract the immutable value
                // before entering the main-actor closure; never send the notification itself.
                let terminateWorker = note.name == NSApplication.willTerminateNotification || note.userInfo?["sleep"] as? Bool == true
                MainActor.assumeIsolated {
                    self?.suspendRuntime(terminateWorker: terminateWorker)
                }
            })
        }
        runtimeObservers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.runtimeSuspended = false; self?.backgroundReleaseTask?.cancel() }
        })
        runtimeObservers.append(center.addObserver(forName: Notification.Name("LumaReader.RuntimeDidResume"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.runtimeSuspended = !NSApp.isActive }
        })
        runtimeObservers.append(center.addObserver(forName: Notification.Name("LumaReader.MemoryPressure"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isPreparingAudio, !EmbeddedNeuralSpeechEngine.shared.isPlaying else { return }
                self.releaseOwnedWorker()
            }
        })
        syncBundledDaemonScriptsIfNeeded()
        loadLocalSlotsConfig()
        refreshInstalledModels()
    }

    private var isRunningInTestRunner: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.processName.lowercased().contains("test")
    }

    private func syncBundledDaemonScriptsIfNeeded() {
        guard !isRunningInTestRunner, let resDir = Bundle.main.resourceURL else { return }
        let fm = FileManager.default
        let targetDir = engineDirectory
        try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        for scriptName in ["kokoro_neural_daemon.py", "exclusive_tts.py", "audio_priority_queue.py", "audio_cache_budget.py", "bounded_onnx.py"] {
            let bundled = resDir.appendingPathComponent(scriptName)
            let dest = targetDir.appendingPathComponent(scriptName)
            guard fm.fileExists(atPath: bundled.path) else { continue }
            let bundledData = try? Data(contentsOf: bundled)
            let destData = try? Data(contentsOf: dest)
            if bundledData != nil && bundledData != destData {
                try? bundledData?.write(to: dest, options: .atomic)
            }
        }
    }

    private func loadExclusiveEngineVoices(for model: String) -> [KokoroVoiceSlot: String] {
        let exclusiveURL = engineDirectory.appendingPathComponent("config/exclusive-engine.json")
        guard let data = try? Data(contentsOf: exclusiveURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let voicesRoot = root["voices"] as? [String: [String: String]],
              let modelMap = voicesRoot[model] else {
            return [:]
        }
        var result: [KokoroVoiceSlot: String] = [:]
        for slot in KokoroVoiceSlot.allCases {
            if let v = modelMap[slot.rawValue], !v.isEmpty {
                result[slot] = v
            }
        }
        return result
    }

    private func persistExclusiveEngineConfig(model: String, slots: [KokoroVoiceSlot: String]) {
        let configDir = engineDirectory.appendingPathComponent("config", isDirectory: true)
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let exclusiveURL = configDir.appendingPathComponent("exclusive-engine.json")
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: exclusiveURL),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = parsed
        }
        root["model"] = model
        var voicesMap = (root["voices"] as? [String: [String: String]]) ?? [:]
        var rawDict: [String: String] = [:]
        for (k, v) in slots { rawDict[k.rawValue] = v }
        voicesMap[model] = rawDict
        root["voices"] = voicesMap
        if let outData = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
            try? outData.write(to: exclusiveURL, options: .atomic)
        }
    }

    public func loadLocalSlotsConfig() {
        let exclusiveURL = engineDirectory.appendingPathComponent("config/exclusive-engine.json")
        if let data = try? Data(contentsOf: exclusiveURL),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let savedModel = root["model"] as? String,
           ["kitten-micro", "kitten-nano"].contains(savedModel) {
            selectedModel = savedModel
        }
        applyLocalCatalogAndSlots(for: selectedModel)
        let configURL = engineDirectory.appendingPathComponent("config/voices.json")
        if selectedModel == "kokoro",
           let data = try? Data(contentsOf: configURL),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            for slot in KokoroVoiceSlot.allCases {
                if let v = dict[slot.rawValue], !v.isEmpty {
                    activeSlots[slot] = v
                }
            }
        }
    }

    private func syncSlotsToDaemon() {
        var rawDict: [String: String] = [:]
        for (k, v) in activeSlots { rawDict[k.rawValue] = v }
        let curSlotRaw = currentSlot.rawValue
        Task {
            guard let url = URL(string: "http://127.0.0.1:\(port)/slots") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "active_slots": rawDict,
                "current_slot": curSlotRaw
            ])
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    public func saveSlots(_ selections: [KokoroVoiceSlot: String]) {
        let updated = Dictionary(uniqueKeysWithValues: KokoroVoiceSlot.allCases.map { slot in
            (slot, validatedVoice(selections[slot] ?? activeSlots[slot], for: slot))
        })
        activeSlots = updated
        let configDir = engineDirectory.appendingPathComponent("config", isDirectory: true)
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        var rawDict: [String: String] = [:]
        for (k, v) in updated { rawDict[k.rawValue] = v }
        if let data = try? JSONSerialization.data(withJSONObject: rawDict, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: configDir.appendingPathComponent("voices.json"), options: .atomic)
        }
        persistExclusiveEngineConfig(model: selectedModel, slots: updated)
        syncSlotsToDaemon()
    }

    public func installLocalModels() async {
        guard !isInstallingModels, !isSwitching else { return }
        guard let script = Bundle.main.resourceURL?.appendingPathComponent("install-neural-voices.sh"),
              FileManager.default.fileExists(atPath: script.path) else {
            statusText = "安装失败：缺少语音安装脚本"
            return
        }
        isInstallingModels = true
        defer { isInstallingModels = false }
        stop()
        releaseOwnedWorker()
        statusText = "正在检查和安装 Kitten Nano / Micro…"
        let directory = engineDirectory
        let logURL = directory.appendingPathComponent("model-install.log")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: logURL, options: .atomic)
            let log = try FileHandle(forWritingTo: logURL)
            defer { try? log.close() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [script.path, directory.path]
            if hasBundledModels, let resources = Bundle.main.resourceURL {
                process.arguments?.append(resources.appendingPathComponent("KittenSpeech").path)
            }
            process.standardOutput = log
            process.standardError = log
            try process.run()
            while process.isRunning {
                try await Task.sleep(for: .milliseconds(350))
            }
            refreshInstalledModels()
            if process.terminationStatus == 0 {
                useAppleSystemSpeech = false
                isInstallingModels = false
                await ensureDaemonRunning(preserveSelectedModel: true)
                if !isReady && runtimeSuspended { statusText = "模型已安装，返回 App 后点试听加载。" }
            } else {
                statusText = "模型安装失败。通过模型管理打开目录，查看 model-install.log。"
            }
        } catch {
            statusText = "模型安装失败：\(error.localizedDescription)"
        }
    }

    public func ensureDaemonRunning(preserveSelectedModel: Bool = false) async {
        guard !isRunningInTestRunner, !isInstallingModels, !runtimeSuspended, !Task.isCancelled else { return }
        syncBundledDaemonScriptsIfNeeded()
        if await checkStatus(preserveSelectedModel: preserveSelectedModel) { return }
        guard !runtimeSuspended, !Task.isCancelled else { return }
        if isServiceOnline {
            for _ in 0..<40 {
                if Task.isCancelled || daemonLoadFailed { return }
                try? await Task.sleep(for: .milliseconds(250))
                if await checkStatus(preserveSelectedModel: preserveSelectedModel) { return }
            }
            return
        }
        if !isLaunchingDaemon {
            isLaunchingDaemon = true
            defer { isLaunchingDaemon = false }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let engDir = home.appendingPathComponent("Library/Application Support/LumaReader/KokoroEngine", isDirectory: true)
            let ttsDir = home.appendingPathComponent("Library/Application Support/LumaReader/KokoroTTS", isDirectory: true)
            let directory = engineDirectory
            let roots = [directory, engDir, ttsDir]
            let daemonCandidates = roots.map { $0.appendingPathComponent("kokoro_neural_daemon.py") }
            let venvCandidates = roots.map { $0.appendingPathComponent("venv/bin/python3") }
            guard let python = venvCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
                statusText = "本地语音环境缺失，请点击「安装／修复本地模型」。"
                return
            }
            if ownedDaemon?.isRunning != true,
               let daemonPy = daemonCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                let process = Process()
                process.executableURL = python
                process.arguments = [daemonPy.path]
                var environment = ProcessInfo.processInfo.environment
                environment["LUMA_OWNER_PID"] = String(ProcessInfo.processInfo.processIdentifier)
                environment["LUMA_KOKORO_DIR"] = engineDirectory.path
                if hasBundledModels, let resources = Bundle.main.resourceURL {
                    environment["LUMA_KITTEN_BUNDLE"] = resources.appendingPathComponent("KittenSpeech").path
                    environment["HF_HUB_OFFLINE"] = "1"
                }
                process.environment = environment
                let logURL = engineDirectory.appendingPathComponent("daemon.log")
                if !FileManager.default.fileExists(atPath: logURL.path) { FileManager.default.createFile(atPath: logURL.path, contents: nil) }
                try? daemonLog?.close()
                daemonLog = try? FileHandle(forWritingTo: logURL)
                try? daemonLog?.truncate(atOffset: 0)
                process.standardOutput = daemonLog ?? FileHandle.nullDevice
                process.standardError = daemonLog ?? FileHandle.nullDevice
                do { try process.run(); ownedDaemon = process }
                catch { statusText = "语音服务启动失败：\(error.localizedDescription)"; return }
            }
            for _ in 0..<25 {
                guard !runtimeSuspended, !Task.isCancelled else { return }
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                if await checkStatus(preserveSelectedModel: preserveSelectedModel) { return }
                if daemonLoadFailed { return }
                if let worker = ownedDaemon, !worker.isRunning { return }
            }
        } else {
            for _ in 0..<20 {
                guard !runtimeSuspended, !Task.isCancelled else { return }
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                if await checkStatus(preserveSelectedModel: preserveSelectedModel) { return }
            }
        }
    }

    @discardableResult
    public func checkStatus(preserveSelectedModel: Bool = false) async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/status") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2.5
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            isServiceOnline = false
            daemonLoadFailed = false
            isReady = false
            statusText = "本地语音未启动。请尝试安装／修复模型，或查看模型目录中的 daemon.log。"
            return false
        }
        isServiceOnline = true
        let daemonModel = (json["model_id"] as? String) ?? selectedModel
        if !preserveSelectedModel && !isSwitching {
            if ["kitten-micro", "kitten-nano"].contains(daemonModel) {
                selectedModel = daemonModel
            }
        }
        let ready = (json["neural_loaded"] as? Bool) ?? false
        isReady = ready
        daemonLoadFailed = !ready && json["error"] is String
        if daemonModel == selectedModel, let slots = json["active_slots"] as? [String: String] {
            applyServerSlots(slots)
        }
        if ready {
            let voiceName = activeSlots[currentSlot] ?? defaultVoice(for: currentSlot, model: selectedModel)
            statusText = "\(modelTitle) 已就绪 · \(voiceName)"
        } else if let err = json["error"] as? String {
            statusText = "\(modelTitle) 加载失败：\(err)"
        } else {
            statusText = "正在加载 \(modelTitle)…"
        }
        refreshInstalledModels()
        return ready
    }

    private func stretchedCacheURL(text: String, voice: String, speed: Float) -> URL {
        let normSpeed = String(format: "%.2f", max(0.5, min(2.5, Double(speed))))
        let rawKey = "audio-v9_\(selectedModel)_\(text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())_\(voice)_\(normSpeed)"
        let digest = Insecure.MD5.hash(data: Data(rawKey.utf8)).map { String(format: "%02x", $0) }.joined()
        return engineDirectory.appendingPathComponent("cache/stretched/\(digest).wav")
    }

    public func stop() {
        synthesisTask?.cancel(); synthesisTask = nil
        activeSpeechRequestID = nil; pendingRequestKey = nil; pendingPlaybackIntent = nil; isPreparingAudio = false
        EmbeddedNeuralSpeechEngine.shared.stop()
        repeatTask?.cancel()
        repeatTask = nil
        preloadTask?.cancel()
        preloadTask = nil
        player?.stop()
        player = nil
    }

    /// Plays the word using Kitten ONNX + WSOLA time-stretching + 80ms silence padding.
    /// Returns true if neural playback succeeded or started asynchronously.
    @discardableResult
    public func play(text: String, speed: Float, voiceOverride: String? = nil, repeats: Int = 1, interval: Double = 0.5, onFailure: (@MainActor () -> Void)? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !runtimeSuspended, !trimmed.isEmpty, !isSwitching, !isInstallingModels else { return false }
        if let process = ownedDaemon, !process.isRunning { isReady = false; isServiceOnline = false }
        let model = selectedModel
        let voice = voiceOverride ?? activeSlots[currentSlot] ?? defaultVoice(for: currentSlot, model: model)
        let key = "\(model)|\(voice)|\(trimmed)"
        let intent = (speed: min(2.5, max(0.5, speed)), repeats: min(5, max(1, repeats)), interval: max(0, interval))
        // Replaying a word that is still generating keeps its existing request alive.
        if isPreparingAudio, pendingRequestKey == key {
            pendingPlaybackIntent = intent
            statusText = "正在准备 \(trimmed)，音频就绪后会播放…"
            return true
        }
        stop()
        let rate = min(2.5, max(0.5, speed))
        let cached = stretchedCacheURL(text: trimmed, voice: voice, speed: 1.0)
        if FileManager.default.fileExists(atPath: cached.path) {
            playWAVFile(at: cached, text: trimmed, speed: rate, repeats: repeats, interval: interval, onFailure: onFailure)
            return true
        }
        let requestID = UUID()
        activeSpeechRequestID = requestID
        pendingRequestKey = key
        pendingPlaybackIntent = intent
        isPreparingAudio = true
        statusText = "正在准备 \(trimmed)…"
        synthesisTask = Task { @MainActor in
            defer {
                if activeSpeechRequestID == requestID {
                    isPreparingAudio = false
                    pendingRequestKey = nil
                    pendingPlaybackIntent = nil
                    activeSpeechRequestID = nil
                    synthesisTask = nil
                }
            }
            if !isReady {
                await ensureDaemonRunning(preserveSelectedModel: true)
            }
            guard !Task.isCancelled, activeSpeechRequestID == requestID, !runtimeSuspended else { return }
            guard isReady else { onFailure?(); return }
            do {
                guard let url = URL(string: "http://127.0.0.1:\(port)/synthesize") else { return }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 60
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["text": trimmed, "voice": voice, "slot": currentSlot.rawValue, "speed": 1.0, "engine": model])
                let (data, response) = try await URLSession.shared.data(for: req)
                try Task.checkCancellation()
                guard activeSpeechRequestID == requestID, selectedModel == model else { return }
                let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let path = result?["wav_path"] as? String,
                      FileManager.default.fileExists(atPath: path) else {
                    statusText = "语音生成失败：\(result?["error"] as? String ?? "没有收到可播放音频")"
                    onFailure?()
                    return
                }
                let latest = pendingPlaybackIntent ?? intent
                playWAVFile(at: URL(fileURLWithPath: path), text: trimmed, speed: latest.speed, repeats: latest.repeats, interval: latest.interval, onFailure: onFailure)
                statusText = "\(modelTitle) · \(voice)"
            } catch {
                if !Task.isCancelled, activeSpeechRequestID == requestID {
                    statusText = "语音请求失败：\(error.localizedDescription)"
                    onFailure?()
                }
            }
        }
        return true
    }

    // native_cached_audio_v6: reuse one 1.0x file for every playback speed.
    private func playWAVFile(at url: URL, text: String, speed: Float, repeats: Int, interval: Double, onFailure: (@MainActor () -> Void)?) {
        let now = Date()
        if now.timeIntervalSince(cacheTouches[url.path] ?? .distantPast) > 3600 {
            if cacheTouches.count >= 256 { cacheTouches.removeAll(keepingCapacity: true) }
            cacheTouches[url.path] = now
            cacheMetadataQueue.async { try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path) }
        }
        EmbeddedNeuralSpeechEngine.shared.playCachedAudio(at: url, text: text, speed: speed, repeats: repeats, interval: interval) { [weak self] in
            self?.statusText = "语音播放失败，请重新试听。"
            onFailure?()
        }
    }

    public func suspendPreload() {
        preloadTask?.cancel()
        preloadTask = Task {
            guard let url = URL(string: "http://127.0.0.1:\(port)/suspend") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 2
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["phrases": [String]()])
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    // final_audio_prefetch_v4
    public func preload(phrases: [String], startIndex: Int = 0, speed: Float = 1.0) {
        guard !runtimeSuspended, isReady, !isSwitching, !phrases.isEmpty else { return }
        let slotRaw = currentSlot.rawValue
        let bounded = Array(phrases.dropFirst(max(0, startIndex)).prefix(3)) // rolling_audio_v5
        guard !bounded.isEmpty else { return }
        preloadTask?.cancel()
        preloadTask = Task {
            guard let url = URL(string: "http://127.0.0.1:\(port)/preload") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Any] = [
                "speed": 1.0,
                "engine": selectedModel,
                "phrases": bounded,
                "start_idx": 0,
                "current_slot": slotRaw
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}

public struct KokoroVoiceSettingsSheet: View {
    @Environment(\.studyAppearance) private var appearance
    @ObservedObject public var kokoro: KokoroNeuralBridge
    public var sampleWord: String
    /// 嵌入到统一「发音设置」弹窗中时为 true：不显示大标题与取消按钮，改动立即保存。
    public var embedded: Bool
    public var onClose: () -> Void

    @State private var draftSlots: [KokoroVoiceSlot: String] = [:]

    public init(kokoro: KokoroNeuralBridge, sampleWord: String, embedded: Bool = false, onClose: @escaping () -> Void) {
        self.kokoro = kokoro
        self.sampleWord = sampleWord
        self.embedded = embedded
        self.onClose = onClose
        self._draftSlots = State(initialValue: kokoro.activeSlots)
    }

    private func voiceBinding(_ slot: KokoroVoiceSlot) -> Binding<String> {
        Binding(
            get: { draftSlots[slot] ?? kokoro.activeSlots[slot] ?? kokoro.defaultVoice(for: slot) },
            set: { value in
                draftSlots[slot] = value
                let preview = sampleWord.isEmpty ? "Luma Reader" : sampleWord
                kokoro.selectVoice(value, for: slot, previewText: preview)
            }
        )
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(kokoro.isReady ? appearance.accent : appearance.ink.opacity(0.38))
                .frame(width: 7, height: 7)
            Text(kokoro.statusText)
                .lumaFont(size: 12)
                .foregroundStyle(appearance.ink.opacity(0.65))
                .lineLimit(3)
                .help(kokoro.statusText)
            Spacer()
            Button {
                Task {
                    await kokoro.ensureDaemonRunning()
                    draftSlots = kokoro.activeSlots
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 10, height: 28))
            .help("刷新模型状态")
            .accessibilityLabel("刷新模型状态")
        }
    }

    private func slotRow(_ slot: KokoroVoiceSlot) -> some View {
        HStack(spacing: 14) {
            Text(slot.kittenDisplayName)
                .lumaFont(size: 14, weight: .medium)
                .foregroundStyle(appearance.ink)
                .frame(width: 80, alignment: .leading)
            Picker(slot.kittenDisplayName, selection: voiceBinding(slot)) {
                ForEach(kokoro.voicesForSlot(slot), id: \.self) { voice in
                    Text(voice).tag(voice)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 180)
            Spacer()
            Button {
                kokoro.useAppleSystemSpeech = false
                let chosen: String = draftSlots[slot] ?? kokoro.activeSlots[slot] ?? kokoro.defaultVoice(for: slot)
                let sample: String = sampleWord.isEmpty ? "Luma Reader" : sampleWord
                _ = kokoro.play(text: sample, speed: 1.0, voiceOverride: chosen)
            } label: {
                Label("试听", systemImage: "play.fill")
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 30))
        }
        .padding(.vertical, 10)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !embedded {
                Text("神经语音发音设置")
                    .lumaFont(size: 20, weight: .medium)
                    .foregroundStyle(appearance.ink)
            }

            statusRow
            Button {
                Task {
                    await kokoro.installLocalModels()
                    draftSlots = kokoro.activeSlots
                }
            } label: {
                Label(kokoro.isInstallingModels ? "正在安装模型…" : "安装／修复本地模型", systemImage: "arrow.down.circle")
            }
            .disabled(kokoro.isInstallingModels || kokoro.isSwitching)
            HStack(spacing: 10) {
                Picker("语音模型", selection: Binding(get: { kokoro.selectedModel }, set: { kokoro.switchModel($0) })) {
                    Text("Kitten Nano · 15M · 省资源").tag("kitten-nano")
                    Text("Kitten Micro · 40M").tag("kitten-micro")
                }
                .pickerStyle(.menu)
                .disabled(kokoro.isSwitching || kokoro.isInstallingModels)

                Menu {
                    Button(role: .destructive) {
                        kokoro.deleteModel("kitten-micro")
                    } label: {
                        Label("删除 Kitten Micro · 40M 模型文件", systemImage: "trash")
                    }
                    Button(role: .destructive) {
                        kokoro.deleteModel("kitten-nano")
                    } label: {
                        Label("删除 Kitten Nano · 15M 模型文件", systemImage: "trash")
                    }
                    Divider()
                    Button {
                        kokoro.revealModelDirectoryInFinder()
                    } label: {
                        Label("在 Finder 中打开模型目录…", systemImage: "folder")
                    }
                } label: {
                    Label("模型管理", systemImage: "trash.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            if kokoro.isSwitching { ProgressView("正在切换模型…").controlSize(.small) }

            VStack(spacing: 0) {
                ForEach(KokoroVoiceSlot.allCases) { slot in
                    slotRow(slot)
                    if slot != KokoroVoiceSlot.allCases.last {
                        Divider().opacity(0.4)
                    }
                }
            }
            .disabled(kokoro.isSwitching || kokoro.isInstallingModels)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appearance.surface)
            )

            Spacer(minLength: 0)

            HStack {
                if !embedded {
                    Button("取消") {
                        onClose()
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 16, height: 34))
                }
                Spacer()
                Button(embedded ? "完成" : "保存") {
                    kokoro.saveSlots(draftSlots)
                    onClose()
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 20, height: 34))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(maxWidth: embedded ? .infinity : 460, maxHeight: embedded ? .infinity : nil, alignment: .topLeading)
        .background(appearance.paper)
        .task {
            await kokoro.ensureDaemonRunning()
            draftSlots = kokoro.activeSlots
        }
        .onReceive(kokoro.$activeSlots) { slots in draftSlots = slots }
    }
}
#endif
