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
        textView.font = NSFont(name: "Georgia", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        textView.textColor = NSColor(appearance.ink)
        textView.insertionPointColor = NSColor(appearance.accent)
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
    public var reviewSchedule: [String: WordReviewProgress]?
    public var writingRevisions: [WritingRevision]?
    public var speechService: SpeechServiceSettings?
    public var workspace: StudyWorkspaceState?
    public var dictationSession: DictationSessionStateMachine?
    public var dictationSessions: [String: DictationSessionStateMachine]?

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
        reviewSchedule: [String: WordReviewProgress]? = nil,
        writingRevisions: [WritingRevision]? = nil,
        speechService: SpeechServiceSettings? = nil,
        workspace: StudyWorkspaceState? = nil,
        dictationSession: DictationSessionStateMachine? = nil,
        dictationSessions: [String: DictationSessionStateMachine]? = nil
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
        self.reviewSchedule = reviewSchedule
        self.writingRevisions = writingRevisions
        self.speechService = speechService
        self.workspace = workspace
        self.dictationSession = dictationSession
        self.dictationSessions = dictationSessions
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

    @MainActor public var repeatCount = 1
    @MainActor public var repeatInterval = 0.5

    @MainActor
    public func speak(text: String, voice: TTSVoiceDescriptor, requestedRate: Float) {
        #if canImport(AVFAudio)
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        guard let installed = AVSpeechSynthesisVoice(identifier:voice.id) else { return }
        for index in 0..<min(5,max(1,repeatCount)) {
            let utterance = AVSpeechUtterance(string:text)
            utterance.voice = installed
            utterance.rate = effectivePlaybackRate(for:voice,userMultiplier:requestedRate)
            utterance.postUtteranceDelay = index < repeatCount-1 ? min(5,max(0,repeatInterval)) : 0
            synthesizer.speak(utterance)
        }
        #endif
    }

    @MainActor
    public func stop() {
        #if canImport(AVFAudio)
        synthesizer.stopSpeaking(at: .immediate)
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
    public static let windowBackground = Color(nsColor: .windowBackgroundColor)
    public static let sidebarPillFill = Color.primary.opacity(0.07)
    public static let sidebarSelectedFill = Color.accentColor.opacity(0.22)
    public static let softPinkAccent = Color.accentColor
    public static let primaryCardGradient = LinearGradient(
        colors: [
            Color.accentColor.opacity(0.28),
            Color.primary.opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let secondaryCardGradient = LinearGradient(
        colors: [
            Color.primary.opacity(0.08),
            Color.primary.opacity(0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let glassBorder = Color.primary.opacity(0.14)
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
                    .font(.system(size: 30, weight: .bold, design: .serif))
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
                            .foregroundStyle(appearance.ink)
                        Text("今天已听写 \(todayDictatedWordCount) 个单词")
                            .font(.system(size: 13))
                            .foregroundStyle(appearance.ink.opacity(0.82))
                        Spacer()
                        HStack {
                            Image(systemName: "headphones")
                                .font(.system(size: 20))
                                .foregroundStyle(appearance.accent)
                            Spacer()
                            Text("继续练习")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(appearance.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .studyGlassCapsule(cornerRadius: 12, selected: true)
                        }
                    }
                    .padding(18)
                    .frame(height: 245)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(appearance.primaryGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(appearance.line, lineWidth: 1)
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
        .background(appearance.paper)
    }

    private func listeningDeckCard(id: String, title: String, icon: String) -> some View {
        Button {
            onSelectDeck(id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 22, weight: .medium, design: .serif))
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
    @Environment(\.studyAppearance) private var appearance
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
                        .foregroundStyle(appearance.ink)
                    Text("双击题目开始练习 · 继承阅读器莫奈主题与玻璃胶囊视觉")
                        .font(.system(size: 13))
                        .foregroundStyle(appearance.ink.opacity(0.68))
                }
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(appearance.ink.opacity(0.6))
                    TextField("搜索题目与主题", text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(appearance.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(width: 240)
                .studyGlassCapsule(cornerRadius: 18)
            }

            HStack(spacing: 10) {
                ForEach(Task1ChartCategory.homeFilterBarCategories, id: \.self) { category in
                    let isSelected = (vm.selectedCategory == category)
                    Button {
                        vm.selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: isSelected, selected: isSelected, horizontalPadding: 14, height: 32))
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: fiveColumnGrid, spacing: 18) {
                    ForEach(visibleItems) { item in
                        let isHighlighted = (vm.selectedQuestionID == item.id)
                        Task1TopicCardView(item: item, isSelected: isHighlighted)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .background(appearance.paper)
    }
}

struct Task1TopicCardView: View {
    @Environment(\.studyAppearance) private var appearance
    let item: Task1QuestionItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.shortTitle)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundStyle(appearance.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            chartThumbnailIcon(for: item.category)
                .frame(maxWidth: .infinity, maxHeight: 96)
        }
        .padding(16)
        .frame(height: 215)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? appearance.primaryGradient : appearance.secondaryGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected ? appearance.accent : appearance.line,
                            lineWidth: isSelected ? 2.0 : 1.0
                        )
                )
                .shadow(color: Color.black.opacity(appearance.isDark ? 0.22 : 0.06), radius: 8, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private func chartThumbnailIcon(for category: Task1ChartCategory) -> some View {
        let iconName: String = {
            switch category {
            case .lineGraph, .all, .mixedChart: return "chart.xyaxis.line"
            case .barChart: return "chart.bar.xaxis"
            case .pieChart: return "chart.pie"
            case .table: return "tablecells"
            case .map: return "map"
            case .processDiagram: return "arrow.triangle.branch"
            }
        }()
        Image(systemName: iconName)
            .resizable()
            .scaledToFit()
            .foregroundStyle(isSelected ? appearance.accent : appearance.ink.opacity(0.75))
            .padding(12)
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

    private func handleBackTap() {
        draft.lastSavedAt = Date()
        onAutoSave(draft)
        // Provide exit confirmation during an active formal 60-minute mock exam to prevent accidental exits
        if !draft.isSingleTaskMode && !draft.isPaused && draft.remainingSeconds > 0 {
            vm.showExitExamConfirmation = true
        } else {
            onNavigateBack?()
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Top Glass Capsule Toolbar (with top-left < 返回 button matching Reader glass capsule style)
            HStack(spacing: 12) {
                if onNavigateBack != nil {
                    Button {
                        handleBackTap()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12.5, weight: .semibold))
                            Text("返回")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                    .help("自动保存未完成作文并返回学习中心（不会误触发交卷）")
                }

                Text(draft.examTitle)
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(appearance.ink)
                    .lineLimit(1)

                if let banner = vm.transientBannerMessage {
                    Text(banner)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(appearance.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .studyGlassCapsule(cornerRadius: 14, selected: true)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundStyle(draft.remainingSeconds < 300 ? Color.red : appearance.accent)
                    Text(formattedRemainingTime)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(draft.remainingSeconds < 300 ? Color.red : appearance.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .studyGlassCapsule(cornerRadius: 18, selected: true)

                if draft.isSingleTaskMode {
                    Button {
                        draft.isPaused.toggle()
                        draft.lastSavedAt = Date()
                        onAutoSave(draft)
                    } label: {
                        Text(draft.isPaused ? "继续计时" : "暂停练习")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: draft.isPaused, horizontalPadding: 14, height: 34))
                }

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
                Text(draft.activePart == .part1 ? "Task 1 (20 分钟 · ≥150 词)" : "Task 2 (40 分钟 · ≥250 词)")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(appearance.accent)
                Divider()
                    .frame(height: 16)
                    .background(appearance.line)
                Text(
                    draft.activePart == .part1
                        ? "You should spend about 20 minutes on this task. Write at least 150 words."
                        : "You should spend about 40 minutes on this task. Write at least 250 words."
                )
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(appearance.ink.opacity(0.86))
                Spacer()
                Text("纯英文无纠错机考模式 · 草稿实时自动保存")
                    .font(.system(size: 11.5))
                    .foregroundStyle(appearance.ink.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .studyGlassCapsule(cornerRadius: 14)

            HSplitView {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            StudyPromptView(text:draft.activePart == .part1 ? question.promptText : (question.companionTask2Prompt ?? "Write about the following topic."),highlights:Binding(get:{draft.promptHighlights?[draft.activePart.rawValue] ?? []},set:{ ranges in
                                    if draft.promptHighlights==nil{draft.promptHighlights=[:]}
                                    draft.promptHighlights?[draft.activePart.rawValue]=ranges
                                    onAutoSave(draft)
                                }))


                            if draft.activePart == .part1, let dataset = question.chartDataset {
                                Task1ChartCardView(category: question.category, dataset: dataset)
                            }
                        }
                        .padding(18)
                    }
                    .frame(minWidth:220,maxWidth:.infinity,maxHeight:.infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(appearance.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(appearance.line, lineWidth: 1))
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
                    .frame(minWidth:260,maxWidth:.infinity,maxHeight:.infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(appearance.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(appearance.line, lineWidth: 1))
                    )
            }


            // Bottom Glass Bar with Part 1/Part 2 switcher and bottom-right real-time word count
            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    partSwitchButton(.part1, title: "Task 1 (20m)")
                    partSwitchButton(.part2, title: "Task 2 (40m)")
                }

                Divider()
                    .frame(height: 18)
                    .background(appearance.line)

                Text("当前题号: \(draft.activePart.rawValue)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(appearance.ink.opacity(0.75))

                Spacer()

                HStack(spacing: 6) {
                    Text("实时字数")
                        .font(.system(size: 12.5))
                        .foregroundStyle(appearance.ink.opacity(0.72))
                    Text("\(currentWordCount) / \(minimumTargetWords) 词")
                        .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(currentWordCount >= minimumTargetWords ? Color.green : appearance.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .studyGlassCapsule(cornerRadius: 16, selected: currentWordCount >= minimumTargetWords)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .studyGlassCapsule(cornerRadius: 16)
        }
        .padding(20)
        .background(appearance.paper)
        .alert("确认暂时离开正式模考？", isPresented: $vm.showExitExamConfirmation) {
            Button("保存草稿并返回学习中心") {
                draft.lastSavedAt = Date()
                onAutoSave(draft)
                onNavigateBack?()
            }
            Button("继续作答", role: .cancel) {}
        } message: {
            Text("当前未完成的作文内容已自动保存，不会误触发交卷。按照正式考试规则，60 分钟倒计时将继续按真实时间运行，您可随时从学习中心返回继续作答。")
        }
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
    @State private var chartZoom = 1.0
    @State private var expanded=false
    var allowsExpansion:Bool = true
    let category: Task1ChartCategory
    let dataset: Task1ChartDataset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if allowsExpansion {Button("放大查看图表",systemImage:"arrow.up.left.and.arrow.down.right") {expanded=true}.foregroundStyle(.black)}
            if !dataset.series.isEmpty && category != .table {
                HStack {
                    Text("图表缩放")
                    Slider(value:$chartZoom,in:1...2.5).frame(width:140)
                    Button("重置") { chartZoom = 1 }
                }.foregroundStyle(.black)
                ScrollView([.horizontal,.vertical]) {
                    Chart {
                        ForEach(dataset.series,id:\.name) { series in
                            ForEach(Array(series.values.enumerated()),id:\.offset) { index,value in
                                if index < dataset.xAxisLabels.count {
                                    if category == .lineGraph {
                                        LineMark(x:.value("类别",dataset.xAxisLabels[index]),y:.value(series.unit,value)).foregroundStyle(by:.value("系列",series.name))
                                    } else if category == .pieChart {
                                        SectorMark(angle:.value("数值",value)).foregroundStyle(by:.value("类别",dataset.xAxisLabels[index]))
                                    } else {
                                        BarMark(x:.value("类别",dataset.xAxisLabels[index]),y:.value(series.unit,value)).foregroundStyle(by:.value("系列",series.name))
                                    }
                                }
                            }
                        }
                    }.frame(width:340*chartZoom,height:240*chartZoom).padding(12)
                }.frame(height:280)
            }
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
                StudyMapDiagram(title:map.beforeYearLabel,features:map.beforeFeatures)
                StudyMapDiagram(title:map.afterYearLabel,features:map.afterFeatures)
                DisclosureGroup("地图原始数据") {
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
                        }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
                            .background(Color.black.opacity(0.04),in:RoundedRectangle(cornerRadius:8))
                        if step.stepNumber != steps.last?.stepNumber {Image(systemName:"arrow.down").font(.caption).foregroundStyle(.black.opacity(0.5)).frame(maxWidth:.infinity)}
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
        .environment(\.colorScheme,.light)
        .sheet(isPresented:$expanded) {
            VStack {
                HStack {Text("题目图表").font(.title2);Spacer();Button("关闭") {expanded=false}.keyboardShortcut(.cancelAction)}
                ScrollView([.horizontal,.vertical]) {
                    Task1ChartCardView(allowsExpansion:false,category:category,dataset:dataset).frame(width:860)
                }
            }.padding(24).frame(minWidth:800,minHeight:600)
        }
    }
}
#endif
