import SwiftUI
import AppKit
import PDFKit
import WebKit
import ImageIO
import UniformTypeIdentifiers

struct ReaderImage:Identifiable {
    let id = UUID()
    let image:NSImage
    let filename:String
    let originalData:Data

    @MainActor func attachment() throws -> AIImageAttachment {
        let longest = max(image.size.width,image.size.height)
        guard longest > 0 else { throw ReaderFailure.message("图片无法读取。") }
        let factor = min(1,1600/longest)
        let width = max(1,Int(image.size.width*factor)), height = max(1,Int(image.size.height*factor))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),
              let context = NSGraphicsContext(bitmapImageRep:bitmap) else { throw ReaderFailure.message("图片转换失败。") }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        let rect = NSRect(x:0,y:0,width:CGFloat(width),height:CGFloat(height))
        NSColor.white.setFill(); NSBezierPath(rect:rect).fill(); image.draw(in:rect)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using:.jpeg,properties:[.compressionFactor:0.8]), data.count <= 4*1024*1024 else { throw ReaderFailure.message("图片过大，请缩小后再发送。") }
        return AIImageAttachment(data:data,mimeType:"image/jpeg",filename:filename)
    }
    @MainActor func save() throws {
        let panel = NSSavePanel(); panel.nameFieldStringValue = filename
        if panel.runModal() == .OK, let url = panel.url { try originalData.write(to:url,options:.atomic) }
    }
}

struct ReaderImageViewer:View {
    let preview:ReaderImage
    let askAI:()->Void
    var onClose:(()->Void)? = nil
    var paper:Color = Color(nsColor:.windowBackgroundColor)
    @Environment(\.dismiss) private var dismiss
    @State private var recognition = ReaderImageText()
    @State private var recognitionAttempt = 0
    @State private var liveText = true
    @State private var showTranscript = false
    @State private var zoom:Double = 1
    @State private var failure:String?
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:12) {
                Text(preview.filename).lineLimit(1).font(.headline)
                Spacer()
                Button { zoom = max(1,zoom-0.5) } label: { Image(systemName:"minus.magnifyingglass").frame(width:40,height:40) }.help(L10n.text("缩小")).disabled(zoom <= 1)
                Button { zoom = min(4,zoom+0.5) } label: { Image(systemName:"plus.magnifyingglass").frame(width:40,height:40) }.help(L10n.text("放大")).disabled(zoom >= 4)
                Button { do { try preview.save() } catch { failure = error.localizedDescription } } label: { Label(L10n.text("保存图片"),systemImage:"square.and.arrow.down").frame(minHeight:40) }
                Button(action:askAI) { Label(L10n.text("问 AI"),systemImage:"sparkles").frame(minHeight:40) }
                Button(L10n.text("完成")) { if let onClose { onClose() } else { dismiss() } }.keyboardShortcut(.cancelAction).frame(minHeight:40)
            }.padding(14).buttonStyle(.borderless)
            Divider()
            GeometryReader { geometry in
                let width = max(1,preview.image.size.width), height = max(1,preview.image.size.height)
                let fit = min(1,min(max(1,geometry.size.width-48)/width,max(1,geometry.size.height-48)/height))
                ScrollView([.horizontal,.vertical]) {
                    NativeLiveTextImage(image:preview.image,analysis:recognition.analysis,enabled:liveText)
                        .frame(width:width*fit*zoom,height:height*fit*zoom)
                        .padding(24).frame(minWidth:geometry.size.width,minHeight:geometry.size.height)
                }
            }
            Divider()
            HStack(spacing:12) {
                if recognition.busy { ProgressView().controlSize(.small) }
                Text(recognition.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer(minLength:0)
                Menu {
                    Toggle(L10n.text("图片上选择文字"),isOn:$liveText)
                    Toggle(L10n.text("展开识别文字"),isOn:$showTranscript).disabled(recognition.transcript.isEmpty)
                    Button(L10n.text("复制全部文字")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(recognition.transcript,forType:.string)
                    }.disabled(recognition.transcript.isEmpty)
                    Button(L10n.text("重新识别")) { recognitionAttempt += 1 }.disabled(recognition.busy)
                } label: { Label(L10n.text("识别文字"),systemImage:"text.viewfinder").frame(minHeight:36) }
            }.padding(.horizontal,16).padding(.vertical,6)
            if showTranscript && !recognition.transcript.isEmpty {
                ScrollView { Text(recognition.transcript).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(16) }.frame(height:120)
            }
        }.frame(minWidth:600,minHeight:440).background(Color.clear)
        .task(id:preview.id.uuidString+String(recognitionAttempt)) { await recognition.recognize(preview) }
        .alert(L10n.text("图片操作失败"),isPresented:Binding(get:{ failure != nil },set:{ if !$0 { failure = nil } })) { Button(L10n.text("好")) { failure = nil } } message: { Text(failure ?? "") }
    }
}

