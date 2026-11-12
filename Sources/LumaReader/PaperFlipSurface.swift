import AppKit
import WebKit

/// Plays a short StPageFlip animation over two already laid-out reader snapshots.
/// The live WKWebView remains the source of truth for the current reading location.
@MainActor
final class PaperFlipSurface {
    private final class MessageRelay: NSObject, WKScriptMessageHandler {
        weak var owner: PaperFlipSurface?
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            MainActor.assumeIsolated {
                guard message.frameInfo.isMainFrame, let event = message.body as? String else { return }
                self.owner?.handle(event)
            }
        }
    }

    private let webView: WKWebView
    private var timeout: Task<Void, Never>?
    private var completion: ((Bool) -> Void)?

    init(in host: NSView) {
        let configuration = WKWebViewConfiguration()
        let relay = MessageRelay()
        configuration.userContentController.add(relay, name: "lumaPaperFlip")
        webView = WKWebView(frame: host.bounds, configuration: configuration)
        relay.owner = self
        webView.autoresizingMask = [.width, .height]
        webView.alphaValue = 0
        host.addSubview(webView, positioned: .above, relativeTo: nil)
    }

    func play(old: NSImage, new: NSImage, columns: Int, forward: Bool, duration: Double, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        let resources = Bundle.main.resourceURL
        guard let libraryURL = resources?.appendingPathComponent("StPageFlip.js"),
              let adapterURL = resources?.appendingPathComponent("PaperFlip.js"),
              let library = try? String(contentsOf: libraryURL, encoding: .utf8),
              let adapter = try? String(contentsOf: adapterURL, encoding: .utf8),
              let oldPages = Self.pages(from: old, columns: columns),
              let newPages = Self.pages(from: new, columns: columns) else {
            finish(false)
            return
        }

        let milliseconds = max(150, Int(duration * 1000))
        let arguments: [String: Any] = [
            "pages": forward ? oldPages + newPages : newPages + oldPages,
            "columns": columns, "width": webView.bounds.width, "height": webView.bounds.height,
            "forward": forward, "milliseconds": milliseconds,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: arguments),
              let json = String(data: data, encoding: .utf8) else {
            finish(false)
            return
        }

        let html = """
        <!doctype html><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:">
        <style>html,body,#book{width:100%;height:100%;margin:0;overflow:hidden}canvas{display:block}</style>
        <div id="book"></div>
        <script>\(library)</script>
        <script>\(adapter)\nplayPaperFlip(\(json));</script>
        """
        webView.loadHTMLString(html, baseURL: nil)
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(duration + 0.8)) } catch { return }
            guard let self else { return }
            self.finish(self.webView.alphaValue > 0)
        }
    }

    private func handle(_ event: String) {
        switch event {
        case "ready": webView.alphaValue = 1
        case "done": finish(true)
        case "failed": finish(false)
        default: break
        }
    }

    private func finish(_ succeeded: Bool) {
        timeout?.cancel()
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "lumaPaperFlip")
        webView.removeFromSuperview()
        let callback = completion
        completion = nil
        callback?(succeeded)
    }

    private static func pages(from image: NSImage, columns: Int) -> [String]? {
        guard let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pages: [String] = []
        for column in 0..<columns {
            let left = bitmap.width * column / columns
            let right = bitmap.width * (column + 1) / columns
            let rect = CGRect(x: left, y: 0, width: right - left, height: bitmap.height)
            guard let page = bitmap.cropping(to: rect),
                  let jpeg = NSBitmapImageRep(cgImage: page).representation(using: .jpeg, properties: [.compressionFactor: 0.94]) else { return nil }
            pages.append("data:image/jpeg;base64," + jpeg.base64EncodedString())
        }
        return pages
    }
}
