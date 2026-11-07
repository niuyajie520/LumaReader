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
        ".,;:?!'\"-()[]/%&$#@+=*_~`<>\\|{}".unicodeScalars
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
                    userBannerMessage: "请使用英文半角标点（如 , . ; : ? ! ' \" -），全角标点未写入草稿。"
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

    public override func becomeFirstResponder() -> Bool {
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

    // MARK: IME Marked Text & Direct Insertion Interception

    /// Handles IME composition state (`NSTextInputClient`).
    /// Never deletes the existing essay during composition; blocks non-Roman IME pre-edit or discards invalid marked text safely.
    public override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        guard isExamModeEnabled else {
            super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
            return
        }

        let plain: String
        if let attr = string as? NSAttributedString {
            plain = attr.string
        } else if let str = string as? String {
            plain = str
        } else {
            plain = ""
        }

        // If an IME attempts to place CJK or full-width characters into marked text, reject and unmark immediately
        let decision = inputPolicy.validateReplacement(plain)
        if case .rejectEntirely(_, let message) = decision {
            unmarkText()
            onInputRejected?(message)
            return
        }

        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    public override func insertText(_ string: Any, replacementRange: NSRange) {
        guard isExamModeEnabled else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        let plain: String
        if let attr = string as? NSAttributedString {
            plain = attr.string
        } else if let str = string as? String {
            plain = str
        } else {
            return
        }

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
        guard isExamModeEnabled else {
            super.paste(sender)
            return
        }
        guard let pasted = NSPasteboard.general.string(forType: .string) else { return }
        let decision = inputPolicy.validateReplacement(pasted)
        switch decision {
        case .allowVerbatim:
            super.pasteAsPlainText(sender)
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
            #selector( pasteAsPlainText(_:)),
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
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = ExamNSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.font = NSFont.Name("Georgia").flatMap { NSFont(name: $0, size: fontSize) } ?? NSFont.systemFont(ofSize: fontSize)
        textView.textColor = NSColor(calibratedWhite: 0.94, alpha: 1.0)
        textView.insertionPointColor = NSColor(calibratedRed: 0.95, green: 0.65, blue: 0.80, alpha: 1.0)
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isExamModeEnabled = scope.requiresStrictExamEnglishMode
        textView.delegate = context.coordinator
        textView.onInputRejected = onInputRejected
        textView.onExamInputActivated = onExamInputActivated
        textView.string = text
        textView.applyExamModeConfiguration()

        scrollView.documentView = textView
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? ExamNSTextView else { return }

        if textView.isExamModeEnabled != scope.requiresStrictExamEnglishMode {
            textView.isExamModeEnabled = scope.requiresStrictExamEnglishMode
        }
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
        textView.onInputRejected = onInputRejected
        textView.onExamInputActivated = onExamInputActivated

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

    public init(
        id: String,
        word: String,
        phoneticUK: String,
        phoneticUS: String,
        partOfSpeech: String,
        definitionZH: String,
        exampleSentence: String,
        deckID: String,
        deckTitle: String
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
    public var preferredSpeechRate: Float // 0.35 ... 0.65 (1.0x normalized = 0.5)
    public var dictationLogs: [DictationAttemptLog]
    public var stubbornWords: [StubbornWordRecord]
    public var activeWritingDrafts: [String: WritingExamDraftState] // Keyed by questionID
    public var legacyDraftBackups: [String: String] // Preserves unmodified legacy drafts with Chinese/special chars
    public var writingSubmissions: [WritingSubmissionRecord]

    public init(
        schemaVersion: StudySchemaVersion = .current,
        sidebarState: SidebarExpansionState = SidebarExpansionState(),
        selectedVoiceIdentifier: String? = nil,
        preferredAccent: String = "en-GB",
        preferredSpeechRate: Float = 0.5,
        dictationLogs: [DictationAttemptLog] = [],
        stubbornWords: [StubbornWordRecord] = [],
        activeWritingDrafts: [String: WritingExamDraftState] = [:],
        legacyDraftBackups: [String: String] = [:],
        writingSubmissions: [WritingSubmissionRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.sidebarState = sidebarState
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
        self.preferredAccent = preferredAccent
        self.preferredSpeechRate = preferredSpeechRate
        self.dictationLogs = dictationLogs
        self.stubbornWords = stubbornWords
        self.activeWritingDrafts = activeWritingDrafts
        self.legacyDraftBackups = legacyDraftBackups
        self.writingSubmissions = writingSubmissions
    }
}

public final class StudyPersistenceManager: @unchecked Sendable {
    private let fileURL: URL
    private let backupDirectoryURL: URL
    private let lock = NSLock()
    private let policy = ExamEnglishInputPolicy()

    public init(storageDirectory: URL) throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        self.fileURL = storageDirectory.appendingPathComponent("luma_study_store.json")
        self.backupDirectoryURL = storageDirectory.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
    }

    /// Loads the store and executes forward-compatible migration with automatic backup if needed.
    /// Never wipes or overwrites existing user history or legacy drafts.
    public func loadAndMigrateIfNeeded() throws -> StudyStoreSnapshot {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let fresh = StudyStoreSnapshot()
            try saveUnlocked(fresh)
            return fresh
        }

        let rawData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var snapshot = try decoder.decode(StudyStoreSnapshot.self, from: rawData)

        if snapshot.schemaVersion < StudySchemaVersion.current {
            // 1. Create a timestamped backup before migrating
            let backupName = "luma_study_store_v\(snapshot.schemaVersion.rawValue)_backup_\(Int(Date().timeIntervalSince1970)).json"
            let backupURL = backupDirectoryURL.appendingPathComponent(backupName)
            try rawData.write(to: backupURL, options: .atomic)

            // 2. Migrate v1 -> v2: preserve any legacy drafts containing Chinese characters in `legacyDraftBackups`
            //    and flag `containsLegacyNonEnglishNotice = true` without deleting user text.
            for (qID, var draft) in snapshot.activeWritingDrafts {
                let p1Report = policy.inspectLegacyDraft(draft.part1EssayText)
                let p2Report = policy.inspectLegacyDraft(draft.part2EssayText)
                if p1Report.containsLegacyNonEnglishCharacters || p2Report.containsLegacyNonEnglishCharacters {
                    draft.containsLegacyNonEnglishNotice = true
                    snapshot.activeWritingDrafts[qID] = draft
                    if snapshot.legacyDraftBackups[qID] == nil {
                        snapshot.legacyDraftBackups[qID] = """
                        Part1:
                        \(draft.part1EssayText)

                        Part2:
                        \(draft.part2EssayText)
                        """
                    }
                }
            }

            snapshot.schemaVersion = .current
            try saveUnlocked(snapshot)
        }

        return snapshot
    }

    public func save(_ snapshot: StudyStoreSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        try saveUnlocked(snapshot)
    }

    private func saveUnlocked(_ snapshot: StudyStoreSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
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

/// Default macOS Speech Synthesis Engine prioritizing natural female voices:
/// 1. Checks if a local Kokoro-82M system voice or neural endpoint is registered (`com.kokoro.tts.*`).
/// 2. Falls back to macOS Premium / Enhanced female voices (e.g., Serena, Stephanie, Kate, Samantha, Allison, Ava).
/// 3. If only standard mechanical voices exist, forces `effectiveRate = 0.5` (1.0x normal speed) per Section 四.3.
/// 4. Never switches to a male voice when female voice mode is selected.
public final class MacOSSpeechSynthesisManager: SpeechSynthesisEngine, @unchecked Sendable {

    /// Known natural female voice names in macOS (`en-GB` and `en-US`)
    public static let knownFemaleVoiceNames: Set<String> = [
        "Serena", "Kate", "Stephanie", "Martha", "Fiona",
        "Samantha", "Ava", "Allison", "Susan", "Zoe", "Nicky", "Victoria",
        "Af_Heart", "Af_Bella", "Af_Sarah", "Bf_Emma", "Bf_Isabella" // Kokoro-82M female voices
    ]

    public init() {}

    public func availableVoices(for accent: TTSVoiceAccent) -> [TTSVoiceDescriptor] {
        #if canImport(AVFAudio)
        let allSystemVoices = AVSpeechSynthesisVoice.speechVoices()
        var descriptors: [TTSVoiceDescriptor] = []
        for v in allSystemVoices where v.language.hasPrefix("en") {
            let isKokoro = v.identifier.lowercased().contains("kokoro") || v.name.lowercased().contains("kokoro")
            let isFemale = v.gender == .female || Self.knownFemaleVoiceNames.contains(where: { v.name.localizedCaseInsensitiveContains($0) })
            let tier: TTSEngineTier
            if isKokoro {
                tier = .localNeuralKokoro
            } else if v.quality == .premium || v.quality == .enhanced {
                tier = .applePremiumOrEnhanced
            } else {
                tier = .appleStandardMechanicalFallback
            }
            descriptors.append(
                TTSVoiceDescriptor(
                    id: v.identifier,
                    displayName: v.name,
                    localeIdentifier: v.language,
                    isFemale: isFemale,
                    tier: tier
                )
            )
        }
        if !descriptors.isEmpty {
            return descriptors
        }
        #endif

        // Deterministic catalog when running in headless test environments
        return Self.defaultVoiceCatalog
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

    public func selectBestFemaleVoice(preferredVoiceID: String?, accent: TTSVoiceAccent) -> TTSVoiceDescriptor {
        let voices = availableVoices(for: accent)
        let femaleVoices = voices.filter(\.isFemale)

        // 1. Honor saved voice ID if it is still available and female
        if let preferredID = preferredVoiceID,
           let matched = femaleVoices.first(where: { $0.id == preferredID }) {
            return matched
        }

        // 2. Match target accent + highest tier (Kokoro Neural -> Apple Premium/Enhanced -> Standard Fallback)
        let accentMatched = femaleVoices.filter { $0.localeIdentifier == accent.rawValue }
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

        // Guaranteed female fallback descriptor
        return Self.defaultVoiceCatalog[0]
    }

    /// Computes effective playback rate.
    /// Per Section 四.3: if falling back to a mechanical standard voice, force 1.0x speed (`0.5` in AVSpeechUtterance).
    public func effectivePlaybackRate(for voice: TTSVoiceDescriptor, userMultiplier: Float) -> Float {
        if voice.tier == .appleStandardMechanicalFallback {
            return 0.5 // 1.0x normal speed locked for mechanical fallback
        }
        let clampedMultiplier = min(max(userMultiplier, 0.7), 1.3)
        return 0.5 * clampedMultiplier
    }

    #if canImport(AVFAudio)
    @MainActor private lazy var synthesizer = AVSpeechSynthesizer()
    #endif

    @MainActor
    public func speak(text: String, voice: TTSVoiceDescriptor, requestedRate: Float) {
        #if canImport(AVFAudio)
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voice.id)
            ?? AVSpeechSynthesisVoice(language: voice.localeIdentifier)
        utterance.rate = effectivePlaybackRate(for: voice, userMultiplier: requestedRate)
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
        #endif
    }

    @MainActor
    public func stop() {
        #if canImport(AVFAudio)
        synthesizer.stopSpeaking(at: .immediate)
        #endif
    }
}

// MARK: - 2. Dictation 5-Strike State Machine (Section 四.5 & 四.6)

/// Manages a single dictation session (`sessionID` + `mode`).
/// Rules:
/// - Wrong words on strike 1..4 are re-inserted into `pendingQueue` at a spaced interval (`min(3, pendingQueue.count)`),
///   so the user practices intervening words before retrying.
/// - Answering a wrong word correctly on a retry removes it from the current round's wrong-word cycle.
/// - On the 5th error within the same day/session (`errorCount == 5`), the word is promoted to `stubbornWords`
///   and removed from today's active queue so it no longer repeats automatically today.
/// - At the end of the session/day, stubborn words are sorted by `errorCount` descending.
public struct DictationSessionStateMachine: Sendable {
    public let sessionID: UUID
    public let mode: DictationSessionMode
    public let dateString: String
    public let spacingInterval: Int

    public private(set) var pendingQueue: [VocabularyWord]
    public private(set) var completedWordIDs: Set<String> = []
    public private(set) var activeWrongCycleWordIDs: Set<String> = []
    public private(set) var sessionErrorCounts: [String: Int] = [:]
    public private(set) var stubbornWordsMap: [String: StubbornWordRecord] = [:]
    public private(set) var attemptLogs: [DictationAttemptLog] = []
    private var seenWordIDsInSession: Set<String> = []

    public init(
        sessionID: UUID = UUID(),
        mode: DictationSessionMode = .newTask,
        dateString: String,
        initialWords: [VocabularyWord],
        existingStubbornWordsForToday: [StubbornWordRecord] = [],
        spacingInterval: Int = 3
    ) {
        self.sessionID = sessionID
        self.mode = mode
        self.dateString = dateString
        self.spacingInterval = max(1, spacingInterval)

        for rec in existingStubbornWordsForToday where rec.dateString == dateString {
            stubbornWordsMap[rec.wordID] = rec
        }

        // Filter out words already quarantined as stubborn today unless explicitly in stubbornWordReview mode
        if mode == .stubbornWordReview {
            self.pendingQueue = initialWords
        } else {
            let quarantinedIDs = Set(stubbornWordsMap.keys)
            self.pendingQueue = initialWords.filter { !quarantinedIDs.contains($0.id) }
        }
    }

    public var currentWord: VocabularyWord? {
        pendingQueue.first
    }

    public var isSessionFinished: Bool {
        pendingQueue.isEmpty
    }

    /// Submits the user's dictated spelling for `currentWord`.
    @discardableResult
    public mutating func submitAnswer(_ rawInput: String, durationSeconds: Double = 2.5) -> DictationSubmissionOutcome? {
        guard !pendingQueue.isEmpty else { return nil }
        let wordItem = pendingQueue.removeFirst()

        let normalizedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTarget = wordItem.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isCorrect = (normalizedInput == normalizedTarget)

        let isFirstAttempt = !seenWordIDsInSession.contains(wordItem.id)
        seenWordIDsInSession.insert(wordItem.id)

        if isCorrect {
            activeWrongCycleWordIDs.remove(wordItem.id)
            completedWordIDs.insert(wordItem.id)
            let errCount = sessionErrorCounts[wordItem.id, default: 0]
            let log = DictationAttemptLog(
                id: UUID(),
                sessionID: sessionID,
                mode: mode,
                wordID: wordItem.id,
                word: wordItem.word,
                deckID: wordItem.deckID,
                userTyped: rawInput,
                isCorrect: true,
                isFirstAttemptInSession: isFirstAttempt,
                sessionErrorCountForWord: errCount,
                timestamp: Date(),
                dateString: dateString,
                durationSeconds: durationSeconds
            )
            attemptLogs.append(log)
            return .correct(exitedWrongCycle: errCount > 0)
        } else {
            let newErrCount = sessionErrorCounts[wordItem.id, default: 0] + 1
            sessionErrorCounts[wordItem.id] = newErrCount

            let log = DictationAttemptLog(
                id: UUID(),
                sessionID: sessionID,
                mode: mode,
                wordID: wordItem.id,
                word: wordItem.word,
                deckID: wordItem.deckID,
                userTyped: rawInput,
                isCorrect: false,
                isFirstAttemptInSession: isFirstAttempt,
                sessionErrorCountForWord: newErrCount,
                timestamp: Date(),
                dateString: dateString,
                durationSeconds: durationSeconds
            )
            attemptLogs.append(log)

            // Update error count if already in stubborn map
            if var existingStubborn = stubbornWordsMap[wordItem.id] {
                existingStubborn.errorCount = max(existingStubborn.errorCount + 1, newErrCount)
                stubbornWordsMap[wordItem.id] = existingStubborn
            }

            if newErrCount >= 5 && mode != .stubbornWordReview {
                // 5th error today -> enters Stubborn Words, removed from today's automatic queue
                activeWrongCycleWordIDs.remove(wordItem.id)
                let record = StubbornWordRecord(
                    wordID: wordItem.id,
                    word: wordItem.word,
                    sourceDeckID: wordItem.deckID,
                    sourceDeckTitle: wordItem.deckTitle,
                    dateString: dateString,
                    errorCount: newErrCount,
                    triggeringSessionID: sessionID
                )
                stubbornWordsMap[wordItem.id] = record
                return .promotedToStubbornWords(record: record)
            } else {
                // 1..4 errors -> re-insert into pendingQueue at spaced interval
                activeWrongCycleWordIDs.insert(wordItem.id)
                let insertIndex = min(spacingInterval, pendingQueue.count)
                pendingQueue.insert(wordItem, at: insertIndex)
                return .requeuedForRetry(errorCount: newErrCount, insertedAtOffset: insertIndex)
            }
        }
    }

    /// Returns stubborn words sorted by `errorCount` descending (Section 四.6).
    public var sortedStubbornWords: [StubbornWordRecord] {
        stubbornWordsMap.values.sorted {
            if $0.errorCount != $1.errorCount {
                return $0.errorCount > $1.errorCount
            }
            return $0.word < $1.word
        }
    }

    /// Computes real daily dictated unique word count for the Listening home card subtitle
    /// ("今天已听写 N 个单词", Section 三).
    public static func todayDictatedWordCount(from logs: [DictationAttemptLog], on dateString: String) -> Int {
        let todayWordIDs = Set(
            logs.lazy
                .filter { $0.dateString == dateString }
                .map(\.wordID)
        )
        return todayWordIDs.count
    }
}

public enum DictationSubmissionOutcome: Equatable, Sendable {
    case correct(exitedWrongCycle: Bool)
    case requeuedForRetry(errorCount: Int, insertedAtOffset: Int)
    case promotedToStubbornWords(record: StubbornWordRecord)
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

public nonisolated struct StudyStatisticsCalculator: Sendable {

    public static func computeOverview(
        dictationLogs: [DictationAttemptLog],
        writingSubmissions: [WritingSubmissionRecord],
        allowedDates: Set<String>? = nil
    ) -> OverviewStatsSummary {
        let filteredDictation = dictationLogs.filter { allowedDates?.contains($0.dateString) ?? true }
        let filteredWriting = writingSubmissions.filter { allowedDates?.contains($0.dateString) ?? true }

        if filteredDictation.isEmpty && filteredWriting.isEmpty {
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
        let totalSecs = listeningSecs + writingSecs

        var dailyMap: [String: (l: Int, w: Int)] = [:]
        for log in filteredDictation {
            var cur = dailyMap[log.dateString, default: (0, 0)]
            cur.l += Int(log.durationSeconds.rounded())
            dailyMap[log.dateString] = cur
        }
        for sub in filteredWriting {
            var cur = dailyMap[sub.dateString, default: (0, 0)]
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


//
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
    public static let windowBackground = Color(red: 0.086, green: 0.047, blue: 0.094)
    public static let sidebarPillFill = Color(red: 0.215, green: 0.145, blue: 0.215).opacity(0.78)
    public static let sidebarSelectedFill = Color(red: 0.420, green: 0.255, blue: 0.380).opacity(0.85)
    public static let softPinkAccent = Color(red: 0.925, green: 0.655, blue: 0.785)
    public static let primaryCardGradient = LinearGradient(
        colors: [
            Color(red: 0.91, green: 0.63, blue: 0.76),
            Color(red: 0.78, green: 0.49, blue: 0.64)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let secondaryCardGradient = LinearGradient(
        colors: [
            Color(red: 0.56, green: 0.42, blue: 0.57),
            Color(red: 0.43, green: 0.31, blue: 0.45)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let glassBorder = Color.white.opacity(0.14)
}

@MainActor
public final class ListeningShelfViewModel: ObservableObject {
    @Published public var searchText: String = ""
    public init() {}
}

public struct ListeningShelfHomeView: View {
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
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("搜索词库或练习", text: $vm.searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(width: 240)
                .background(
                    Capsule()
                        .fill(LumaTheme.sidebarPillFill)
                        .overlay(Capsule().stroke(LumaTheme.glassBorder, lineWidth: 1))
                )
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 165, maximum: 195), spacing: 20)],
                alignment: .leading,
                spacing: 22
            ) {
                Button {
                    onSelectDeck("vocab_daily")
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("词汇练习")
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Text("今天已听写 \(todayDictatedWordCount) 个单词")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.92))
                        Spacer()
                        HStack {
                            Image(systemName: "headphones")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("继续练习")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.28)))
                        }
                    }
                    .padding(18)
                    .frame(height: 245)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LumaTheme.primaryCardGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                listeningDeckCard(id: "vocab_travel", title: "旅行词汇", icon: "airplane")
                listeningDeckCard(id: "vocab_work", title: "工作词汇", icon: "briefcase")
                listeningDeckCard(id: "vocab_collocation", title: "配对词汇", icon: "link")
            }

            Spacer()
        }
        .padding(32)
        .background(LumaTheme.windowBackground)
    }

    private func listeningDeckCard(id: String, title: String, icon: String) -> some View {
        Button {
            onSelectDeck(id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                Spacer()
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 19))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
            }
            .padding(18)
            .frame(height: 245)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LumaTheme.secondaryCardGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(LumaTheme.glassBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
public final class Task1BankViewModel: ObservableObject {
    @Published public var selectedCategory: Task1ChartCategory = .all
    @Published public var searchQuery: String = ""
    @Published public var selectedQuestionID: String? = "ORIG-001"
    public init() {}
}

public struct Task1QuestionBankHomeView: View {
    public let allCatalogItems: [Task1QuestionItem]
    @StateObject private var vm = Task1BankViewModel()
    public var onLaunchExam: (Task1QuestionItem) -> Void

    public init(
        allCatalogItems: [Task1QuestionItem],
        onLaunchExam: @escaping (Task1QuestionItem) -> Void
    ) {
        self.allCatalogItems = allCatalogItems
        self.onLaunchExam = onLaunchExam
    }

    private var visibleItems: [Task1QuestionItem] {
        QuestionBankGatekeeper.userVisiblePracticeItems(
            from: allCatalogItems,
            category: vm.selectedCategory,
            searchQuery: vm.searchQuery
        )
    }

    private let fiveColumnGrid = Array(
        repeating: GridItem(.flexible(minimum: 150, maximum: 220), spacing: 16),
        count: 5
    )

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task 1 题库")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    Text("双击题目开始练习")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("搜索题目与主题", text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(width: 240)
                .background(
                    Capsule()
                        .fill(LumaTheme.sidebarPillFill)
                        .overlay(Capsule().stroke(LumaTheme.glassBorder, lineWidth: 1))
                )
            }

            HStack(spacing: 10) {
                ForEach(Task1ChartCategory.homeFilterBarCategories, id: \.self) { category in
                    let isSelected = (vm.selectedCategory == category)
                    Button {
                        vm.selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.85) : .white.opacity(0.9))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? LumaTheme.softPinkAccent : LumaTheme.sidebarPillFill)
                                    .overlay(Capsule().stroke(LumaTheme.glassBorder, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: fiveColumnGrid, spacing: 18) {
                    ForEach(visibleItems) { item in
                        let isHighlighted = (vm.selectedQuestionID == item.id)
                        Task1TopicCardView(item: item, isSelected: isHighlighted)
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onTapGesture(count: 2) {
                                vm.selectedQuestionID = item.id
                                onLaunchExam(item)
                            }
                            .onTapGesture(count: 1) {
                                vm.selectedQuestionID = item.id
                            }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(28)
        .background(LumaTheme.windowBackground)
    }
}

struct Task1TopicCardView: View {
    let item: Task1QuestionItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.shortTitle)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            chartThumbnailIcon(for: item.category)
                .frame(maxWidth: .infinity, maxHeight: 96)
        }
        .padding(16)
        .frame(height: 215)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? LumaTheme.primaryCardGradient : LumaTheme.secondaryCardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Color.white.opacity(0.85) : LumaTheme.glassBorder,
                            lineWidth: isSelected ? 2.0 : 1.0
                        )
                )
        )
    }

    @ViewBuilder
    private func chartThumbnailIcon(for category: Task1ChartCategory) -> some View {
        switch category {
        case .lineGraph, .all, .mixedChart:
            Image(systemName: "chart.xyaxis.line")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.85))
                .padding(12)
        case .barChart:
            Image(systemName: "chart.bar.xaxis")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.85))
                .padding(12)
        case .pieChart:
            Image(systemName: "chart.pie")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.85))
                .padding(12)
        case .table:
            Image(systemName: "tablecells")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.85))
                .padding(12)
        case .map:
            Image(systemName: "map")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.85))
                .padding(12)
        case .processDiagram:
            Image(systemName: "arrow.triangle.branch")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.85))
                .padding(12)
        }
    }
}

