import SwiftUI
import AppKit
import VisionKit
import Vision
import Observation

@MainActor @Observable final class ReaderImageText {
    var analysis: ImageAnalysis?
    var transcript = ""
    var status = ""
    var busy = false
    func recognize(_ preview:ReaderImage) async {
        analysis = nil; transcript = ""; status = "正在识别文字…"; busy = true
        defer { busy = false }
        do {
            if ImageAnalyzer.isSupported {
                let configuration = ImageAnalyzer.Configuration([.text])
                let result = try await ImageAnalyzer().analyze(preview.image,orientation:.up,configuration:configuration)
                try Task.checkCancellation()
                analysis = result; transcript = result.transcript
            } else {
                // Intel/unsupported Live Text hardware still gets Apple's on-device Vision OCR.
                let bytes = preview.originalData
                transcript = try await Task.detached(priority:.utility) {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    request.automaticallyDetectsLanguage = true
                    try VNImageRequestHandler(data:bytes,options:[:]).perform([request])
                    try Task.checkCancellation()
                    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator:"\n")
                }.value
                try Task.checkCancellation()
            }
            status = transcript.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "未识别到文字":
                (analysis == nil ? "已识别，可展开或复制文字":"可直接在图片上选择文字")
        } catch is CancellationError { status = "" }
        catch { status = "文字识别失败，可重新尝试："+error.localizedDescription }
    }
}

struct NativeLiveTextImage: NSViewRepresentable {
    let image:NSImage
    let analysis:ImageAnalysis?
    let enabled:Bool
    func makeNSView(context:Context) -> LiveTextImageView {
        let view = LiveTextImageView(frame:.zero)
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.image = image
        return view
    }
    func sizeThatFits(_ proposal:ProposedViewSize,nsView:LiveTextImageView,context:Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width:width,height:height)
    }
    func updateNSView(_ view:LiveTextImageView,context:Context) {
        if view.image !== image { view.image = image }
        if view.textOverlay.analysis !== analysis { view.textOverlay.analysis = analysis }
        let interactions:ImageAnalysisOverlayView.InteractionTypes = enabled ? .textSelection:[]
        if view.textOverlay.preferredInteractionTypes != interactions { view.textOverlay.preferredInteractionTypes = interactions }
        view.textOverlay.isHidden = !enabled || analysis == nil
        view.textOverlay.setContentsRectNeedsUpdate()
    }
}
final class LiveTextImageView: NSImageView {
    let textOverlay = ImageAnalysisOverlayView(frame:.zero)
    override init(frame:NSRect) {
        super.init(frame:frame)
        textOverlay.frame = bounds
        textOverlay.autoresizingMask = [.width,.height]
        textOverlay.trackingImageView = self
        textOverlay.preferredInteractionTypes = .textSelection
        addSubview(textOverlay)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) is not supported") }
}
