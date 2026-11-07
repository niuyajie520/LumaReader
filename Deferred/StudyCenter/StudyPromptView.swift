import SwiftUI
import AppKit

struct StudyPromptView:NSViewRepresentable {
    let text:String
    func makeNSView(context:Context)->NSScrollView {
        let scroll = NSScrollView()
        let view = PromptTextView()
        view.isEditable = false; view.isSelectable = true
        view.drawsBackground = false; scroll.drawsBackground = false
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        scroll.documentView = view; scroll.hasVerticalScroller = true
        return scroll
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) {
        guard let view = scroll.documentView as? PromptTextView else { return }
        if view.string != text {
            view.string = text; view.font = .systemFont(ofSize:15)
            view.textColor = .labelColor
        }
    }
    final class PromptTextView:NSTextView {
        override func menu(for event:NSEvent)->NSMenu? {
            let menu = super.menu(for:event) ?? NSMenu()
            for (title,action) in [("高亮所选文字",#selector(highlightSelection)),("取消所选高亮",#selector(clearHighlight))] {
                let item = NSMenuItem(title:title,action:action,keyEquivalent:""); item.target = self; menu.addItem(item)
            }
            return menu
        }
        @objc private func highlightSelection() {
            guard selectedRange().length > 0 else { return }
            textStorage?.addAttribute(.backgroundColor,value:NSColor.systemYellow.withAlphaComponent(0.45),range:selectedRange())
        }
        @objc private func clearHighlight() {
            guard selectedRange().length > 0 else { return }
            textStorage?.removeAttribute(.backgroundColor,range:selectedRange())
        }
    }
}
