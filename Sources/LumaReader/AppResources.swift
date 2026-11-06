import Foundation

/// Resolve installed .app and SwiftPM layouts without invoking the generated
/// Bundle.module accessor's build-machine-path fatalError fallback.
enum AppResources {
    private final class Marker: NSObject {}
    static func url(forResource name:String,withExtension ext:String) -> URL? {
        if let url = Bundle.main.url(forResource:name,withExtension:ext) { return url }
        let roots = [Bundle.main.resourceURL,Bundle.main.executableURL?.deletingLastPathComponent(),
                     Bundle.main.bundleURL,Bundle(for:Marker.self).bundleURL.deletingLastPathComponent(),
                     URL(fileURLWithPath:CommandLine.arguments[0]).deletingLastPathComponent()].compactMap { $0 }
        for root in roots {
            let path = root.appendingPathComponent("LumaReader_LumaReader.bundle")
            if let bundle = Bundle(url:path), let url = bundle.url(forResource:name,withExtension:ext) { return url }
        }
        return nil
    }
}