extension ReaderController {
    func previewImage(_ source:String) {
        guard let root = imageRoot, let url = URL(string:source) else { return }
        let embedded = source.hasPrefix("data:image/")
        guard embedded || url.isFileURL else { store?.error = "只支持书内本地图片。"; return }
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        guard embedded || resolved.path.hasPrefix(root.resolvingSymlinksInPath().standardizedFileURL.path+"/") else { store?.error = "图片路径不在当前图书内。"; return }
        let embeddedType = source.split(separator:";",maxSplits:1).first.map(String.init) ?? ""
        let ext = ["data:image/jpeg":"jpg","data:image/png":"png","data:image/webp":"webp","data:image/gif":"gif","data:image/svg+xml":"svg"][embeddedType] ?? "img"
        let filename = embedded ? "书内图片."+ext:resolved.lastPathComponent
        let current = store?.selectedID
        Task { [weak self] in
            do {
                let data = try await Task.detached(priority:.utility) {
                    if embedded {
                        guard source.utf8.count <= 28*1024*1024, let comma = source.firstIndex(of:","), source[..<comma].hasSuffix(";base64"),
                              let bytes = Data(base64Encoded:String(source[source.index(after:comma)...])), !bytes.isEmpty, bytes.count <= 20*1024*1024 else { throw ReaderFailure.message("内嵌图片格式不支持或大于 20 MB。") }
                        return bytes
                    }
                    let values = try resolved.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey])
                    guard values.isRegularFile == true, let bytes = values.fileSize, bytes > 0, bytes <= 20*1024*1024 else { throw ReaderFailure.message("图片为空或大于 20 MB。") }
                    return try Data(contentsOf:resolved,options:.mappedIfSafe)
                }.value
                guard let self, self.store?.selectedID == current else { return }
                if let source = CGImageSourceCreateWithData(data as CFData,nil), let info = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                   let width = info[kCGImagePropertyPixelWidth] as? Double, let height = info[kCGImagePropertyPixelHeight] as? Double, width*height > 80_000_000 { throw ReaderFailure.message("图片尺寸过大。") }
                guard let image = NSImage(data:data) else { throw ReaderFailure.message("图片格式无法读取。") }
                self.imagePreview = ReaderImage(image:image,filename:filename,originalData:data)
            } catch { self?.store?.error = error.localizedDescription }
        }
    }
    func previewCurrentPDFPage() { if let page = currentPDFPage { previewPDFPage(page) } }
    func previewPDFPage(_ page:PDFPage) {
        let image = page.thumbnail(of:NSSize(width:2000,height:2000),for:.cropBox)
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data:tiff), let png = bitmap.representation(using:.png,properties:[:]) else { return }
        imagePreview = ReaderImage(image:image,filename:"图书页面.png",originalData:png)
    }
    func askAboutImage(_ image:ReaderImage) {
        do {
            let attachment = try image.attachment()
            captureAIContext(selection:"") { [weak self] context in
                self?.store?.ai.prepare(context,image:attachment)
                NotificationCenter.default.post(name:.lumaAskAI,object:nil)
            }
        } catch { store?.error = error.localizedDescription }
    }
    func previewIllustration(rect:NSRect) {
        guard let view = illustrationWebView else { return }
        let bounded = rect.intersection(view.bounds)
        guard !bounded.isEmpty, bounded.width > 1, bounded.height > 1 else { return }
        let configuration = WKSnapshotConfiguration(); configuration.rect = bounded
        view.takeSnapshot(with:configuration) { [weak self] image,error in
            guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data:tiff), let png = rep.representation(using:.png,properties:[:]) else { return }
            self?.imagePreview = ReaderImage(image:image,filename:"书内插图.png",originalData:png)
        }
    }
}
