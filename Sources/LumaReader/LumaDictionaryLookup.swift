import AppKit

/// 快速查词：调用 macOS 系统词典的「查询」浮窗（可启用《牛津英语词典》《牛津英汉汉英词典》等），
/// 不在应用里显示任何词典界面，只在需要时弹出释义。
@MainActor
enum LumaDictionaryLookup {
    static func show(_ text: String, in view: NSView, at point: NSPoint) {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        let attr = NSAttributedString(string: word, attributes: [.font: NSFont.systemFont(ofSize: 15)])
        view.showDefinition(for: attr, at: point)
    }

    /// 当前鼠标位置（转换到 view 坐标），用于从菜单 / 快捷键触发时决定浮窗位置。
    static func mousePoint(in view: NSView) -> NSPoint {
        guard let window = view.window else { return NSPoint(x: view.bounds.midX, y: view.bounds.midY) }
        let inWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let p = view.convert(inWindow, from: nil)
        return view.bounds.contains(p) ? p : NSPoint(x: view.bounds.midX, y: view.bounds.midY)
    }

    /// 如果焦点在可编辑文本（写作、笔记、AI 输入框等）里，查询选中文字或光标所在单词。
    /// 返回 false 表示焦点不在文本框里，由调用方改为查询阅读区选中的文字。
    @discardableResult
    static func lookUpInFocusedTextView() -> Bool {
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView, let storage = tv.textStorage else { return false }
        var range = tv.selectedRange()
        if range.length == 0 {
            range = tv.selectionRange(forProposedRange: range, granularity: .selectByWord)
        }
        guard range.length > 0, NSMaxRange(range) <= storage.length else { return true }
        tv.showDefinition(for: nil, range: range, options: nil, baselineOriginProvider: nil)
        return true
    }
}