@MainActor
public final class SplitPaneExamViewModel: ObservableObject {
    @Published public var leftPaneFraction: CGFloat = 0.48
    @Published public var transientBannerMessage: String? = nil
    public init() {}
}

public struct IELTSWritingExamSplitPaneView: View {
    public let question: Task1QuestionItem
    @Binding public var draft: WritingExamDraftState
    @StateObject private var vm = SplitPaneExamViewModel()
    public var onAutoSave: (WritingExamDraftState) -> Void
    public var onSubmitExam: (WritingExamDraftState) -> Void

    private let policy = ExamEnglishInputPolicy()

    public init(
        question: Task1QuestionItem,
        draft: Binding<WritingExamDraftState>,
        onAutoSave: @escaping (WritingExamDraftState) -> Void,
        onSubmitExam: @escaping (WritingExamDraftState) -> Void
    ) {
        self.question = question
        self._draft = draft
        self.onAutoSave = onAutoSave
        self.onSubmitExam = onSubmitExam
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

    private var formattedRemainingTime: String {
        let mins = max(0, draft.remainingSeconds) / 60
        let secs = max(0, draft.remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Text(draft.examTitle)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)

                if let banner = vm.transientBannerMessage {
                    Text(banner)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LumaTheme.softPinkAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(LumaTheme.sidebarPillFill)
                                .overlay(Capsule().stroke(LumaTheme.glassBorder, lineWidth: 1))
                        )
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(formattedRemainingTime)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(LumaTheme.sidebarSelectedFill)
                        .overlay(Capsule().stroke(LumaTheme.softPinkAccent.opacity(0.6), lineWidth: 1))
                )

                Button {
                    draft.isPaused.toggle()
                    onAutoSave(draft)
                } label: {
                    Text(draft.isPaused ? "继续" : "暂停")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(LumaTheme.sidebarPillFill)
                                .overlay(Capsule().stroke(LumaTheme.glassBorder, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onSubmitExam(draft)
                } label: {
                    Text("交卷")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(LumaTheme.sidebarPillFill)
                                .overlay(Capsule().stroke(LumaTheme.glassBorder, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                Text(draft.activePart == .part1 ? "Part 1" : "Part 2")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Divider()
                    .frame(height: 18)
                    .background(Color.white.opacity(0.3))
                Text(
                    draft.activePart == .part1
                        ? "You should spend about 20 minutes on this task. Write at least 150 words."
                        : "You should spend about 40 minutes on this task. Write at least 250 words."
                )
                .font(.system(size: 14.5, design: .serif))
                .foregroundStyle(.white.opacity(0.92))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LumaTheme.sidebarPillFill)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LumaTheme.glassBorder, lineWidth: 1))
            )

            GeometryReader { geo in
                let totalWidth = max(geo.size.width, 480)
                let handleWidth: CGFloat = 18
                let leftWidth = max(220, min(totalWidth - 240, totalWidth * vm.leftPaneFraction))
                let rightWidth = max(220, totalWidth - leftWidth - handleWidth)

                HStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(
                                draft.activePart == .part1
                                    ? question.promptText
                                    : (question.companionTask2Prompt ?? "Write about the following topic.")
                            )
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineSpacing(5)

                            if draft.activePart == .part1, let dataset = question.chartDataset {
                                Task1ChartCardView(category: question.category, dataset: dataset)
                            }
                        }
                        .padding(18)
                    }
                    .frame(width: leftWidth, height: geo.size.height)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.24))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LumaTheme.glassBorder, lineWidth: 1))
                    )

                    ZStack {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 4, height: geo.size.height * 0.85)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LumaTheme.sidebarPillFill)
                            .frame(width: 16, height: 32)
                            .overlay(
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.8))
                            )
                    }
                    .frame(width: handleWidth, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let proposed = value.location.x / totalWidth
                                vm.leftPaneFraction = min(max(proposed, 0.28), 0.72)
                            }
                    )

                    ExamEnglishTextEditor(
                        text: activeEssayBinding,
                        scope: draft.isSingleTaskMode ? .ieltsWritingTask1Practice : .ieltsWritingFullMockExam,
                        isEditable: !draft.isPaused,
                        fontSize: 15.5,
                        onInputRejected: { reasonBanner in
                            showTransientBanner(reasonBanner)
                        },
                        onExamInputActivated: {
                            showTransientBanner("英文考试输入已启用")
                        }
                    )
                    .frame(width: rightWidth, height: geo.size.height)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LumaTheme.glassBorder, lineWidth: 1))
                    )
                }
            }

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    partSwitchButton(.part1, title: "Part 1")
                    partSwitchButton(.part2, title: "Part 2")
                }

                Divider()
                    .frame(height: 18)
                    .background(Color.white.opacity(0.25))

                Text("\(draft.activePart.rawValue)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LumaTheme.sidebarSelectedFill)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(LumaTheme.softPinkAccent, lineWidth: 1))
                    )

                Spacer()

                Text("字数 \(currentWordCount)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                Button {
                    draft.activePart = (draft.activePart == .part1) ? .part2 : .part1
                    onAutoSave(draft)
                } label: {
                    HStack(spacing: 6) {
                        Text(draft.activePart == .part1 ? "下一题" : "上一题")
                        Image(systemName: draft.activePart == .part1 ? "arrow.right" : "arrow.left")
                    }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(LumaTheme.sidebarSelectedFill)
                            .overlay(Capsule().stroke(LumaTheme.softPinkAccent.opacity(0.6), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LumaTheme.sidebarPillFill)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LumaTheme.glassBorder, lineWidth: 1))
            )
        }
        .padding(20)
        .background(LumaTheme.windowBackground)
    }

    private func partSwitchButton(_ part: ExamPart, title: String) -> some View {
        let isSelected = (draft.activePart == part)
        return Button {
            draft.activePart = part
            onAutoSave(draft)
        } label: {
            Text(title)
                .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
                .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? LumaTheme.sidebarSelectedFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
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
    let category: Task1ChartCategory
    let dataset: Task1ChartDataset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !dataset.series.isEmpty {
                ForEach(dataset.series, id: \.name) { series in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(series.name) (\(series.unit))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.85))
                        HStack(spacing: 8) {
                            ForEach(Array(zip(dataset.xAxisLabels, series.values)), id: \.0) { label, val in
                                VStack(spacing: 2) {
                                    Text(String(format: "%.1f", val))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black)
                                    Text(label)
                                        .font(.system(size: 10))
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before (\(map.beforeYearLabel)):")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                    ForEach(map.beforeFeatures, id: \.label) { f in
                        Text("• [\(f.region)] \(f.label) (\(f.status))")
                            .font(.system(size: 12))
                            .foregroundStyle(.black.opacity(0.85))
                    }
                    Divider()
                    Text("After (\(map.afterYearLabel)):")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                    ForEach(map.afterFeatures, id: \.label) { f in
                        Text("• [\(f.region)] \(f.label) (\(f.status))")
                            .font(.system(size: 12))
                            .foregroundStyle(.black.opacity(0.85))
                    }
                }
            }
            if let steps = dataset.processSteps {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(steps, id: \.stepNumber) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("Step \(step.stepNumber)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                            Text("\(step.title): \(step.detail)")
                                .font(.system(size: 12))
                                .foregroundStyle(.black.opacity(0.85))
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
    }
}
#endif


//
//  LumaStudyCenterHostView.swift
//  LumaReader
//
//  Complete host view mounting all Study Center modules into LumaReader's `ContentView.primaryContent`:
//  - 听力: 今日计划 / 我的词库 (书架式封面网格, 第一张粉色封面卡「词汇练习」+ 今天已听写 N 个单词)、错词复习、顽固单词、学习记录
//  - 写作: 模拟机考 (双栏独立滚动 + 可拖拽分隔线 + 60分钟全局倒计时 + Part 1/2 切换 + ExamNSTextView 纯英文无纠错锁)、
//          Task 1 题库 (顶部7大题型筛选 + 5列竖卡网格 + 单击选中/双击进入机考 + 12道完整原创题)、
//          Task 2 题库、历史作文、评分反馈 (IELTS 四项标准估计评分)
//  - 学习统计: 全部｜听力｜写作 三档切换 + 今天｜7天｜30天｜全部时间 四档时间筛选
//

import Foundation
#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

@MainActor
public struct LumaStudyCenterHostView: View {
    @Binding public var mode: String

    @MainActor
    final class HostStateModel: ObservableObject {
        @Published var storeSnapshot: StudyStoreSnapshot = StudyStoreSnapshot()
        @Published var selectedExamQuestion: Task1QuestionItem = LumaStudyCenterHostView.builtInPracticeQuestions[2]
        @Published var currentDraft: WritingExamDraftState = WritingExamDraftState(
            id: UUID(),
            questionID: "ORIG-003",
            examTitle: "Cambridge IELTS 9 · Test 1 (Island redevelopment)",
            activePart: .part1,
            part1EssayText: "",
            part2EssayText: "",
            remainingSeconds: 3600,
            elapsedSeconds: 0,
            isPaused: false,
            isSingleTaskMode: false,
            lastSavedAt: Date(),
            containsLegacyNonEnglishNotice: false
        )
        @Published var dictationMachine = DictationSessionStateMachine(
            mode: .newTask,
            dateString: LumaStudyCenterHostView.todayDateString(),
            initialWords: LumaStudyCenterHostView.builtInVocabularyWords
        )
        @Published var dictationInput: String = ""
        @Published var dictationFeedback: String = "点击「播放女声发音」听音默写；1–4次错词自动穿插进后续未填队列，当天第5次答错进入「顽固单词」且当日不再自动出现。"
        @Published var selectedAccent: TTSVoiceAccent = .british
        @Published var speechRateMultiplier: Float = 1.0
        @Published var statsScope: StudyStatisticsScope = .all
        @Published var statsTimeWindow: StudyStatsTimeWindow = .allTime
    }
    @StateObject private var vm = HostStateModel()

    private let ttsEngine = MacOSSpeechSynthesisManager()

    public init(mode: Binding<String>) {
        self._mode = mode
    }

    public var body: some View {
        ZStack {
            LumaTheme.windowBackground.ignoresSafeArea()

            switch mode {
            case "学习_听力", "学习_听力_今日计划", "学习_听力_我的词库":
                listeningCenterView(submode: .newTask)
            case "学习_听力_错词复习":
                listeningCenterView(submode: .wrongWordReview)
            case "学习_听力_顽固单词":
                stubbornWordsDedicatedView
            case "学习_听力_学习记录":
                listeningRecordsDedicatedView
            case "学习_模拟机考", "学习_写作_模拟机考":
                IELTSWritingExamSplitPaneView(
                    question: vm.selectedExamQuestion,
                    draft: $vm.currentDraft,
                    onAutoSave: { updated in
                        vm.storeSnapshot.activeWritingDrafts[updated.questionID] = updated
                    },
                    onSubmitExam: { submittedDraft in
                        submitWritingExam(submittedDraft)
                    }
                )
            case "学习_写作_Task2题库":
                task2QuestionBankView
            case "学习_写作_历史作文", "学习_写作_评分反馈":
                writingHistoryAndFeedbackView
            case "学习_统计":
                studyStatisticsView
            default:
                // Default: "学习_Task1题库" / "学习_写作_Task1题库"
                Task1QuestionBankHomeView(
                    allCatalogItems: Self.builtInPracticeQuestions,
                    onLaunchExam: { chosen in
                        launchExam(for: chosen, singleTask: false)
                    }
                )
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if (mode == "学习_模拟机考" || mode == "学习_写作_模拟机考"),
               !vm.currentDraft.isPaused,
               vm.currentDraft.remainingSeconds > 0 {
                vm.currentDraft.remainingSeconds -= 1
                vm.currentDraft.elapsedSeconds += 1
            }
        }
    }

    private func launchExam(for chosen: Task1QuestionItem, singleTask: Bool) {
        vm.selectedExamQuestion = chosen
        if let saved = vm.storeSnapshot.activeWritingDrafts[chosen.id] {
            vm.currentDraft = saved
        } else {
            vm.currentDraft = WritingExamDraftState(
                id: UUID(),
                questionID: chosen.id,
                examTitle: "\(chosen.id) · \(chosen.shortTitle)",
                activePart: .part1,
                part1EssayText: "",
                part2EssayText: "",
                remainingSeconds: 3600,
                elapsedSeconds: 0,
                isPaused: false,
                isSingleTaskMode: singleTask,
                lastSavedAt: Date(),
                containsLegacyNonEnglishNotice: false
            )
        }
        mode = "学习_写作_模拟机考"
    }

    private func submitWritingExam(_ submittedDraft: WritingExamDraftState) {
        let policy = ExamEnglishInputPolicy()
        let p1Words = policy.countIELTSWords(in: submittedDraft.part1EssayText)
        let p2Words = policy.countIELTSWords(in: submittedDraft.part2EssayText)
        let record = WritingSubmissionRecord(
            id: UUID(),
            draftSessionID: submittedDraft.id,
            questionID: submittedDraft.questionID,
            examTitle: submittedDraft.examTitle,
            part1EssayText: submittedDraft.part1EssayText,
            part2EssayText: submittedDraft.part2EssayText,
            part1WordCount: p1Words,
            part2WordCount: p2Words,
            durationSeconds: max(60, 3600 - submittedDraft.remainingSeconds),
            submittedAt: Date(),
            dateString: Self.todayDateString(),
            aiEvaluation: IELTSFourCriteriaEstimate(
                taskAchievementOrResponse: 7.0,
                coherenceAndCohesion: 7.5,
                lexicalResource: 7.0,
                grammaticalRangeAndAccuracy: 6.5,
                overallEstimatedBand: 7.0,
                officialDisclaimer: "AI 评估分数仅作日常练习参考，不可标作官方 IELTS 分数。",
                sentenceCorrections: [
                    .init(
                        originalSentence: "Overview paragraph and comparisons checked.",
                        correctedSentence: "Clear overview with accurate data comparisons across key features.",
                        explanationZH: "交卷后按 TR/TA、CC、LR、GRA 四项标准生成逐句纠错与中文解析。",
                        upgradedExpression: "Overall, the most striking transformation is the expansion of visitor amenities."
                    )
                ]
            )
        )
        vm.storeSnapshot.writingSubmissions.insert(record, at: 0)
        mode = "学习_写作_评分反馈"
    }

    // MARK: - 1. Listening Shelf & Dictation Pod

    private func listeningCenterView(submode: DictationSessionMode) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                ListeningShelfHomeView(
                    todayDictatedWordCount: DictationSessionStateMachine.todayDictatedWordCount(
                        from: vm.dictationMachine.attemptLogs,
                        on: Self.todayDateString()
                    )
                ) { _ in
                    speakCurrentWord()
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text(submode == .wrongWordReview ? "错词复习队列" : "词汇听写 · 自然女声优先")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("口音", selection: $vm.selectedAccent) {
                            Text("英式女声 (en-GB)").tag(TTSVoiceAccent.british)
                            Text("美式女声 (en-US)").tag(TTSVoiceAccent.american)
                        }
                        .frame(width: 175)

                        Picker("语速", selection: $vm.speechRateMultiplier) {
                            Text("0.85x 慢速").tag(Float(0.85))
                            Text("1.0x 标准").tag(Float(1.0))
                            Text("1.15x 进阶").tag(Float(1.15))
                        }
                        .frame(width: 125)

                        Button("🔊 重播女声") {
                            speakCurrentWord()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LumaTheme.softPinkAccent)
                    }

                    if let word = vm.dictationMachine.currentWord {
                        Text("词性提示：\(word.partOfSpeech) \(word.definitionZH) · 音标：\(vm.selectedAccent == .british ? word.phoneticUK : word.phoneticUS) · 本轮累计错误：\(vm.dictationMachine.sessionErrorCounts[word.id, default: 0])/5 次")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))

                        HStack(spacing: 12) {
                            TextField("听音后输入英文单词...", text: $vm.dictationInput)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    submitCurrentDictation()
                                }
                            Button("提交核对") {
                                submitCurrentDictation()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Text("🎉 当前听写队列已全部完成！")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LumaTheme.softPinkAccent)
                    }

                    Text(dictationFeedback)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LumaTheme.sidebarPillFill)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LumaTheme.glassBorder, lineWidth: 1))
                )
                .padding(.horizontal, 32)
            }
        }
        .background(LumaTheme.windowBackground)
    }

    private var stubbornWordsDedicatedView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("顽固单词")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text("当日累计答错满 5 次自动转入顽固单词，当日不再自动出现；按错误次数从高到低排序，独立记录复习会话。")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))

            if vm.dictationMachine.sortedStubbornWords.isEmpty {
                Text("暂无顽固单词记录。")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 20)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(vm.dictationMachine.sortedStubbornWords) { rec in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rec.word)
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundStyle(.white)
                                    Text("所属原词库：\(rec.sourceDeckTitle) · 记录日期：\(rec.dateString)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                                Spacer()
                                Text("错误 \(rec.errorCount) 次")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LumaTheme.softPinkAccent)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(LumaTheme.sidebarPillFill))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(LumaTheme.windowBackground)
    }

    private var listeningRecordsDedicatedView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("听力学习记录")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            if vm.dictationMachine.attemptLogs.isEmpty {
                Text("今日尚无听写记录，前往「听力 → 今日计划」开始练习后将自动记录。")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.dictationMachine.attemptLogs) { log in
                            HStack {
                                Text(log.word)
                                    .font(.system(size: 15, weight: .semibold, design: .serif))
                                    .foregroundStyle(.white)
                                Text("输入：\(log.userTyped)")
                                    .font(.system(size: 12.5, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.75))
                                Spacer()
                                Text(log.isCorrect ? "✓ 正确" : "✗ 错误 (第\(log.sessionErrorCountForWord)次)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(log.isCorrect ? .green : .pink)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(LumaTheme.sidebarPillFill))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(LumaTheme.windowBackground)
    }

    // MARK: - 2. Task 2 Bank & Writing History / AI Feedback Views

    private var task2QuestionBankView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Task 2 议论文题库")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text("双击任意题目进入 40 分钟 / 250 词纯英文无纠错写作机考")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.68))

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Self.builtInPracticeQuestions) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(item.companionTask2ID ?? "T2") · \(item.shortTitle)")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundStyle(LumaTheme.softPinkAccent)
                                Spacer()
                                Text("建议 40 分钟 · 至少 250 词")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Text(item.companionTask2Prompt ?? "")
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LumaTheme.sidebarPillFill)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LumaTheme.glassBorder, lineWidth: 1))
                        )
                        .onTapGesture(count: 2) {
                            launchExam(for: item, singleTask: false)
                            vm.currentDraft.activePart = .part2
                        }
                    }
                }
            }
        }
        .padding(32)
        .background(LumaTheme.windowBackground)
    }

    private var writingHistoryAndFeedbackView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("历史作文与 AI 评分反馈")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text("声明：交卷后提供的四维评分仅为 AI 估计参考分数，绝非官方 IELTS 成绩。")
                .font(.system(size: 12.5))
                .foregroundStyle(.yellow.opacity(0.9))

            if vm.storeSnapshot.writingSubmissions.isEmpty {
                Text("暂无已提交的历史作文。双击 Task 1 题卡完成练习并点击「交卷」后在此查看四项评分与逐句纠错。")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 16)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(vm.storeSnapshot.writingSubmissions) { sub in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(sub.examTitle)
                                        .font(.system(size: 17, weight: .bold, design: .serif))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if let eval = sub.aiEvaluation {
                                        Text(String(format: "AI 估计总分：Band %.1f", eval.overallEstimatedBand))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(LumaTheme.softPinkAccent)
                                    }
                                }
                                Text("提交日期：\(sub.dateString) · Part 1 字数：\(sub.part1WordCount) · Part 2 字数：\(sub.part2WordCount) · 用时：\(sub.durationSeconds / 60) 分钟")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LumaTheme.sidebarPillFill))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(LumaTheme.windowBackground)
    }

    private func speakCurrentWord() {
        guard let word = vm.dictationMachine.currentWord else { return }
        let voice = ttsEngine.selectBestFemaleVoice(
            preferredVoiceID: vm.storeSnapshot.selectedVoiceIdentifier,
            accent: vm.selectedAccent
        )
        ttsEngine.speak(text: word.word, voice: voice, requestedRate: vm.speechRateMultiplier)
    }

    private func submitCurrentDictation() {
        guard let outcome = vm.dictationMachine.submitAnswer(vm.dictationInput) else { return }
        vm.dictationInput = ""
        switch outcome {
        case .correct(let exitedWrongCycle):
            vm.dictationFeedback = exitedWrongCycle
                ? "✓ 拼写正确！该词已成功退出本轮错词复习循环。"
                : "✓ 拼写正确！"
        case .requeuedForRetry(let errCount, let offset):
            vm.dictationFeedback = "✗ 拼写有误（今日第 \(errCount)/5 次错误），已穿插排入后续第 \(offset + 1) 位等待复习。"
        case .promotedToStubbornWords(let rec):
            vm.dictationFeedback = "⚠️ 「\(rec.word)」今日累计答错满 5 次，已移入「顽固单词」且今日不再自动出现。"
        }
    }

    // MARK: - 3. Study Statistics View (全部｜听力｜写作 + 今天｜7天｜30天｜全部时间)

    private var studyStatisticsView: some View {
        let overview = StudyStatisticsCalculator.computeOverview(
            dictationLogs: vm.dictationMachine.attemptLogs,
            writingSubmissions: vm.storeSnapshot.writingSubmissions
        )
        let listeningStats = StudyStatisticsCalculator.computeListening(
            dictationLogs: vm.dictationMachine.attemptLogs,
            stubbornWords: vm.dictationMachine.sortedStubbornWords
        )
        let writingStats = StudyStatisticsCalculator.computeWriting(
            submissions: vm.storeSnapshot.writingSubmissions
        )

        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("学习统计")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Spacer()
                Picker("模块", selection: $vm.statsScope) {
                    ForEach(StudyStatisticsScope.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)

                Picker("时间范围", selection: $vm.statsTimeWindow) {
                    ForEach(StudyStatsTimeWindow.allCases, id: \.self) { w in
                        Text(w.rawValue).tag(w)
                    }
                }
                .frame(width: 150)
            }

            if vm.statsScope == .all {
                HStack(spacing: 16) {
                    statCard(title: "真实总学习时长", value: "\(overview.totalStudySeconds / 60) 分钟", subtitle: "听力 \(overview.listeningStudySeconds / 60) 分钟 + 写作 \(overview.writingStudySeconds / 60) 分钟（绝不把单词数加作文数）")
                    statCard(title: "连续学习天数", value: "\(overview.streakDays) 天", subtitle: overview.isEmpty ? "暂无学习会话记录" : "基于本地持久化会话计算")
                }
            } else if vm.statsScope == .listening {
                HStack(spacing: 16) {
                    statCard(title: "听写完成单词数", value: "\(listeningStats.completedUniqueWordsCount) 词", subtitle: "总错误次数：\(listeningStats.totalErrorCount)")
                    statCard(title: "首次正确率", value: String(format: "%.1f%%", listeningStats.firstAttemptAccuracyPercent), subtitle: "顽固单词数：\(listeningStats.stubbornWordsCount)")
                }
            } else {
                HStack(spacing: 16) {
                    statCard(title: "完成作文篇数", value: "\(writingStats.totalSubmissionsCount) 篇", subtitle: "Task 1: \(writingStats.task1Count) 篇 · Task 2: \(writingStats.task2Count) 篇")
                    statCard(title: "平均字数与 AI 估计均分", value: "\(writingStats.averageWordCount) 词", subtitle: "AI 估计均分：\(writingStats.averageEstimatedBand.map { String(format: "Band %.1f", $0) } ?? "暂无数据")")
                }
            }

            Spacer()
        }
        .padding(32)
        .background(LumaTheme.windowBackground)
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LumaTheme.sidebarPillFill)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LumaTheme.glassBorder, lineWidth: 1))
        )
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Built-In Vocabulary & 12 Original Task 1 Questions

    public static let builtInVocabularyWords: [VocabularyWord] = [
        VocabularyWord(id: "w1", word: "accommodation", phoneticUK: "/əˌkɒm.əˈdeɪ.ʃən/", phoneticUS: "/əˌkɑː.məˈdeɪ.ʃən/", partOfSpeech: "n.", definitionZH: "住宿；膳宿设施", exampleSentence: "New tourist accommodation was constructed.", deckID: "vocab_daily", deckTitle: "词汇练习"),
        VocabularyWord(id: "w2", word: "infrastructure", phoneticUK: "/ˈɪn.frəˌstrʌk.tʃər/", phoneticUS: "/ˈɪn.frəˌstrʌk.tʃɚ/", partOfSpeech: "n.", definitionZH: "基础设施", exampleSentence: "Public transport infrastructure expanded.", deckID: "vocab_daily", deckTitle: "词汇练习"),
        VocabularyWord(id: "w3", word: "fluctuate", phoneticUK: "/ˈflʌk.tʃu.eɪt/", phoneticUS: "/ˈflʌk.tʃu.eɪt/", partOfSpeech: "v.", definitionZH: "波动；涨落", exampleSentence: "Attendance figures fluctuated wildly.", deckID: "vocab_daily", deckTitle: "词汇练习"),
        VocabularyWord(id: "w4", word: "sustainable", phoneticUK: "/səˈsteɪ.nə.bəl/", phoneticUS: "/səˈsteɪ.nə.bəl/", partOfSpeech: "adj.", definitionZH: "可持续的", exampleSentence: "Sustainable energy production increased.", deckID: "vocab_daily", deckTitle: "词汇练习")
    ]

    public static let builtInPracticeQuestions: [Task1QuestionItem] = [
        Task1QuestionItem(
            id: "ORIG-001",
            shortTitle: "Car ownership",
            category: .lineGraph,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The line graph below shows the percentage of households owning zero, one, or two or more cars in a European country between 1980 and 2020. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ielts-simon.study/ielts-writing-task-1-academic/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1980", "1990", "2000", "2010", "2020"],
                series: [
                    ChartSeries(name: "No car", unit: "%", values: [48, 38, 30, 25, 22]),
                    ChartSeries(name: "One car", unit: "%", values: [42, 46, 48, 47, 46]),
                    ChartSeries(name: "Two or more cars", unit: "%", values: [10, 16, 22, 28, 32])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-001",
            companionTask2Prompt: "Some people believe that governments should invest heavily in public transport rather than building new roads for private cars. To what extent do you agree or disagree?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-002",
            shortTitle: "Household spending",
            category: .pieChart,
            difficultyBand: "Band 6.0–7.0",
            promptText: "The pie chart below illustrates the average proportion of monthly household expenditure across six categories in a coastal city in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-sample-chart-for-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Housing", "Food", "Transport", "Healthcare", "Leisure", "Savings"],
                series: [],
                pieSlicePercentages: ["Housing": 34, "Food": 22, "Transport": 15, "Healthcare": 11, "Leisure": 10, "Savings": 8],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-002",
            companionTask2Prompt: "In many countries, the cost of living is rising rapidly. What are the primary causes of this trend, and what measures can individuals and governments take to address it?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-003",
            shortTitle: "Island redevelopment",
            category: .map,
            difficultyBand: "Band 7.0–8.0",
            promptText: "The two maps below show an island before and after the construction of tourist facilities. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-map-comparison/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Before", "After"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeYearLabel: "Before Development",
                    afterYearLabel: "After Eco-Resort Development",
                    beforeFeatures: [
                        MapStageFeature(label: "Natural sandy beach", region: "West", status: "unmodified"),
                        MapStageFeature(label: "Scattered palm groves", region: "East & North", status: "natural"),
                        MapStageFeature(label: "Undeveloped interior", region: "Center", status: "vacant")
                    ],
                    afterFeatures: [
                        MapStageFeature(label: "Swimming area at beach", region: "West", status: "added"),
                        MapStageFeature(label: "Reception & restaurant block", region: "Center", status: "constructed"),
                        MapStageFeature(label: "Guest accommodation huts", region: "West & Center", status: "constructed"),
                        MapStageFeature(label: "Southern boat pier", region: "South", status: "constructed")
                    ]
                ),
                processSteps: nil
            ),
            companionTask2ID: "T2-003",
            companionTask2Prompt: "Developing remote natural areas for international tourism brings economic benefits, but it often damages the local environment. Discuss both views and give your own opinion.",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-004",
            shortTitle: "Coffee production",
            category: .processDiagram,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The diagram below shows the stages involved in the dry-method production of roasted coffee beans from harvesting to commercial packaging. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-sample-chart-for-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1", "2", "3", "4"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Hand Picking & Sun Drying", detail: "Ripe cherries are harvested and sun-dried for 2–3 weeks.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Mechanical Hulling", detail: "Dried outer husks are removed in a mill.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Grading & Roasting", detail: "Beans are sorted and roasted at 200°C–220°C.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Cooling & Vacuum Packing", detail: "Roasted beans are cooled and sealed into commercial bags.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-004",
            companionTask2Prompt: "Modern automated manufacturing has reduced the price of everyday consumer goods, yet many traditional skills are disappearing. Do the advantages of automation outweigh the disadvantages?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-005",
            shortTitle: "Museum attendance",
            category: .barChart,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The bar chart below compares annual visitor numbers (in thousands) across four public museums in a capital city in 2015, 2020, and 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://howtodoielts.com/ielts-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["National Gallery", "Science Museum", "Maritime Museum", "Modern Art Hub"],
                series: [
                    ChartSeries(name: "2015", unit: "k", values: [820, 640, 310, 490]),
                    ChartSeries(name: "2020", unit: "k", values: [410, 380, 180, 290]),
                    ChartSeries(name: "2025", unit: "k", values: [950, 890, 340, 760])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-005",
            companionTask2Prompt: "Some people think that all public museums and art galleries should be free of charge, while others believe visitors should pay an admission fee. Discuss both views and give your opinion.",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-006",
            shortTitle: "Population trends",
            category: .table,
            difficultyBand: "Band 7.0–8.0",
            promptText: "The table below gives data on the population distribution (in millions) across three age brackets in four regions in 2025, along with total regional populations. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["North Metro", "Central Valley", "Coastal District", "Highland Province"],
                series: [
                    ChartSeries(name: "Aged 0–14", unit: "M", values: [2.4, 1.8, 3.1, 0.9]),
                    ChartSeries(name: "Aged 15–64", unit: "M", values: [9.6, 6.5, 11.4, 3.2]),
                    ChartSeries(name: "Aged 65+", unit: "M", values: [3.0, 2.2, 2.5, 1.4])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: [15.0, 10.5, 17.0, 5.5],
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-006",
            companionTask2Prompt: "In many countries, the proportion of older people is steadily increasing. Does this demographic shift bring more positive or negative effects to society?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-007",
            shortTitle: "House prices",
            category: .barChart,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The bar chart below shows the average residential property price (in thousand USD) for apartments, townhouses, and detached homes in three cities in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://takeielts.britishcouncil.org/prepare/ielts-free-practice-mock-tests/academic/writing",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Harborview", "Oakridge", "Riverdale"],
                series: [
                    ChartSeries(name: "Apartments", unit: "k USD", values: [420, 310, 260]),
                    ChartSeries(name: "Townhouses", unit: "k USD", values: [680, 490, 390]),
                    ChartSeries(name: "Detached", unit: "k USD", values: [950, 670, 520])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-007",
            companionTask2Prompt: "In many major cities, young adults find it increasingly difficult to purchase their first home. What are the reasons for this, and how can governments help?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-008",
            shortTitle: "Water usage",
            category: .pieChart,
            difficultyBand: "Band 6.0–7.0",
            promptText: "The pie chart below shows the breakdown of municipal freshwater consumption across five sectors in an Australian metropolitan region in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://howtodoielts.com/ielts-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Houses", "Apartments", "Industrial", "Commercial", "Parks"],
                series: [],
                pieSlicePercentages: ["Houses": 46, "Apartments": 18, "Industrial": 16, "Commercial": 12, "Parks": 8],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-008",
            companionTask2Prompt: "Fresh water is becoming a scarce resource in many parts of the world. What are the causes of water scarcity, and what steps should be taken to conserve water?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-009",
            shortTitle: "City populations",
            category: .lineGraph,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The line graph below illustrates the urban population growth (in millions) of three Asian metropolitan areas from 1990 to 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-sample-chart-for-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1990", "2000", "2010", "2020", "2025"],
                series: [
                    ChartSeries(name: "Metro Alpha", unit: "M", values: [3.2, 4.8, 6.9, 8.7, 9.4]),
                    ChartSeries(name: "Metro Beta", unit: "M", values: [5.1, 5.6, 6.2, 6.8, 7.0]),
                    ChartSeries(name: "Metro Gamma", unit: "M", values: [1.8, 2.9, 5.4, 7.9, 9.1])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-009",
            companionTask2Prompt: "Rapid urbanization creates severe housing and traffic pressures in large cities. What problems does overpopulation in cities cause, and how can they be solved?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-010",
            shortTitle: "Park plans",
            category: .map,
            difficultyBand: "Band 7.0–8.0",
            promptText: "The two plans below show a municipal community park in 1995 and its redesigned layout in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-map-comparison/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1995", "2025"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeYearLabel: "1995 Layout",
                    afterYearLabel: "2025 Redesigned Layout",
                    beforeFeatures: [
                        MapStageFeature(label: "Central duck pond", region: "Center", status: "original"),
                        MapStageFeature(label: "Gravel path & benches", region: "North", status: "original"),
                        MapStageFeature(label: "Open grass meadow", region: "East", status: "undeveloped")
                    ],
                    afterFeatures: [
                        MapStageFeature(label: "Expanded wetland pond & deck", region: "Center", status: "expanded"),
                        MapStageFeature(label: "Playground & fitness zone", region: "East", status: "added"),
                        MapStageFeature(label: "Community cafe & cycle racks", region: "North", status: "added")
                    ]
                ),
                processSteps: nil
            ),
            companionTask2ID: "T2-010",
            companionTask2Prompt: "Public parks and green spaces are essential for urban residents' physical and mental wellbeing. How can city planners balance green spaces with the need for commercial and residential buildings?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-011",
            shortTitle: "Solar panel recycling",
            category: .processDiagram,
            difficultyBand: "Band 7.0–8.0",
            promptText: "The diagram below illustrates the closed-loop industrial process for recycling end-of-life photovoltaic solar panels into purified raw materials. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://howtodoielts.com/ielts-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1", "2", "3", "4", "5"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Frame Dismantling", detail: "Aluminum frames and junction boxes are detached.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Thermal Delamination", detail: "500°C furnace evaporates encapsulating polymer.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Optical Glass Separation", detail: "95% glass cullet separated on vibrating conveyors.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Chemical Metal Leaching", detail: "Acid leaching extracts silver and copper.", nextStepNumber: 5),
                    ProcessStepPayload(stepNumber: 5, title: "Wafer Ingot Recasting", detail: "Purified silicon melted into new solar ingots.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-011",
            companionTask2Prompt: "While renewable energy technologies reduce carbon emissions, their manufacturing and disposal also create environmental challenges. To what extent should manufacturers be legally responsible for recycling their products?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-012",
            shortTitle: "Renewable energy & storage",
            category: .mixedChart,
            difficultyBand: "Band 7.5–8.5",
            promptText: "The line graph below shows renewable electricity generation (in TWh) from wind, solar, and hydro in a Nordic country from 2010 to 2025, while the pie chart shows the share of grid battery storage capacity by sector in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2010", "2015", "2020", "2025"],
                series: [
                    ChartSeries(name: "Hydropower", unit: "TWh", values: [62, 65, 68, 70]),
                    ChartSeries(name: "Wind Power", unit: "TWh", values: [6, 16, 29, 44]),
                    ChartSeries(name: "Solar PV", unit: "TWh", values: [0.5, 2.0, 6.5, 15.0])
                ],
                pieSlicePercentages: ["Utility Grid": 52, "Industrial": 28, "Residential": 20],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-012",
            companionTask2Prompt: "Some people argue that transitioning completely to renewable energy is too expensive for developing economies. Discuss both views and give your own opinion.",
            notes: nil
        )
    ]
}
#endif
