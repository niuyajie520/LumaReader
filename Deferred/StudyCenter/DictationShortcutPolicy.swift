import Foundation

/// Modifier bits are deliberately independent of AppKit for deterministic policy tests.
enum DictationShortcutAction: Equatable {
    case replay, slowReplay, togglePause, toggleMeaning, toggleHint, previous, revealAnswer, help
}
enum DictationShortcutPolicy {
    static let command: UInt8 = 1, option: UInt8 = 2, shift: UInt8 = 4, control: UInt8 = 8
    static func action(keyCode: UInt16, characters: String, modifiers: UInt8) -> DictationShortcutAction? {
        let text = characters.lowercased()
        if modifiers == command {
            if text == "r" { return .replay }
            if text == "/" || keyCode == 44 { return .toggleHint }
            if text == "'" { return .revealAnswer }
        }
        if modifiers == (command | shift) {
            if text == "r" { return .slowReplay }
            if text == "?" || text == "/" || keyCode == 44 { return .help }
        }
        if modifiers == (command | option) {
            if text == "p" { return .togglePause }
            if text == "m" { return .toggleMeaning }
            if keyCode == 123 { return .previous }
        }
        return nil
    }
    static let helpText = "⌘R　重新播放\n⇧⌘R　慢放 0.75×\n⌥⌘P　暂停／继续\n空格　计时已暂停时继续（切回应用后直接按）\n⌥⌘M　显示／隐藏中文\n⌘/　首字母提示\n⌥⌘←　上一个已完成单词\nReturn　提交答案\n⇧⌘/　显示快捷键\n\n仅在当前听写窗口生效。⌘H 保留为 macOS 隐藏应用。"
}
