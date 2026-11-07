import Foundation

/// WebKit can canonicalize macOS aliases such as /var to /private/var.
/// Compare resolved paths on both sides while retaining a directory boundary.
enum ReaderFileNavigation {
    static func contains(_ url:URL,in root:URL) -> Bool {
        guard url.isFileURL, root.isFileURL else { return false }
        let directory = root.resolvingSymlinksInPath().standardizedFileURL.path
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL.path
        return candidate.hasPrefix(directory + "/")
    }
}
