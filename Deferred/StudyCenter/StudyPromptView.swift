import SwiftUI
import AppKit

public struct StudyTextHighlight:Codable,Equatable,Sendable {
    public let start:Int
    public let length:Int
    public init(start:Int,length:Int){self.start=start;self.length=length}
}
nonisolated enum StudyHighlightRanges {
    static func adding(_ selection:NSRange,to ranges:[StudyTextHighlight],textLength:Int)->[StudyTextHighlight] {
        guard valid(selection,textLength) else{return ranges}
        let sorted=(ranges+[StudyTextHighlight(start:selection.location,length:selection.length)]).filter{valid(NSRange(location:$0.start,length:$0.length),textLength)}.sorted{$0.start<$1.start}
        var result:[StudyTextHighlight]=[]
        for item in sorted {
            if let last=result.last,item.start<=last.start+last.length {
                result[result.count-1]=StudyTextHighlight(start:last.start,length:max(last.start+last.length,item.start+item.length)-last.start)
            }else{result.append(item)}
        }
        return result
    }
    static func removing(_ selection:NSRange,from ranges:[StudyTextHighlight],textLength:Int)->[StudyTextHighlight] {
        guard valid(selection,textLength) else{return ranges}
        return ranges.flatMap {item->[StudyTextHighlight] in
            let end=item.start+item.length,cutEnd=selection.location+selection.length
            if end<=selection.location || item.start>=cutEnd{return[item]}
            var fragments:[StudyTextHighlight]=[]
            if item.start<selection.location{fragments.append(.init(start:item.start,length:selection.location-item.start))}
            if end>cutEnd{fragments.append(.init(start:cutEnd,length:end-cutEnd))}
            return fragments
        }
    }
    static func valid(_ range:NSRange,_ length:Int)->Bool {range.location != NSNotFound && range.location>=0 && range.length>0 && range.location<=length && range.length<=length-range.location}
}
struct StudyPromptView:NSViewRepresentable {
    @Environment(\.studyAppearance) private var appearance
    let text:String
    @Binding var highlights:[StudyTextHighlight]
    func makeNSView(context:Context)->NSScrollView {
        let scroll=NSScrollView()
        let view=PromptTextView(frame:NSRect(x:0,y:0,width:400,height:240))
        view.isEditable=false;view.isSelectable=true
        view.drawsBackground=false;scroll.drawsBackground=false
        view.isVerticallyResizable=true;view.isHorizontallyResizable=false
        view.autoresizingMask=[.width]
        view.textContainer?.widthTracksTextView=true
        view.textContainer?.containerSize=NSSize(width:400,height:CGFloat.greatestFiniteMagnitude)
        scroll.documentView=view;scroll.hasVerticalScroller=true
        return scroll
    }
    func sizeThatFits(_ proposal:ProposedViewSize,nsView:NSScrollView,context:Context)->CGSize? {
        let width=max(120,proposal.width ?? 400)
        let textWidth=max(80,width-24)
        let bounds=(text as NSString).boundingRect(with:NSSize(width:textWidth,height:CGFloat.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:NSFont.systemFont(ofSize:15)])
        return CGSize(width:width,height:min(320,max(90,ceil(bounds.height)+20)))
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) {
        guard let view=scroll.documentView as? PromptTextView else{return}
        if view.string != text {view.string=text}
        view.font = .systemFont(ofSize:15);view.textColor=NSColor(appearance.ink)
        view.highlights=highlights
        view.highlightColor=NSColor(appearance.accent).withAlphaComponent(0.3)
        view.onHighlightsChanged={highlights=$0}
        view.paintHighlights()
    }
    final class PromptTextView:NSTextView {
        var highlights:[StudyTextHighlight]=[]
        var onHighlightsChanged:([StudyTextHighlight])->Void={_ in}
        var highlightColor=NSColor.systemYellow.withAlphaComponent(0.4)
        override func menu(for event:NSEvent)->NSMenu? {
            let menu=super.menu(for:event) ?? NSMenu()
            for(title,action) in [("高亮所选文字",#selector(highlightSelection)),("取消所选高亮",#selector(clearHighlight))] {
                let item=NSMenuItem(title:title,action:action,keyEquivalent:"");item.target=self;menu.addItem(item)
            }
            return menu
        }
        func paintHighlights(){
            let length=(string as NSString).length
            textStorage?.removeAttribute(.backgroundColor,range:NSRange(location:0,length:length))
            for range in highlights where StudyHighlightRanges.valid(NSRange(location:range.start,length:range.length),length) {
                textStorage?.addAttribute(.backgroundColor,value:highlightColor,range:NSRange(location:range.start,length:range.length))
            }
        }
        @objc func highlightSelection(){
            highlights=StudyHighlightRanges.adding(selectedRange(),to:highlights,textLength:(string as NSString).length)
            paintHighlights();onHighlightsChanged(highlights)
        }
        @objc func clearHighlight(){
            highlights=StudyHighlightRanges.removing(selectedRange(),from:highlights,textLength:(string as NSString).length)
            paintHighlights();onHighlightsChanged(highlights)
        }
    }
}
